import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType keyboardType;
  final bool isPassword;
  final String? Function(String?)? validator;
  final IconData? prefixIcon; // Prefix Icon parameter
  final Widget? suffixIcon; // Suffix Icon parameter
  final BorderSide? borderSide; // BorderSide parameter (nullable)
  final BorderRadius? borderRadius;
  final bool? filled;
  final bool? readOnly;
  final bool enabled;
  final int? minLines;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;

  final int? maxLines;

  const InputField({
    super.key,
    this.hintText,
    this.controller,
    this.labelText,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.validator,
    this.prefixIcon, // Prefix Icon parameter
    this.suffixIcon, // Suffix Icon parameter
    this.borderSide,
    this.borderRadius,
    this.filled,
    this.maxLines,
    this.readOnly,
    this.enabled = true,  this.minLines,  this.inputFormatters, this.prefixText, // Nullable borderSide for customization
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: isPassword,
      maxLines: maxLines ?? null,
      minLines: minLines??1,
      readOnly: readOnly ?? false,
      enabled: enabled ,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixText: prefixText,
        prefixIconColor: Theme.of(context).inputDecorationTheme.prefixIconColor,
        labelStyle: Theme.of(context).inputDecorationTheme.labelStyle,
        fillColor: Theme.of(context)
            .inputDecorationTheme
            .fillColor, // Default to white background
        filled: filled ?? true, // Default filled to true
        border: OutlineInputBorder(
          borderRadius:
              borderRadius ?? BorderRadius.circular(20), // Default radius 10
          borderSide: BorderSide(
              width: 1,
              color:
                  Colors.black), // Default borderSide to none if not provided
        ),
        prefixIcon:
            prefixIcon != null ? Icon(prefixIcon) : null, // Prefix Icon logic
        suffixIcon: suffixIcon, // Suffix Icon logic
      ),
      validator: validator,
    );
  }
}
