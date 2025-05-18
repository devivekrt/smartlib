import 'package:flutter/material.dart';

class DarkColor {
  static const highlightColor =  Color(0xFF0090B5);

  static const cardColor = Color(0xFF010515); // appbar, footer , card
  static const borderColor = Color(0xFF626570); // stroke
  static const secondary = Color(0xFF0D1529); //background
  static const primary = Color(0xFF00D3BB); // button
  //static const darkOrange = Color(0xff8e351e);
  static const text = Colors.white70; // highlight text

  static const white = Colors.white;
  static const black = Colors.black;
  static const green = Colors.green; //success
  static const red = Color(0xffb84660); //error
  static const blue = Colors.blue; //
  static const orange = Colors.orange; //warning
}

final darkTheme = ThemeData(
  visualDensity: VisualDensity.adaptivePlatformDensity,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: DarkColor.secondary,
  cardTheme: CardTheme(
    color: DarkColor.cardColor,
    shape: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: DarkColor.borderColor, width: 1),
    ),
  ),
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: DarkColor.primary,
    onPrimary: DarkColor.white,
    secondary: DarkColor.secondary,
    onSecondary: DarkColor.black,
    error: DarkColor.red,
    onError: DarkColor.white,
    surface: DarkColor.cardColor,
    onSurface: DarkColor.white,
  ),
  inputDecorationTheme: InputDecorationTheme(
    prefixIconColor: Colors.white70,

    hintStyle: TextStyle(color: Colors.white70),
    fillColor: DarkColor.cardColor,
    labelStyle: TextStyle(color: Colors.white70),

    // Add border theme
    border: OutlineInputBorder(
      borderSide: BorderSide(
        color: DarkColor.borderColor,
      ), // default border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: DarkColor.borderColor,
        width: 0.5,
      ), // enabled state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: DarkColor.primary,
        width: 0.5,
      ), // focused state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: DarkColor.red,
        width: 1.0,
      ), // error state border color
      borderRadius: BorderRadius.circular(8.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(
        color: DarkColor.red,
        width: 2.0,
      ), // focused error border color
      borderRadius: BorderRadius.circular(8.0),
    ),
  ),
  fontFamily: "poppins",
  appBarTheme: AppBarTheme(
    surfaceTintColor: DarkColor.cardColor, // after scroll color change
    backgroundColor: DarkColor.cardColor, // Primary color for AppBar
  ),
  textTheme: TextTheme(
    titleLarge: TextStyle(
      color: Colors.white70,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    ),
    titleMedium: TextStyle(color: Colors.white70, fontSize: 16), // Black color
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ), // Black color
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: Colors.white70,
    ), // Black color
    // Black color
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.all(
        DarkColor.primary,
      ), // Set the primary color
      foregroundColor: WidgetStateProperty.all(Colors.white), // Text color
      padding: WidgetStateProperty.all(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ), // Adjust padding
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), // Rounded corners
        ),
      ),
    ),
  ),
  buttonTheme: ButtonThemeData(
    buttonColor: DarkColor.primary, // Primary buttons use the primary color
  ),
);
