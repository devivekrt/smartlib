import 'package:flutter/material.dart';

import '../theme/theme.dart';

class SolidButton extends StatelessWidget {
  const SolidButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.buttonColor = DarkColor.primary,
    this.width = 100,
    this.height = 60,
    this.borderColor,
  });
  final String text;
  final VoidCallback onPressed;
  final Color? buttonColor;
  final double width;
  final double height;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          color:  Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        minimumSize: Size(width, height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor ?? Colors.transparent),
        ),
      ),
    );
  }
}
