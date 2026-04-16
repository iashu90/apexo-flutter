import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class MonthNavigatorBar extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<DateTime> onPick;
  final bool showBorder;

  const MonthNavigatorBar({
    super.key,
    required this.selectedMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    this.showBorder = true,
  });

  ButtonStyle get _monthButtonStyle {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return const Color(0x331A74DB);
        }
        if (states.contains(WidgetState.hovered)) {
          return const Color(0x1F1A74DB);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.all(const Color(0xFF1468CC)),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        DateTime temp = DateTime(selectedMonth.year, selectedMonth.month, 1);
        final max = DateTime(DateTime.now().year, DateTime.now().month, 1);
        return ContentDialog(
          title: const Text('Select month'),
          content: SizedBox(
            width: 280,
            child: StatefulBuilder(
              builder: (context, setStateDialog) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ComboBox<int>(
                    isExpanded: true,
                    value: temp.month,
                    items: List.generate(
                      12,
                      (i) => ComboBoxItem<int>(
                        value: i + 1,
                        child: Text(DateFormat('MMMM').format(DateTime(2000, i + 1))),
                      ),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setStateDialog(() {
                        final candidate = DateTime(temp.year, v, 1);
                        temp = candidate.isAfter(max) ? max : candidate;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ComboBox<int>(
                    isExpanded: true,
                    value: temp.year,
                    items: List.generate(
                      31,
                      (i) {
                        final year = DateTime.now().year - i;
                        return ComboBoxItem<int>(
                          value: year,
                          child: Text(year.toString()),
                        );
                      },
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      setStateDialog(() {
                        final candidate = DateTime(v, temp.month, 1);
                        temp = candidate.isAfter(max) ? max : candidate;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, temp),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      onPick(DateTime(picked.year, picked.month, 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: showBorder ? Border.all(color: const Color(0xFFD6E2F0)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: onPrevious,
                style: _monthButtonStyle,
                child: const Icon(FluentIcons.chevron_left, size: 12),
              ),
              Button(
                onPressed: () => _pickMonth(context),
                style: _monthButtonStyle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(
                        color: Color(0xFF25466E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Monthly filter',
                      style: TextStyle(
                        color: Color(0xFF557195),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Button(
                onPressed: onNext,
                style: _monthButtonStyle,
                child: const Icon(FluentIcons.chevron_right, size: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
