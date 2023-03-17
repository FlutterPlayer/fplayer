import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';

import 'home_page.dart';

void main() {
  // debugPaintSizeEnabled = true;
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF07B9B9),
        primaryColorDark: const Color(0xFFFFFFFF),
        primaryColorLight: const Color(0x33000000),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            overlayColor: MaterialStateProperty.all(Colors.transparent),
          ),
        ),
      ),
      home: HomeScreen(),
    );
  }
}
