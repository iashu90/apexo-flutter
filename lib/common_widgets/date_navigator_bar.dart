import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class DateNavigatorBar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;
  final bool showBorder;
  final bool showTodayButton;
  final Color todayButtonColor;

  const DateNavigatorBar({
    super.key,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    required this.onToday,
    this.showBorder = true,
    this.showTodayButton = true,
    this.todayButtonColor = const Color(0xFF1A74DB),
  });

  ButtonStyle get _dateButtonStyle {
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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border:
                showBorder ? Border.all(color: const Color(0xFFD6E2F0)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                onPressed: onPrevious,
                style: _dateButtonStyle,
                child: const Icon(FluentIcons.chevron_left, size: 12),
              ),
              Button(
                onPressed: onPick,
                style: _dateButtonStyle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM d, yyyy').format(selectedDate),
                      style: const TextStyle(
                        color: Color(0xFF25466E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('EEEE').format(selectedDate),
                      style: const TextStyle(
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
                style: _dateButtonStyle,
                child: const Icon(FluentIcons.chevron_right, size: 12),
              ),
            ],
          ),
        ),
        if (showTodayButton) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Visibility(
              visible: !isToday,
              maintainAnimation: true,
              maintainState: true,
              maintainSize: true,
              child: FilledButton(
                onPressed: onToday,
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return const Color(0xFF0B5BBC);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF1468CC);
                    }
                    return todayButtonColor;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.white),
                ),
                child: const Text('Today'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
