import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:origo/home_page.dart';
import 'package:origo/main.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return HomePage();
        } else {
          return const LoginScreen();
        }
      },
    ));
  }
}