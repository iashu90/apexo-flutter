import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }
}
