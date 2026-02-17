import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'utils/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite FFI only for desktop platforms (not web, mobile, or others)
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
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
    
    // Ensure Firebase Auth is initialized on the main thread
    FirebaseAuth.instance.authStateChanges().listen((_) {
      // This ensures the auth state listener is setup on the main thread
    });
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const ListifyApp(),
    ),
  );
}

class ListifyApp extends StatelessWidget {
  const ListifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Listify',
      theme: context.watch<ThemeProvider>().currentTheme,
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