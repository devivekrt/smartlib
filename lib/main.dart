import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartlib/student/welcomescreen.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/student/Login.dart';
import 'package:smartlib/student/library_market_place.dart';
import 'package:smartlib/student/main_tab_screen.dart';
import 'package:smartlib/student/select_page.dart';
import 'package:smartlib/student/sign_up.dart';
import 'package:smartlib/student/splash_screen.dart';
import 'package:smartlib/student/success_page.dart';
import 'package:smartlib/student/test.dart';

import 'firebase_options.dart';
import 'function/listen_data.dart';
import 'function/notification_service.dart';
import 'function/student_function.dart';
import 'function/student_location.dart';
import 'library/library_details_upload.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  // Initialize notification service
  await NotificationService().initialize();
  // Initialize location service
  final locationService = StudentLocationService();
  await locationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LibTrack",
      theme: darkTheme,
      navigatorKey: NotificationService().navigatorKey,
      debugShowCheckedModeBanner: false,
      home: SplashScreen( ),
    );
  }
}
