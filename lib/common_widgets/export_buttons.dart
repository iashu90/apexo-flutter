import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A pair of pill-style CSV (green) and PDF (red) export buttons.
///
/// Use [ExportCsvButton] or [ExportPdfButton] individually, or
/// [ExportButtons] to show both side by side.
class ExportButtons extends StatelessWidget {
  final VoidCallback? onCsv;
  final VoidCallback? onPdf;
  final bool csvBusy;
  final bool pdfBusy;

  const ExportButtons({
    super.key,
    this.onCsv,
    this.onPdf,
    this.csvBusy = false,
    this.pdfBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExportCsvButton(onPressed: onCsv, busy: csvBusy),
        const SizedBox(width: 8),
        ExportPdfButton(onPressed: onPdf, busy: pdfBusy),
      ],
    );
  }
}

class ExportCsvButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool busy;

  const ExportCsvButton({super.key, this.onPressed, this.busy = false});

  @override
  State<ExportCsvButton> createState() => _ExportCsvButtonState();
}

class _ExportCsvButtonState extends State<ExportCsvButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFD7F2E6) : const Color(0xFFE8F7EF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF86D6A9)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/svg/csv_icon.svg',
                width: 15,
                height: 15,
              ),
              const SizedBox(width: 6),
              Text(
                widget.busy ? 'CSV...' : 'CSV',
                style: const TextStyle(
                  color: Color(0xFF1F9D55),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportPdfButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool busy;

  const ExportPdfButton({super.key, this.onPressed, this.busy = false});

  @override
  State<ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<ExportPdfButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF9D6D6) : const Color(0xFFFDECEC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFF4A5A5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/svg/pdf_icon.svg',
                width: 15,
                height: 15,
              ),
              const SizedBox(width: 6),
              Text(
                widget.busy ? 'PDF...' : 'PDF',
                style: const TextStyle(
                  color: Color(0xFFE5484D),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
