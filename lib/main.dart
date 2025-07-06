import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/student/splash_screen.dart';

import 'function/notification_service.dart';
import 'function/student_location.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set UI style - fast operation
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());

  await Firebase.initializeApp();
  // Initialize notification service
 Future.wait([
  NotificationService().initialize(),
  // Initialize location service
   StudentLocationService().initialize(),
 ]);

}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "LibTrack",
      theme: darkTheme,
      debugShowCheckedModeBanner: false,
      home: SplashScreen( ),
    );
  }
}
