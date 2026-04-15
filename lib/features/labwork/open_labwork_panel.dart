import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/operators_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void openLabwork([Labwork? labwork]) {
  final editingCopy = Labwork.fromJson(labwork?.toJson() ?? {});

  routes.openPanel(Panel(
    item: editingCopy,
    store: labworks,
    icon: FluentIcons.manufacturing,
    title: labworks.get(editingCopy.id) == null
        ? txt("newLabwork")
        : editingCopy.title,
    tabs: [
      PanelTab(
        title: txt("labwork"),
        icon: FluentIcons.manufacturing,
        body: _LabworkEditing(editingCopy),
      ),
    ],
  ));
}

class _LabworkEditing extends StatefulWidget {
  final Labwork labwork;

  const _LabworkEditing(this.labwork);

  @override
  State<_LabworkEditing> createState() => _LabworkEditingState();
}

class _LabworkEditingState extends State<_LabworkEditing> {
  final TextEditingController labNameController = TextEditingController();
  Set<String> selectedTeethSet = {};
  final FocusNode labNameFocusNode = FocusNode();
  double pricePerUnit = 0;

  @override
  void initState() {
    super.initState();
    labNameController.text = widget.labwork.lab;
    labNameController.addListener(() {
      setState(() {});
    });
    selectedTeethSet = Set<String>.from(widget.labwork.selectedTeeth ?? []);
    if ((widget.labwork.noOfUnits ?? 0) > 0) {
      pricePerUnit = (widget.labwork.price ?? 0) / widget.labwork.noOfUnits;
    } else {
      pricePerUnit = 0;
    }
  }

  @override
  void dispose() {
    labNameController.dispose();
    labNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: "${txt("date")}:",
            child: DateTimePicker(
              key: WK.fieldLabworkDate,
              initValue: widget.labwork.date,
              onChange: (d) => widget.labwork.date = d,
              buttonText: txt("changeDate"),
            ),
          ),
          InfoLabel(
            label: "${txt("patient")}:",
            child: PatientPicker(
                value: widget.labwork.patientID,
                onChanged: (id) {
                  widget.labwork.patientID = id;
                }),
          ),
          InfoLabel(
            label: "${txt("doctors")}:",
            child: OperatorsPicker(
                value: widget.labwork.operatorsIDs,
                onChanged: (ids) {
                  widget.labwork.operatorsIDs = ids;
                }),
          ),
          InfoLabel(
            label: "${txt("laboratory")}:",
            child: LaboratoryPicker(
              value: labNameController.text,
              onChanged: (lab) {
                setState(() {
                  labNameController.text = lab ?? "";
                  widget.labwork.lab = lab ?? "";
                });
              },
              focusNode: labNameFocusNode,
              controller: labNameController,
            ),
          ),
          InfoLabel(
            label: "${txt("orderNotes")}:",
            child: CupertinoTextField(
              key: WK.fieldLabworkOrderNotes,
              controller: TextEditingController(text: widget.labwork.note),
              placeholder: "${txt("orderNotes")}...",
              onChanged: (val) {
                widget.labwork.note = val;
              },
              maxLines: null,
            ),
          ),
          TeethPicker(
            selectedTeeth: selectedTeethSet,
            isAdult: selectedTeethSet.every((t) =>
                t.startsWith('1') ||
                t.startsWith('2') ||
                t.startsWith('3') ||
                t.startsWith('4')),
            onChanged: (teeth) {
              setState(() {
                selectedTeethSet = teeth;
                widget.labwork.selectedTeeth = selectedTeethSet.toList();
              });
            },
          ),
          InfoLabel(
            label: "${txt("typeOfWork")}:",
            child: ComboBox<String>(
              value: widget.labwork.typeOfWork.isNotEmpty
                  ? widget.labwork.typeOfWork
                  : null,
              items: [
                "Zirconia",
                "PFM",
                "RPD",
                "Denture",
                "Implant",
                "ESSIX",
                "Other"
              ]
                  .map((type) =>
                      ComboBoxItem<String>(value: type, child: Text(type)))
                  .toList(),
              placeholder: Text("${txt("selectTypeOfWork")}..."),
              onChanged: (val) {
                setState(() {
                  widget.labwork.typeOfWork = val ?? "";
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          InfoLabel(
            label: "${txt("noOfUnits")}:",
            child: NumberBox(
              key: WK.fieldLabworkNoOfUnits,
              style: textFieldTextStyle(),
              clearButton: false,
              mode: SpinButtonPlacementMode.inline,
              value: widget.labwork.noOfUnits.toDouble(),
              min: 0,
              onChanged: (n) {
                setState(() {
                  widget.labwork.noOfUnits = n?.toInt() ?? 0;
                  widget.labwork.price =
                      pricePerUnit * widget.labwork.noOfUnits;
                });
              },
            ),
          ),
          InfoLabel(
            label: "Price per Unit:",
            child: NumberBox(
              key: WK.fieldLabworkPricePerUnit,
              style: textFieldTextStyle(),
              clearButton: false,
              value: pricePerUnit,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              min: 0,
              onChanged: (n) {
                setState(() {
                  pricePerUnit = n ?? 0;
                  widget.labwork.price =
                      pricePerUnit * widget.labwork.noOfUnits;
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          InfoLabel(
            label: "${txt("shade")}:",
            child: ComboBox<String>(
              value:
                  widget.labwork.shade.isNotEmpty ? widget.labwork.shade : null,
              items: [
                "0M1",
                "0M2",
                "0M3",
                "1M1",
                "1M2",
                "2L1.5",
                "2L2.5",
                "2M1",
                "2M2",
                "2M3",
                "2R1.5",
                "2R2.5",
                "3L1.5",
                "3L2.5",
                "3M1",
                "3M2",
                "3M3",
                "3R1.5",
                "3R2.5"
              ]
                  .map((shade) =>
                      ComboBoxItem<String>(value: shade, child: Text(shade)))
                  .toList(),
              placeholder: Text("${txt("selectShade")}..."),
              onChanged: (val) {
                setState(() {
                  widget.labwork.shade = val ?? "";
                });
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InfoLabel(
                  label:
                      "${txt("priceIn")} ${globalSettings.get("currency_______").value}",
                  child: NumberBox(
                    key: WK.fieldLabworkPrice,
                    style: textFieldTextStyle(),
                    clearButton: false,
                    mode: SpinButtonPlacementMode.inline,
                    value: widget.labwork.price,
                    onChanged: (n) {
                      setState(() {
                        // widget.labwork.noOfUnits = n?.toInt() ?? 0;
                        // widget.labwork.price =
                        //     pricePerUnit * widget.labwork.noOfUnits;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Padding(
                padding: const EdgeInsets.only(top: 22.5),
                child: Checkbox(
                  key: WK.fieldLabworkPaidToggle,
                  checked: widget.labwork.paid,
                  onChanged: (n) {
                    setState(() {
                      widget.labwork.paid = n == true;
                    });
                  },
                  content: widget.labwork.paid
                      ? Txt(txt("paid"))
                      : Txt(txt("unpaid")),
                ),
              )
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                checked: widget.labwork.deliveredToDoctor == true,
                onChanged: (val) {
                  setState(() {
                    widget.labwork.deliveredToDoctor = val ?? false;
                  });
                },
                content: Txt(txt("deliveredToDoctor")),
              ),
              const SizedBox(height: 10),
              Checkbox(
                checked: widget.labwork.deliveredToPatient == true,
                onChanged: (val) {
                  setState(() {
                    widget.labwork.deliveredToPatient = val ?? false;
                  });
                },
                content: Txt(txt("deliveredToPatient")),
              ),
            ],
          ),
        ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
      ),
    );
  }
}

class LaboratoryPicker extends StatelessWidget {
  final void Function(String? labName) onChanged;
  final String? value;
  final FocusNode? focusNode;
  final TextEditingController? controller;

  const LaboratoryPicker({
    super.key,
    required this.onChanged,
    this.value,
    this.focusNode,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TagInputWidget(
      key: WK.fieldLabworkLabName,
      focusNode: focusNode,
      controller: controller,
      suggestions: labworks.predefinedLabs
          .map((e) => TagInputItem(value: e, label: e))
          .toList(),
      onChanged: (s) {
        if (s.isEmpty) return onChanged(null);
        onChanged(s.first.value ?? "");
      },
      initialValue: value != null && value!.isNotEmpty
          ? [TagInputItem(value: value!, label: value!)]
          : [],
      strict: false,
      limit: 1,
      placeholder: txt("laboratory"),
      clearButton: true,
    );
  }
}

BoxDecoration textFieldDecoration() {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(5),
    border: Border.all(color: const Color.fromARGB(255, 192, 192, 192)),
  );
}

WidgetStateProperty<BoxDecoration>? textFieldDecorationProperty() {
  return WidgetStateProperty.all(
    BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: const Color.fromARGB(255, 192, 192, 192)),
    ),
  );
}

TextStyle textFieldTextStyle() {
  return const TextStyle(
    fontSize: 16,
  );
}
