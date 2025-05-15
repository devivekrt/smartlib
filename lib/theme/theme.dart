import 'package:flutter/material.dart';
class DarkColor {
  static const nero = Color(0xff181818); // appbar, footer , background, card
  static const grey17 = Color(0xff2b2b2b); // stroke
  static const darkGrey = Color(0xff1f1f1f); //background
  static const brightOrange = Color(0xffE5702D); // button
  static const darkOrange = Color(0xff8e351e);
  static const aqua = Color(0xff05F8F3); // highlight text
  static const scienceBlue = Color(0xff0262D7); // links

  static const white = Colors.white;
  static const black = Colors.black;
  static const green = Colors.green; //success
  static const red = Color(0xffb84660); //error
  static const blue = Colors.blue; //
  static const orange = Colors.orange; //warning
}
final darkTheme = ThemeData(

  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkColor.darkGrey,
  cardTheme: CardTheme(
    color: DarkColor.nero,
    shape: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color:DarkColor.white,width: 0.5 )
    ),
  ),
  colorScheme:  ColorScheme(
    brightness: Brightness.dark,
    primary: DarkColor.brightOrange,
    onPrimary: DarkColor.white,
    secondary: DarkColor.darkOrange,
    onSecondary:  DarkColor.black,
    error: DarkColor.red,
    onError: DarkColor.white,
    surface: DarkColor.nero,
    onSurface: DarkColor.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    prefixIconColor: Colors.white70,

    hintStyle: TextStyle(color: Colors.white70),
    fillColor: DarkColor.nero,
    labelStyle: TextStyle(color: Colors.white70),

    // Add border theme
    border: OutlineInputBorder(
      borderSide: BorderSide(color: DarkColor.grey17), // default border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
          color: DarkColor.grey17, width: 0.5), // enabled state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
          color: DarkColor.brightOrange,
          width: 0.5), // focused state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(
          color: DarkColor.red, width: 1.0), // error state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(
          color: DarkColor.red, width: 2.0), // focused error border color
      borderRadius: BorderRadius.circular(8.0),
    ),
  ),
  fontFamily: "poppins",
  appBarTheme:  AppBarTheme(
    surfaceTintColor: DarkColor.nero,// after scroll color change
    backgroundColor: DarkColor.nero, // Primary color for AppBar
  ),
  textTheme: TextTheme(
    titleLarge: TextStyle(color: Colors.white70,fontWeight: FontWeight.bold,fontSize: 20 ),
    titleMedium: TextStyle(color: Colors.white70,fontSize: 16,), // Black color
    titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white70), // Black color
    bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Colors.white70), // Black color
    // Black color
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(
          DarkColor.brightOrange), // Set the primary color
      foregroundColor: WidgetStateProperty.all(Colors.white), // Text color
      padding: WidgetStateProperty.all(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12)), // Adjust padding
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Rounded corners
        ),
      ),
    ),
  ),
  buttonTheme: ButtonThemeData(
    buttonColor:
    DarkColor.brightOrange, // Primary buttons use the primary color
  ),
);
