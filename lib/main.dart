import 'package:body_posture_detector/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Body Posture Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color.fromRGBO(44, 51, 51, 1),
        ),
        canvasColor: const Color.fromRGBO(44, 51, 51, 1),
        textTheme: GoogleFonts.muktaTextTheme().copyWith(
          button: GoogleFonts.mukta(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          headline1: GoogleFonts.mukta(
            color: const Color.fromRGBO(163, 198, 198, 1),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme().copyWith(
          iconTheme: const IconThemeData(
            color: Color.fromRGBO(163, 198, 198, 1),
            size: 22,
          ),
        ), 
      ),
      home: const SplashScreen(),
    );
  }
}
