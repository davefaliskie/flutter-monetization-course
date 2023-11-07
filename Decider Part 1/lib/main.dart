import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:decider/services/auth_service.dart';
import 'package:decider/views/home_view.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/Account.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AuthService().getOrCreateUser();

  runApp(MultiProvider(
    providers: [Provider.value(value: AuthService())],
    child: DeciderApp(),
  ));
}

class DeciderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Decider',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        home: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(context.read<AuthService>().currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if(snapshot.hasData) {
              Account account = Account.fromSnapshot(snapshot.data, context.read<AuthService>().currentUser?.uid);
              return HomeView(account: account);
            }
            return Container(color: Colors.white);
          },
        )
     );
  }
}
