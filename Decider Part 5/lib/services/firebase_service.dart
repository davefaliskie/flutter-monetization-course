import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  increaseDecision({uid, quantity}) {
    print("increaseDecision: $quantity");
    FirebaseFirestore.instance.collection("users").doc(uid).update({
      'bank': FieldValue.increment(quantity),
      'nextFreeQuestion': DateTime.now(),
    });
  }

  setAccountType({uid, type}) {
    FirebaseFirestore.instance.collection("users").doc(uid).update({
      '$type': true,
      'nextFreeQuestion': DateTime.now(),
    });
  }
}