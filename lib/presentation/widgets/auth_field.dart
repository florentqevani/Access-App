import 'package:flutter/material.dart';

class AuthField extends StatelessWidget {
  final String label;
  final bool obscureText;
  final TextEditingController controller;
  const AuthField({
    super.key,
    required this.label,
    this.obscureText = false,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }
}
