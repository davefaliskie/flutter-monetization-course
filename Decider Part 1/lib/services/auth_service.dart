
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> getOrCreateUser() async {
    if (currentUser == null) {
      await _firebaseAuth.signInAnonymously();
      initializeAccount();
    }
    return currentUser;
  }

  initializeAccount() {
    DocumentReference document = FirebaseFirestore.instance.collection('users').doc(currentUser?.uid);
    document.get().then((documentSnapshot) {
      if (!documentSnapshot.exists) {
        document.set({"bank": 3});
      }
    });
  }
}