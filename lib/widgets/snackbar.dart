import 'package:flutter/material.dart';

void showError(BuildContext context,String message,Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message),backgroundColor: color,),
  );
}