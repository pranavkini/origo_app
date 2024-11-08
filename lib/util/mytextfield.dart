import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  const MyTextField({
    super.key,
    required this.hint,
    required this.obscureText,
    required this.controller,
    this.icon,
  });

  final String hint;
  final bool obscureText;
  final TextEditingController controller;
  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Fixed padding
      width: double.infinity, // Take full width
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.grey[400]),
        obscureText: obscureText,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.grey[900],
          labelText: hint,
          labelStyle: TextStyle(color: Colors.white),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade800),
            borderRadius: BorderRadius.circular(8), // Rounded corners
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(8), // Rounded corners
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon!.icon,
                  color: Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
