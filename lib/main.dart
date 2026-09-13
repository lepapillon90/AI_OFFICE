import 'package:flutter/material.dart';

void main() {
  runApp(const OfficeApp());
}

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(body: Center(child: Text('AI Office'))),
      );
}
