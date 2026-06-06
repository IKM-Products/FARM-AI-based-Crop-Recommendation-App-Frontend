import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Keeps the splash screen visible for 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using a deep green to match your farming theme
      backgroundColor: Colors.green.shade800,
      body: const Center(
        child: Icon(
          Icons.eco,
          size: 150, // Made it slightly larger since it's the only element
          color: Colors.white,
        ),
      ),
    );
  }
}