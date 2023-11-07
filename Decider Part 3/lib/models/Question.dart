class Question {
  String? query;
  String? answer;
  DateTime? created;

  Question();

  Map<String, dynamic> toJson() => {'query': query, 'answer': answer, 'created': created};

  Question.fromSnapshot(snapshot)
      : query = snapshot.data()['query'],
        answer = snapshot.data()['answer'],
        created = snapshot.data()['created'].toDate();
}
