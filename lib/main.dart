import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:smartlib/theme/theme.dart';
import 'package:smartlib/user-pages/Login.dart';
import 'package:smartlib/user-pages/home_page.dart';
import 'package:smartlib/user-pages/lib_detail.dart';
import 'package:smartlib/user-pages/market_place.dart';
import 'package:smartlib/user-pages/select_page.dart';
import 'package:smartlib/user-pages/sign_up.dart';
import 'package:smartlib/user-pages/splash_screen.dart';
import 'package:smartlib/user-pages/success_page.dart';

import 'firebase_options.dart';
import 'function/users_function.dart';
import 'owner-pages/library_details_page.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: "Smart-Lib",
      theme: darkTheme,
      debugShowCheckedModeBanner: false,

      home: SelectPage(),
    );
  }
}
