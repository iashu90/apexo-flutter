import 'package:fluent_ui/fluent_ui.dart';
import '../../features/doctors/doctors_store.dart';

String _doctorChipTitleCase(String input) {
  final cleaned = input.trim();
  if (cleaned.isEmpty) return cleaned;
  return cleaned
    .split(RegExp(r'\s+'))
    .map((part) => part.isEmpty
      ? part
      : '${part[0].toUpperCase()}${part.length > 1 ? part.substring(1).toLowerCase() : ''}')
    .join(' ');
}

/// Utility to pick one or more doctors in a dialog.
Future<List<String>?> pickDoctorDialog(
  BuildContext context, {
  List<String> initialSelected = const <String>[],
  String title = 'Assign Doctor(s)',
  String? subtitle,
}) async {
  return showDialog<List<String>>(
    context: context,
    builder: (dialogContext) {
      final doctorRows = doctors.present.values.toList(growable: false)
        ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      final selected = initialSelected.toSet();
      return StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(title),
              ),
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: doctorRows.isEmpty
                ? const Text('No doctors available to assign.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF355279),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (selected.isEmpty)
                        const Text(
                          'No doctors selected',
                          style: TextStyle(color: Color(0xFF6D84A8)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: doctorRows
                              .where((doctor) => selected.contains(doctor.id))
                              .map((doctor) {
                            final doctorName = doctor.title.trim().isEmpty
                                ? 'Unnamed doctor'
                              : _doctorChipTitleCase(doctor.title);
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selected.remove(doctor.id);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE9F9EF),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                                child: Text(
                                  doctorName,
                                  style: const TextStyle(
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      const SizedBox(height: 10),
                      if (selected.isNotEmpty) ...[
                        const Divider(size: 1),
                        const SizedBox(height: 10),
                      ],
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: doctorRows
                                .where((doctor) => !selected.contains(doctor.id))
                                .map((doctor) {
                              final doctorName = doctor.title.trim().isEmpty
                                  ? 'Unnamed doctor'
                                  : _doctorChipTitleCase(doctor.title);
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selected.add(doctor.id);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF4FB),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFD2E1F2),
                                    ),
                                  ),
                                  child: Text(
                                    doctorName,
                                    style: const TextStyle(
                                      color: Color(0xFF355A84),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(growable: false),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, selected.toList(growable: false)),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
}
