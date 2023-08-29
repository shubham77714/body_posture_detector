import 'dart:async';

import 'package:body_posture_detector/image_picker_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late Animation<double> imageAnimation;
  late Animation<double> textAnimation;
  late AnimationController animationController;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    imageAnimation = Tween<double>(begin: 0, end: 100).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    textAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    animationController.forward();
    animationController.addListener(() {
      setState(() {});
    });

    Timer(
      const Duration(seconds: 2),
      () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context)=>const ImagePickerScreen()
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(41, 89, 88, 1),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: Image.asset(
              "assets/icon.png",
              height: imageAnimation.value,
              width: imageAnimation.value,
            ),
          ),
          Text(
            "Body Posture Detector",
            style: TextStyle(
              fontSize: textAnimation.value,
              fontWeight: FontWeight.w600,
              color: const Color.fromARGB(255, 66, 212, 202),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    animationController.dispose();
    super.dispose();
  }
}
