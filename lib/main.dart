import 'package:ai_office/screens/office_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const OfficeApp());
}

class OfficeApp extends StatelessWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansKR'),
        home: const OfficeScreen(),
      );
}
