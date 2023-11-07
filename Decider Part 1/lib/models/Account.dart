class Account {
  String? uid;
  int bank = 0;
  DateTime? nextFreeQuestion;

  Account();

  Map<String, dynamic> toJson() => {'bank': bank, 'nextFreeQuestion': nextFreeQuestion};

  Account.fromSnapshot(snapshot, uid)
      : bank = snapshot.data()['bank'],
        nextFreeQuestion = snapshot.data()['nextFreeQuestion']?.toDate() ,
        uid = uid;
}