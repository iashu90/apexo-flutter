import 'dart:math';

import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/labwork/open_labwork_v2_dialog.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart' as intl;
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/services/localization/locale.dart';

class LabworkCard extends StatelessWidget {
  final Labwork labwork;
  final int number;
  final String? difference;
  const LabworkCard({
    super.key,
    required this.labwork,
    required this.number,
    this.difference,
  });

  @override
  Widget build(BuildContext context) {
    final color = Colors.blue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 15, 15, 0),
      child: Column(
        children: [
          if (difference != null) ...[
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeDifference(),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(FluentIcons.test_beaker, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Acrylic(
                  elevation: 100,
                  blurAmount: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5)),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: color,
                          width: 5,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Txt(
                              "${"Labwork"}: $number",
                              style: TextStyle(
                                fontSize: 10,
                                color: color.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(FluentIcons.clock, color: color),
                            const SizedBox(width: 5),
                            Txt(
                              intl.DateFormat(
                                      "E d/MM/yyyy - hh:mm a", locale.s.$code)
                                  .format(labwork.date),
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Row(
                               mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(FluentIcons.delete,
                                      size: 17, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => ContentDialog(
                                        title: const Text('Delete Labwork'),
                                        content: RichText(
                                          text: TextSpan(
                                            style: FluentTheme.of(context)
                                                .typography
                                                .body,
                                            children: [
                                              const TextSpan(
                                                text:
                                                    'Are you sure you want to permanently delete this labwork dated ',
                                              ),
                                              TextSpan(
                                                text: intl.DateFormat(
                                                        "E d/MM/yyyy - hh:mm a",
                                                        locale.s.$code)
                                                  .format(labwork.date),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.warningPrimaryColor, // Highlight the date
                                                ),
                                              ),
                                              const TextSpan(
                                                text:
                                                    '? This action cannot be undone.',
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          Button(
                                            child: const Text('Cancel'),
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                          ),
                                          FilledButton(
                                            style: ButtonStyle(
                                              backgroundColor:
                                                  ButtonState.all(Colors.red),
                                            ),
                                            child: const Text('Delete'),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      // Perform hard delete logic here
                                      await labworks.hardDelete(
                                          labwork.id); // or your delete method
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                  iconButtonMode: IconButtonMode.large,
                                ),
                                IconButton(
                                  icon: const Icon(FluentIcons.edit, size: 17),
                                  onPressed: () {
                                    openLabworkDialog(context, labwork);
                                  },
                                  iconButtonMode: IconButtonMode.large,
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (labwork.lab.isNotEmpty) ...[
                          ..._betweenSections,
                          _buildSection(txt("laboratory"), labwork.lab,
                              FluentIcons.company_directory, color),
                          if (labwork.typeOfWork.isNotEmpty) ...[
                            ..._betweenSections,
                            _buildSection("Type of work", labwork.typeOfWork,
                                FluentIcons.add_work, color),
                          ],
                          if (labwork.selectedTeeth.isNotEmpty) ...[
                            ..._betweenSections,
                            _buildSection(
                              "Teeth",
                              labwork.selectedTeeth
                                  .join(', '), // Show as comma separated string
                              FluentIcons.add_field,
                              color,
                            ),
                          ],
                          ...[
                          ..._betweenSections,
                          _buildSection(
                              "No. of units",
                              labwork.noOfUnits.toString(),
                              FluentIcons.number_field,
                              color),
                        ],
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Transform _spacerIcon([flip = 1]) {
    return Transform.flip(
      flipX: flip == 1 ? true : false,
      flipY: false,
      child: Transform.translate(
        offset: Offset(0, flip < 1 ? 2.0 * flip : 5.0 * flip),
        child: Transform.rotate(
          angle: (pi / (flip == 1 ? 2 : 1)) * flip,
          child: Icon(
            color: Colors.grey.withValues(alpha: 0.3),
            FluentIcons.turn_right,
            size: 14,
          ),
        ),
      ),
    );
  }

  Center _buildTimeDifference() {
    return Center(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: [
        _spacerIcon(1),
        _horizontalSpacing(),
        TimeDifference(difference: difference),
        _horizontalSpacing(),
        _spacerIcon(-1),
      ],
    ));
  }

  Row _buildSection(String title, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            icon,
            size: 13,
            color: color.withOpacity(0.5),
          ),
        ),
        Acrylic(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          elevation: 100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Txt(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        _horizontalSpacing(),
        Expanded(
          child: Txt(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

List<Widget> get _betweenSections {
  return [_verticalSpacing(), _divider(), _verticalSpacing()];
}

Divider _divider() => const Divider(size: 300);
SizedBox _horizontalSpacing([double n = 5]) => SizedBox(width: n);

SizedBox _verticalSpacing([double n = 10.0]) => SizedBox(height: n);

class TimeDifference extends StatelessWidget {
  const TimeDifference({
    super.key,
    required this.difference,
  });

  final String? difference;

  @override
  Widget build(BuildContext context) {
    return Txt(
      difference ?? "",
      style: TextStyle(
          fontSize: 12,
          color: Colors.grey.withOpacity(0.5),
          fontWeight: FontWeight.bold),
    );
  }
}
