import 'package:fluent_ui/fluent_ui.dart';

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
    final hasText = controller != null && controller!.text.trim().isNotEmpty;

    return SizedBox(
      width: width,
      child: TextBox(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        placeholder: hint,
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(
            FluentIcons.search,
            size: 12,
            color: Color(0xFF6D84A8),
          ),
        ),
        suffix: hasText
            ? IconButton(
                icon: const Icon(FluentIcons.clear, size: 10),
                onPressed: onClear,
              )
            : null,
      ),
    );
  }
}
