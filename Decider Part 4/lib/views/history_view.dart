import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decider/models/Account.dart';
import 'package:decider/models/Question.dart';
import 'package:decider/services/ad_mob_service.dart';
import 'package:decider/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'helpers/question_card.dart';

class HistoryView extends StatefulWidget {
  final Account account;
  HistoryView({required this.account});

  @override
  _HistoryViewState createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<Object> _historyList = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getUsersQuestionsList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Past Decisions"),
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: _historyList.length,
          itemBuilder: (context, index) {
            if (_historyList[index] is Question) {
              return QuestionCard(_historyList[index] as Question);
            } else if (_historyList[index] is BannerAd){
              return Container(
                height: 60,
                color: Colors.white,
                child: AdWidget(ad: _historyList[index] as BannerAd),
              );
            } else {
              return Container();
            }
          },
        ),
      ),
    );
  }

  Future getUsersQuestionsList() async {
    var data = await FirebaseFirestore.instance
        .collection('users')
        .doc(context.read<AuthService>().currentUser?.uid)
        .collection('questions')
        .orderBy('created', descending: true)
        .get();

    setState(() {
      _historyList = List.from(data.docs.map((doc) => Question.fromSnapshot(doc)));

      //  Add Banner Ads
      if (widget.account.adFree == false) {
        final adMobService = context.read<AdMobService>();
        adMobService.initialization.then((value) {
          for (int i = _historyList.length - 3; i >= 3; i -= 7) {
            _historyList.insert(
              i,
              BannerAd(
                adUnitId: adMobService.bannerAdUnitId!,
                size: AdSize.fullBanner,
                request: AdRequest(),
                listener: adMobService.bannerListener,
              )..load(),
            );
          }
        });
      }
    });
  }
}
