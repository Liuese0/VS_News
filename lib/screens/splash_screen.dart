// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import 'auth/welcome_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (authProvider.hasExistingAccount) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              );
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.primaryColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.05),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    size: screenWidth * 0.2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: screenWidth * 0.08,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  '뜨거운 이슈, 당신의 선택은?',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: screenHeight * 0.06),
                SizedBox(
                  width: screenWidth * 0.08,
                  height: screenWidth * 0.08,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: screenHeight * 0.02),
                Text(
                  '초기화 중...',
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}