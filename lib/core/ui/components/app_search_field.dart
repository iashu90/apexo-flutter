import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final double width;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.width = 280,
    this.onClear,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller != null && (controller!.text.isNotEmpty)
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: onClear,
                )
              : null,
        ),
      ),
    );
  }
}
