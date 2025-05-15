import 'package:flutter/material.dart';

class SolidButton extends StatelessWidget {
  const SolidButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.buttonColor,  this.width = 100,  this.height =50 ,

  });
  final String text;
  final VoidCallback onPressed;
  final Color? buttonColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,

      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(

        backgroundColor: buttonColor,
        minimumSize: Size(width, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
