import 'package:flutter/material.dart';
import 'package:ngenius_flutter_sdk/models/ngenius_response_model.dart';
import 'package:ngenius_flutter_sdk/ngenius_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NgeniusExample(),
    );
  }
}

class NgeniusExample extends StatelessWidget {
  const NgeniusExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('N-Genius Example'),
      ),
      body: Center(
        child: ElevatedButton(
            onPressed: () async {
              final ngeniusFlutterSdk = NgeniusFlutterSdk();
              NGeniusResponseModel ngeniusResponse = await ngeniusFlutterSdk.launchCardPayment(orderJsonObject: {});
              if (context.mounted) {
                if (ngeniusResponse.message == "PAYMENT_SUCCESSFUL") {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transaction Successful")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          "Transaction Failed :: code :: ${ngeniusResponse.code} :: message :: ${ngeniusResponse.message}")));
                }
              }
            },
            child: Text("Launch Card Payment")),
      ),
    );
  }
}



