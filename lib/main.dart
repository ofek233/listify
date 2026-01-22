import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite for desktop platforms (Windows, Linux, macOS)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  // Initialize Firebase with explicit options for all platforms
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCUaa52MpQ7vv-T9D1KyndknvD4taDLSxo",
        authDomain: "listify-b624b.firebaseapp.com",
        projectId: "listify-b624b",
        storageBucket: "listify-b624b.firebasestorage.app",
        messagingSenderId: "325994277971",
        appId: "1:325994277971:android:3e6520826094f98b016aa6",
      ),
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(const ListifyApp());
}

class ListifyApp extends StatelessWidget {
  const ListifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Listify',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const HomePage();
          }

          return const LoginPage();
        },
      ),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
      },
    );
  }
}
