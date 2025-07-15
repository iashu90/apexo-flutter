import 'package:apexo/core/activity_logger.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AcrylicButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onPressed;
  final double elevation;
  final Gradient? gradient;

  const AcrylicButton(
      {super.key,
      required this.icon,
      required this.text,
      required this.onPressed,
      this.gradient,
      this.elevation = 1});
  @override
  Widget build(BuildContext context) {
    return Acrylic(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      elevation: elevation,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(5),
        ),
        child: IconButton(
          focusable: true,
          autofocus: true,
          icon: Row(
            children: [Icon(icon), const SizedBox(width: 5), Txt(text)],
          ),
          onPressed: () {
            ActivityLogger.logAction("AcrylicButton Clicked",
                screen: "AcrylicButton", data: {"text": text});
            onPressed?.call();
          },
        ),
      ),
    );
  }
}
