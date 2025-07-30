import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/issue_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';

void main() {
  runApp(const NewsDebaterApp());
}

class NewsDebaterApp extends StatelessWidget {
  const NewsDebaterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => IssueProvider()),
      ],
      child: MaterialApp(
        title: '뉴스 디베이터',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: AppColors.primaryColor,
          fontFamily: 'Pretendard',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          scaffoldBackgroundColor: AppColors.backgroundColor,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}