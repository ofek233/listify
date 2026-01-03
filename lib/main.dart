import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
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
      home: const HomePage(),
    );
  }
}
