import 'package:flutter/material.dart';
import 'package:smartlib/theme/theme.dart';

class NextButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;
  final String text;

  const NextButton({
    Key? key,
    required this.isEnabled,
    required this.onPressed, this.text ="Next",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? DarkColor.primary : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}