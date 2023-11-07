import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decider/models/Account.dart';
import 'package:decider/models/Question.dart';
import 'package:decider/services/ad_mob_service.dart';
import 'package:decider/services/auth_service.dart';
import 'package:decider/views/history_view.dart';
import 'package:decider/views/store_view.dart';
import 'package:flutter/material.dart';
import "package:decider/extensions/string_extension.dart";
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:timer_count_down/timer_controller.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:intl/intl.dart';

enum AppStatus { ready, waiting }

class HomeView extends StatefulWidget {
  final Account account;

  HomeView({required this.account});

  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  TextEditingController _questionController = TextEditingController();
  String _answer = "";
  bool _askBtnActive = false;
  Question _question = Question();
  AppStatus? _appStatus;
  int _timeTillNextFree = 0;
  CountdownController _countDownController = CountdownController();

  // Ad Related
  late AdMobService _adMobService;
  BannerAd? _banner;
  InterstitialAd? _interstitial;
  RewardedAd? _reward;
  bool _showReward = false;

  @override
  void initState() {
    super.initState();
    _timeTillNextFree = widget.account.nextFreeQuestion?.difference((DateTime.now())).inSeconds ?? 0;
    _giveFreeDecision(widget.account.bank, _timeTillNextFree);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.account.adFree == false) {
      _adMobService = context.read<AdMobService>();
      _adMobService.initialization.then((value) {
        setState(() {
          _banner = BannerAd(
            adUnitId: _adMobService.bannerAdUnitId!,
            size: AdSize.fullBanner,
            request: AdRequest(),
            listener: _adMobService.bannerListener,
          )..load();
          _createInterstitialAd();
          _createRewardAd();
        });
      });
    } else {
      setState(() {
        _banner = null;
        _interstitial = null;
        _reward = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _setAppStatus();
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text("Decider"),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => StoreView()),
                  );
                },
                child: Icon(Icons.shopping_bag),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => HistoryView(account: widget.account)));
                },
                child: Icon(Icons.history),
              ),
            )
          ],
        ),
        body: SafeArea(
          child: Container(
            width: MediaQuery.of(context).size.width,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Decisions Left: ${(widget.account.unlimited == true) ? 'Unlimited' : widget.account.bank}"),
                ),
                _nextFreeCountdown(),
                Spacer(),
                if (widget.account.adFree == false) _buildRewardPrompt(),
                Spacer(),
                _buildQuestionForm(),
                Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _showPlan(),
                ),
                Text("${context.read<AuthService>().currentUser?.uid}"),
                if (_banner == null || widget.account.adFree == true)
                  SizedBox(height: 10)
                else
                  Container(
                    height: 60,
                    child: AdWidget(ad: _banner!),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

//----------------------------------------------------------------------------------
//  Widget Functions, which return a widget that's rendered in the view.
//----------------------------------------------------------------------------------
  Widget _buildQuestionForm() {
    if (_appStatus == AppStatus.ready) {
      return Column(
        children: [
          Text("Should I", style: Theme.of(context).textTheme.headline4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0, left: 30.0, right: 30.0),
            child: TextField(
              decoration: InputDecoration(
                helperText: 'Enter A Question',
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              controller: _questionController,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                setState(() {
                  _askBtnActive = value.length >= 1 ? true : false;
                });
              },
            ),
          ),
          ElevatedButton(
            onPressed: _askBtnActive == true ? _answerQuestion : null,
            child: Text("Ask"),
          ),
          _questionAndAnswer()
        ],
      );
    } else {
      return _questionAndAnswer();
    }
  }

  String _getAnswer() {
    var answerOptions = ['yes', 'no', 'definitely', 'not right now'];
    return answerOptions[Random().nextInt(answerOptions.length)];
  }

  Widget _questionAndAnswer() {
    if (_answer != "") {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Text("Should I ${_question.query}?"),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(
              "Answer: ${_answer.capitalize()}",
              style: Theme.of(context).textTheme.headline6,
            ),
          )
        ],
      );
    } else {
      return Container();
    }
  }

  Widget _nextFreeCountdown() {
    if (_appStatus == AppStatus.waiting && widget.account.unlimited != true) {
      _countDownController.start();
      var f = NumberFormat("00", "en_US");
      return Column(
        children: [
          Text("You will get one free decision in"),
          Countdown(
            controller: _countDownController,
            seconds: _timeTillNextFree,
            build: (BuildContext context, double time) =>
                Text("${f.format(time ~/ 3600)}:${f.format((time % 3600) ~/ 60)}:${f.format(time.toInt() % 60)}"),
            interval: Duration(seconds: 1),
            onFinished: () {
              _giveFreeDecision(widget.account.bank, 0);
              setState(() {
                _timeTillNextFree = 0;
                _appStatus = AppStatus.ready;
              });
            },
          )
        ],
      );
    } else {
      return Container();
    }
  }

  Widget _buildRewardPrompt() {
    if (_reward == null && _showReward == true) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.exposure_plus_2, size: 50.0, color: Colors.orange),
          ),
          Text("You received 2 new decisions", style: Theme.of(context).textTheme.headline6)
        ],
      );
    } else if (_reward != null) {
      return ElevatedButton(
        onPressed: _showRewardAd,
        child: Text("Get 2 Free Decisions"),
      );
    } else {
      return Container();
    }
  }

  Widget _showPlan() {
    if (widget.account.unlimited == true) {
      return Text("Account Type: Unlimited");
    } else if (widget.account.premium == true) {
      return Text("Account Type: Premium");
    } else {
      return Text("Account Type: Free");
    }
  }

//----------------------------------------------------------------------------------
//  Void Functions, perform logical actions, change state, etc.
//----------------------------------------------------------------------------------
  void _setAppStatus() {
    if (widget.account.bank > 0 || widget.account.unlimited == true) {
      setState(() {
        _appStatus = AppStatus.ready;
      });
    } else {
      setState(() {
        _appStatus = AppStatus.waiting;
      });
    }
  }

  void _giveFreeDecision(currentBank, timeTillNextFree) {
    if (currentBank <= 0 && timeTillNextFree <= 0) {
      FirebaseFirestore.instance.collection('users').doc(widget.account.uid).update({'bank': 1});
    }
  }

  void _answerQuestion() async {
    _showInterstitialAd();
    setState(() {
      _answer = _getAnswer();
    });

    _question.query = _questionController.text;
    _question.answer = _answer;
    _question.created = DateTime.now();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.account.uid)
        .collection('questions')
        .add(_question.toJson());

    //Update the document
    if (widget.account.unlimited != true) widget.account.bank -= 1;
    widget.account.nextFreeQuestion = DateTime.now().add(Duration(seconds: 20));
    setState(() {
      _timeTillNextFree = widget.account.nextFreeQuestion?.difference((DateTime.now())).inSeconds ?? 0;
      if (widget.account.bank == 0) {
        _appStatus = AppStatus.waiting;
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(widget.account.uid).update(widget.account.toJson());

    _questionController.text = "";
  }

  void _createInterstitialAd() {
    InterstitialAd.load(
        adUnitId: _adMobService.interstitialAdUnitId!,
        request: AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (InterstitialAd ad) {
          _interstitial = ad;
        }, onAdFailedToLoad: (LoadAdError error) {
          _interstitial = null;
        }));
  }

  void _showInterstitialAd() {
    if (_interstitial != null && widget.account.adFree == false) {
      _interstitial!.fullScreenContentCallback =
          FullScreenContentCallback(onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        _createInterstitialAd();
      }, onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        _createInterstitialAd();
      });
      _interstitial!.show();
      _interstitial = null;
    }
  }

  void _increaseDecision(quantity) {
    final newBankValue = widget.account.bank + quantity;
    FirebaseFirestore.instance.collection('users').doc(widget.account.uid).update({'bank': newBankValue});
  }

  void _createRewardAd() {
    RewardedAd.load(
      adUnitId: _adMobService.rewardAdUnitId!,
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _reward = ad;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          setState(() {
            _reward = null;
          });
        },
      ),
    );
  }

  void _showRewardAd() {
    if (_reward != null && widget.account.adFree == false) {
      _reward!.fullScreenContentCallback = FullScreenContentCallback(onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _createRewardAd();
      }, onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _createRewardAd();
      });

      _reward!.show(onUserEarnedReward: (RewardedAd ad, RewardItem reward) {
        _increaseDecision(2);
        setState(() {
          _reward = null;
          _showReward = true;
        });
      });
    }
  }
}
