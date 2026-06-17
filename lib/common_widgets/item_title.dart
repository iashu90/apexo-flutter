import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/utils/imgs.dart';
import 'package:apexo/utils/que.dart';
import 'package:apexo/common_widgets/text_util.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../core/model.dart';
import '../utils/get_deterministic_item.dart';
import '../utils/colors_without_yellow.dart';

class ItemTitle extends StatefulWidget {
  final Model item;
  final double radius;
  final double maxWidth;
  final IconData? icon;
  final Color? predefinedColor;
  final double? fontSize;
  const ItemTitle({
    super.key,
    required this.item,
    this.radius = 15,
    this.maxWidth = 130.0,
    this.icon,
    this.predefinedColor,
    this.fontSize,
  });

  @override
  State<ItemTitle> createState() => _ItemTitleState();
}

class _ItemTitleState extends State<ItemTitle> {
  ImageProvider? _avatarToEvict;

  @override
  void dispose() {
    super.dispose();
    if (_avatarToEvict != null) _avatarToEvict!.evict();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.predefinedColor ??
        (widget.item.archived == true
            ? FluentTheme.of(context).shadowColor.withValues(alpha: 0.2)
            : getDeterministicItem(colorsWithoutYellow, (widget.item.title)));
    return SizedBox(
      width: 200,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(100),
              boxShadow: kElevationToShadow[1]),
          child: FutureBuilder(
              future: widget.item.avatar != null
                  ? (launch.isDemo
                      ? demoAvatarRequestQue.add(
                          () => getImage(widget.item.id, widget.item.avatar!))
                      : getImage(widget.item.imageRowId ?? widget.item.id,
                          widget.item.avatar!))
                  : null,
              builder: (context, snapshot) {
                if (snapshot.data != null) {
                  _avatarToEvict = snapshot.data;
                }
                if (widget.item.title.isEmpty) {
                  widget.item.title = " ";
                }
                return CircleAvatar(
                  key: Key(widget.item.id),
                  radius: widget.radius,
                  backgroundColor: color,
                  backgroundImage:
                      (snapshot.data != null) ? snapshot.data : null,
                  child: widget.item.archived == true
                      ? Icon(FluentIcons.archive, size: widget.radius)
                      : snapshot.data == null
                          ? widget.icon == null
                              ? Txt(("${toTitleCase(widget.item.title)} ").substring(0, 1))
                              : Icon(widget.icon, size: widget.radius)
                          : null,
                );
              }),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(1.5, 5, 10, 5),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 0.5,
                  strokeAlign: BorderSide.strokeAlignOutside),
            ),
            child: Container(
              constraints: BoxConstraints(
                  minWidth: widget.maxWidth < 100 ? widget.maxWidth : 100,
                  maxWidth: widget.maxWidth),
              padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Txt(
                    widget.item is Doctor
                        ? 'Dr. ${toTitleCase(widget.item.title)}'
                        : toTitleCase(widget.item.title),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: widget.fontSize ?? 14),
                  ),
                  if (widget.item is Patient)
                    Txt(
                      (widget.item as Patient).phone,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        )
      ]),
    );
  }
}
