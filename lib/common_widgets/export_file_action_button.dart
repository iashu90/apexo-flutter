import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ExportFileType { csv, pdf }

class ExportFileActionButton extends StatelessWidget {
  final ExportFileType type;
  final VoidCallback? onPressed;
  final bool busy;
  final double iconSize;

  const ExportFileActionButton({
    super.key,
    required this.type,
    required this.onPressed,
    this.busy = false,
    this.iconSize = 18,
  });

  String get _assetPath {
    switch (type) {
      case ExportFileType.csv:
        return 'assets/svg/csv_icon.svg';
      case ExportFileType.pdf:
        return 'assets/svg/pdf_icon.svg';
    }
  }

  String get _label {
    if (busy) {
      return type == ExportFileType.csv ? 'CSV...' : 'PDF...';
    }
    return type == ExportFileType.csv ? 'CSV' : 'PDF';
  }

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onPressed,
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            _assetPath,
            width: iconSize,
            height: iconSize,
          ),
          const SizedBox(width: 7),
          Text(_label),
        ],
      ),
    );
  }
}
