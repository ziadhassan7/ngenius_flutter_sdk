import 'package:flutter/material.dart';


/// Dummy entry point to make native android and ios code readable


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YAY Portal',
      home: const Scaffold(body: Column(),),
    );
  }
}
