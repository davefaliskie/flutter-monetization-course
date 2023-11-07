import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decider/models/Question.dart';
import 'package:decider/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'helpers/question_card.dart';

class HistoryView extends StatefulWidget {
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
            return QuestionCard(_historyList[index] as Question);
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
    });
  }
}
