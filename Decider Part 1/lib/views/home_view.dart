import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decider/models/Account.dart';
import 'package:decider/models/Question.dart';
import 'package:decider/services/auth_service.dart';
import 'package:decider/views/history_view.dart';
import 'package:flutter/material.dart';
import "package:decider/extensions/string_extension.dart";
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

  @override
  void initState() {
    super.initState();
    _timeTillNextFree = widget.account.nextFreeQuestion?.difference((DateTime.now())).inSeconds ?? 0;
    _giveFreeDecision(widget.account.bank, _timeTillNextFree);
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
                onTap: () {},
                child: Icon(Icons.shopping_bag),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => HistoryView()));
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
                  child: Text("Decisions Left: ${widget.account.bank}"),
                ),
                _nextFreeCountdown(),
                Spacer(),
                _buildQuestionForm(),
                Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text("Account Type: Free"),
                ),
                Text("${context.read<AuthService>().currentUser?.uid}")
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
    if (_appStatus == AppStatus.waiting) {
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

//----------------------------------------------------------------------------------
//  Void Functions, perform logical actions, change state, etc.
//----------------------------------------------------------------------------------
  void _setAppStatus() {
    if (widget.account.bank > 0) {
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
    if(currentBank <= 0 && timeTillNextFree <= 0) {
      FirebaseFirestore.instance.collection('users').doc(widget.account.uid).update({'bank': 1});
    }
  }

  void _answerQuestion() async {
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
    widget.account.bank -= 1;
    widget.account.nextFreeQuestion = DateTime.now().add(Duration(seconds: 20));
    setState(() {
      _timeTillNextFree = widget.account.nextFreeQuestion?.difference((DateTime.now())).inSeconds ?? 0;
      if(widget.account.bank == 0) {
        _appStatus = AppStatus.waiting;
      }
    });

    await FirebaseFirestore.instance.collection('users').doc(widget.account.uid).update(widget.account.toJson());

    _questionController.text = "";
  }
}
