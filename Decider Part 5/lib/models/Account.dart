class Account {
  String? uid;
  int bank = 0;
  DateTime? nextFreeQuestion;
  bool? premium;
  bool? unlimited;

  Account();

  bool get adFree {
    if (premium == true || unlimited == true) {
      return true;
    } else {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'bank': bank,
        'nextFreeQuestion': nextFreeQuestion,
        'premium': premium,
        'unlimited': unlimited,
      };

  Account.fromSnapshot(snapshot, uid)
      : bank = snapshot.data()['bank'],
        nextFreeQuestion = snapshot.data()['nextFreeQuestion']?.toDate(),
        uid = uid,
        premium = snapshot.data()['premium'],
        unlimited = snapshot.data()['unlimited'];
}
