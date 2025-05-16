// lib/main.dart

import 'package:av/firebase_options.dart';
import 'package:av/register.dart';
import 'package:av/home.dart';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_preview/device_preview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(DevicePreview(builder: (_) => const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Visualizer',

      // Instead of hard-coding `home: RegisterPage()`,
      // listen to the auth state and show the right screen:
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // While waiting for Firebase to initialize the auth state…
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          // If we have a user, go to HomePage
          if (snapshot.hasData) {
            return const HomePage();
          }
          // Otherwise, show the registration/login flow
          return const RegisterPage();
        },
      ),
    );
  }
}