import 'dart:convert';

import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/dialogs/import_photos_dialog.dart';
import 'package:apexo/common_widgets/teeth_picker.dart';
import 'package:apexo/features/appointments/sittings_checkbox.dart';
import 'package:apexo/features/appointments/treatment_model.dart';
import 'package:apexo/features/data/prescriptions_model.dart';
import 'package:apexo/features/data/prescriptions_store.dart';
import 'package:apexo/utils/imgs.dart';
import 'package:apexo/utils/logger.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/open_add_patient_popup.dart';

import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/grid_gallery.dart';
import 'package:apexo/common_widgets/operators_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/utils/clinic_time.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart' as material;

void openAppointment([Appointment? appointment, int initialTab = 0]) {
  final editingCopy = Appointment.fromJson(appointment?.toJson() ?? {});
  final panel = Panel(
    item: editingCopy,
    store: appointments,
    icon: FluentIcons.calendar,
    title: appointments.get(editingCopy.id) == null
        ? txt("addAppointment")
        : editingCopy.title,
    tabs: [],
  );

  final tabs = [
    PanelTab(
      title: txt("appointment"),
      icon: FluentIcons.calendar,
      body: _AppointmentDetails(editingCopy),
    ),
    PanelTab(
      title: txt("operativeDetails"),
      icon: FluentIcons.medical_care,
      onlyIfSaved: true,
      body: _OperativeDetails(editingCopy),
    ),
    PanelTab(
      title: txt("prescription"),
      icon: FluentIcons
          .medical, // You can use FluentIcons.prescriptions or another suitable icon
      onlyIfSaved: true,
      body: InfoLabel(
        label: txt("prescription"),
        child: PrescriptionInput(
          allPrescriptions: prescriptionsStore.prescriptions,
          initialPrescriptions: editingCopy.prescriptions,
          panel: panel,
          onChanged: (s) async {
            editingCopy.prescriptions = s;

            // Add new prescriptions to the store/remote if they don't exist
            for (final prescription in s) {
              final exists = prescriptionsStore.present.values
                  .any((p) => p.prescription == prescription);
              if (!exists) {
                Prescriptions prescriptions = Prescriptions();
                prescriptions.prescription = prescription;
                prescriptionsStore.set(prescriptions);
              }
            }
          },
          appointment: editingCopy,
        ),
      ),
    ),
    PanelTab(
      title: txt("gallery"),
      icon: FluentIcons.camera,
      body: _AppointmentGallery(panel),
      onlyIfSaved: true,
      footer: kIsWeb
          ? null
          : _AppointmentGalleryFooter(
              panel), // TODO: image upload isn't supported on web
      padding: 0,
    ),
  ];
  panel.tabs.addAll(tabs);
  panel.selectedTab(initialTab.clamp(0, tabs.length - 1));
  routes.openPanel(panel);
}

class _AppointmentGalleryFooter extends StatefulWidget {
  final Panel<Appointment> panel;
  const _AppointmentGalleryFooter(this.panel);

  @override
  State<_AppointmentGalleryFooter> createState() =>
      _AppointmentGalleryFooterState();
}

class _AppointmentGalleryFooterState extends State<_AppointmentGalleryFooter> {
  @override
  Widget build(BuildContext context) {
    return Acrylic(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FilledButton(
              child: Row(
                children: [
                  const Icon(FluentIcons.link),
                  const SizedBox(width: 5),
                  Txt(txt("link")),
                ],
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return ImportDialog(panel: widget.panel);
                  },
                );
              },
            ),
            if (ImagePicker().supportsImageSource(ImageSource.camera))
              FilledButton(
                child: Row(
                  children: [
                    const Icon(FluentIcons.camera),
                    const SizedBox(width: 5),
                    Txt(txt("camera")),
                  ],
                ),
                onPressed: () async {
                  final XFile? res =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (res == null) return;
                  widget.panel.inProgress(true);
                  try {
                    final imgName = await handleNewImage(
                        rowID: widget.panel.item.id, targetPath: res.path);
                    if (widget.panel.item.imgs.contains(imgName) == false) {
                      widget.panel.item.imgs.add(imgName);
                      appointments.set(widget.panel.item);
                      widget.panel.savedJson =
                          jsonEncode(widget.panel.item.toJson());
                    }
                  } catch (e, s) {
                    logger("Error during uploading camera capture: $e", s);
                  }
                  widget.panel.selectedTab(widget.panel.selectedTab());
                  widget.panel.inProgress(false);
                },
              ),
            FilledButton(
              child: Row(
                children: [
                  const Icon(FluentIcons.photo2_add),
                  const SizedBox(width: 5),
                  Txt(txt("upload")),
                ],
              ),
              onPressed: () async {
                List<XFile> res = await ImagePicker()
                    .pickMultiImage(limit: 50 - widget.panel.item.imgs.length);
                widget.panel.inProgress(true);
                try {
                  for (var img in res) {
                    final imgName = await handleNewImage(
                        rowID: widget.panel.item.id, targetPath: img.path);
                    if (widget.panel.item.imgs.contains(imgName) == false) {
                      widget.panel.item.imgs.add(imgName);
                      appointments.set(widget.panel.item);
                      widget.panel.savedJson =
                          jsonEncode(widget.panel.item.toJson());
                      widget.panel.selectedTab(widget.panel.selectedTab());
                    }
                  }
                } catch (e, s) {
                  logger("Error during file upload: $e", s);
                }
                widget.panel.inProgress(false);
                widget.panel.selectedTab(widget.panel.selectedTab());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentGallery extends StatefulWidget {
  final Panel<Appointment> panel;
  const _AppointmentGallery(this.panel);

  @override
  State<_AppointmentGallery> createState() => _AppointmentGalleryState();
}

class _AppointmentGalleryState extends State<_AppointmentGallery> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.panel.selectedTab.stream,
        builder: (context, _) {
          return widget.panel.item.imgs.isEmpty
              ? Center(
                  child: InfoBar(
                      title: Txt(txt("emptyGallery")),
                      content: Txt(txt("noPhotos"))))
              : StreamBuilder(
                  stream: widget.panel.inProgress.stream,
                  builder: (context, snapshot) {
                    return GridGallery(
                      rowId: widget.panel.item.id,
                      imgs: widget.panel.item.imgs,
                      progress: widget.panel.inProgress(),
                      onPressDelete: (img) async {
                        widget.panel.inProgress(true);
                        try {
                          await appointments.deleteImg(
                              widget.panel.item.id, img);
                          widget.panel.item.imgs.remove(img);
                          appointments.set(widget.panel.item);
                          widget.panel.savedJson =
                              jsonEncode(widget.panel.item.toJson());
                        } catch (e, s) {
                          logger("Error during deleting image: $e", s);
                        }
                        widget.panel.inProgress(false);
                        widget.panel.selectedTab(widget.panel.selectedTab());
                      },
                    );
                  });
        });
  }
}

class _AppointmentDetails extends StatefulWidget {
  final Appointment appointment;
  const _AppointmentDetails(this.appointment);

  @override
  State<_AppointmentDetails> createState() => _AppointmentDetailsState();
}

class _AppointmentDetailsState extends State<_AppointmentDetails> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          /// rebuild needed if a patient is selected/deselected
          key: Key(widget.appointment.patientID ?? ""),
          label: "${txt("patient")}:",
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: PatientPicker(
                      value: widget.appointment.patientID,
                      onChanged: (id) {
                        setState(() {
                          widget.appointment.patientID = id;
                        });
                      }),
                ),
                const SizedBox(width: 5),
                if (widget.appointment.patientID == null)
                  Container(
                    decoration: const BoxDecoration(
                      color: material.Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        FluentIcons.add,
                        color: material.Colors.white, // White icon
                      ),
                      onPressed: () async {
                        final newPatient = await openAddPatientPopup(
                          context: context,
                        );
                        if (newPatient == null) return;
                        widget.appointment.patientID = newPatient.id;
                      },
                    ),
                  ),
              ]),
        ),
        InfoLabel(
          label: "${txt("doctors")}:",
          child: OperatorsPicker(
              value: widget.appointment.operatorsIDs,
              onChanged: (s) {
                widget.appointment.operatorsIDs = s;
              }),
        ),
        Column(
          children: [
            InfoLabel(
              label: "${txt("date")}:",
              child: DateTimePicker(
                key: WK.fieldAppointmentDate,
                initValue: widget.appointment.date,
                onChange: (d) {
                  widget.appointment.date = DateTime(
                    d.year,
                    d.month,
                    d.day,
                    widget.appointment.date.hour,
                    widget.appointment.date.minute,
                  );
                },
                buttonText: txt("changeDate"),
                buttonIcon: FluentIcons.calendar,
                format: "d MMMM yyyy",
              ),
            ),
            const SizedBox(height: 5),
            if (widget.appointment.operators.isNotEmpty &&
                !widget.appointment.availableWeekDays
                    .contains(widget.appointment.date.weekday))
              InfoBar(
                title: Txt(txt("attention")),
                content: Txt(txt("doctorNotAvailable")),
                severity: InfoBarSeverity.warning,
              )
          ],
        ),
        InfoLabel(
          label: "${txt("time")}:",
          child: DateTimePicker(
            key: WK.fieldAppointmentTime,
            initValue: widget.appointment.date,
            onChange: (d) => {
              widget.appointment.date = DateTime(
                widget.appointment.date.year,
                widget.appointment.date.month,
                widget.appointment.date.day,
                d.hour,
                d.minute,
              )
            },
            buttonText: txt("changeTime"),
            pickTime: true,
            buttonIcon: FluentIcons.clock,
            format: "hh:mm a",
          ),
        ),
        InfoLabel(
          label: "${txt("preOperativeNotes")}:",
          child: CupertinoTextField(
            key: WK.fieldAppointmentPreOpNotes,
            expands: true,
            maxLines: null,
            controller:
                TextEditingController(text: widget.appointment.preOpNotes),
            onChanged: (v) => widget.appointment.preOpNotes = v,
            placeholder: "${txt("preOperativeNotes")}...",
          ),
        ),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}

class _OperativeDetails extends StatefulWidget {
  final Appointment appointment;
  const _OperativeDetails(this.appointment);

  @override
  State<_OperativeDetails> createState() => _OperativeDetailsState();
}

class _OperativeDetailsState extends State<_OperativeDetails> {
  final TextEditingController postOpNotesController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController paidController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  String discountType = 'flat'; // 'flat' or 'percent'
  bool didNotEditPaidYet = true;
  Set<String> selectedTreatments = {};
  double originalPrice = 0;
  Set<String> selectedTeethSet = {};
  bool isAdult = true;
  List<bool> rctChecked = List<bool>.filled(rctSittings.length, false);
  List<bool> crownChecked = List<bool>.filled(crownSittings.length, false);

  void setToDone() {
    setState(() {
      widget.appointment.isDone = true;
    });
  }

  @override
  void initState() {
    super.initState();
    postOpNotesController.text = widget.appointment.postOpNotes;
    priceController.text = widget.appointment.price.toStringAsFixed(0);
    paidController.text = widget.appointment.paid.toStringAsFixed(0);

    // Pre-populate discount fields from model
    discountController.text = widget.appointment.discount == 0
        ? ''
        : widget.appointment.discount.toString();
    discountType = widget.appointment.discountType;

    if (widget.appointment.paid != 0) didNotEditPaidYet = false;
    if (widget.appointment.selectedTreatments.isNotEmpty) {
      selectedTreatments = widget.appointment.selectedTreatments.toSet();
    } else {
      selectedTreatments = {};
    }
    // Initialize selectedTeethSet from the saved appointment value
    selectedTeethSet = Set<String>.from(widget.appointment.selectedTeeth);
    widget.appointment.treatmentGpayPaid = widget.appointment.treatmentGpayPaid;
    final normalizedSubTreatments = widget.appointment.subTreatments
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toSet();
    if (normalizedSubTreatments.contains('Access opening') ||
        normalizedSubTreatments.contains('BMP')) {
      normalizedSubTreatments
        ..remove('Access opening')
        ..remove('BMP')
        ..add('AO & BMP');
      widget.appointment.subTreatments =
          normalizedSubTreatments.toList(growable: false);
    }
    for (int i = 0; i < rctSittings.length; i++) {
      rctChecked[i] = normalizedSubTreatments.contains(rctSittings[i]);
    }
    // Set initial checked state for Crown sittings
    for (int i = 0; i < crownSittings.length; i++) {
      crownChecked[i] = normalizedSubTreatments.contains(crownSittings[i]);
    }
    originalPrice = widget.appointment.price;
    _applyDiscount();
  }

  void updateSelectedTreatments() {
    widget.appointment.selectedTreatments = selectedTreatments.toList();
    double total = 0;
    for (final treatment in allTreatments) {
      if (selectedTreatments.contains(treatment.name)) {
        if (treatment.multiplier) {
          total += treatment.price *
              (selectedTeethSet.isNotEmpty ? selectedTeethSet.length : 1);
        } else {
          total += treatment.price;
        }
      }
    }
    priceController.text = (total == 0.0) ? '' : total.toStringAsFixed(0);
    widget.appointment.price = total;
    originalPrice = total;
    _applyDiscount();
  }

  void _applyDiscount() {
    double discount = double.tryParse(discountController.text) ?? 0;
    double finalPrice = originalPrice;
    if (discount > 0) {
      if (discountType == 'percent') {
        finalPrice = originalPrice - (originalPrice * discount / 100);
      } else {
        finalPrice = originalPrice - discount;
      }
      if (finalPrice < 0) finalPrice = 0;
    }
    // Save to model
    widget.appointment.discount = discount;
    widget.appointment.discountType = discountType;

    priceController.text =
        finalPrice == 0 ? '0' : finalPrice.toStringAsFixed(0);
    widget.appointment.price = finalPrice;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final previousAppointments = (appointments.present.values
        .where((a) =>
          a.id != widget.appointment.id &&
          a.patientID == widget.appointment.patientID &&
          a.date.isBefore(widget.appointment.date))
        .toList()
        ..sort((a, b) => b.date.compareTo(a.date)))
      .take(10)
      .toList(growable: false);
    final Appointment? lastAppointment =
      previousAppointments.isEmpty ? null : previousAppointments.first;
    final timelineAppointments = previousAppointments.length <= 1
      ? <Appointment>[]
      : previousAppointments.sublist(1);

    final double discount = double.tryParse(discountController.text) ?? 0;
    double discountValue = 0;
    if (discountType == 'percent') {
      discountValue = originalPrice * discount / 100;
    } else {
      discountValue = discount;
    }
    final double discountedPrice =
        (originalPrice - discountValue).clamp(0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: "${txt("doctors")}:",
              child: OperatorsPicker(
                value: widget.appointment.operatorsIDs,
                onChanged: (s) {
                  setState(() {
                    widget.appointment.operatorsIDs = s;
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            InfoLabel(
              label: "Diagnosis:",
              child: TagInputWidget(
                key: WK.fieldAppointmentDiagnosis,
                suggestions: [
                  // You can define a list of diagnosis options, or use allTreatments if you want
                  ...allDiagnosis.map((d) => TagInputItem(
                        value: d,
                        label: d,
                      )),
                ],
                onChanged: (s) {
                  setState(() {
                    widget.appointment.diagnosis = s
                        .where((x) => x.value != null)
                        .map((x) => x.value!)
                        .toList();
                  });
                },
                initialValue: [
                  ...widget.appointment.diagnosis
                      .map((v) => TagInputItem(value: v, label: v)),
                ],
                strict: false,
                limit: 999,
                placeholder: "Diagnosis...",
              ),
            ),
            const SizedBox(height: 10),
            InfoLabel(
              label: "${txt("treatment")}:",
              child: TagInputWidget(
                key: WK.fieldAppointmentTreatments,
                suggestions: [
                  // Main treatments
                  ...allTreatments.map((t) => TagInputItem(
                        value: t.name,
                        label: "${t.name} - ₹${t.price}",
                      )),
                ],
                onChanged: (s) {
                  setState(() {
                    selectedTreatments = s
                        .where((x) => x.value != null)
                        .map((x) => x.value!)
                        .toSet();
                    updateSelectedTreatments();
                  });
                },
                initialValue: [
                  // Pre-select already selected treatments and sub-treatments
                  ...selectedTreatments.map((v) {
                    // Find the label for the value
                    final main = allTreatments.firstWhere(
                      (t) => t.name == v,
                      orElse: () => Treatment(
                          name: '', price: 0), // Provide a default Treatment
                    );
                    if (main.name.isNotEmpty) {
                      // found
                      return TagInputItem(
                          value: v, label: "${main.name} - ₹${main.price}");
                    }
                    return TagInputItem(value: v, label: v);
                  }),
                ],
                strict: false,
                limit: 999,
                placeholder: "${txt("treatments")}...",
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Show for RCT
        if (selectedTreatments.contains("RCT")) ...[
          SittingsCheckboxGroup(
            label: "RCT Sittings",
            sittings: rctSittings,
            checked: rctChecked,
            onChanged: (idx) {
              setState(() {
                // Toggle only the selected index
                rctChecked[idx] = !rctChecked[idx];
                // Update subTreatments with selected RCT sittings
                widget.appointment.subTreatments = [
                  for (int i = 0; i < rctSittings.length; i++)
                    if (rctChecked[i]) rctSittings[i]
                ];
              });
            },
          ),
          const SizedBox(height: 8),
        ],

// Show for PFM or Zirconia crown
        if (selectedTreatments
            .any((t) => t.toLowerCase().contains("crown"))) ...[
          SittingsCheckboxGroup(
            label: "Crown Sittings",
            sittings: crownSittings,
            checked: crownChecked,
            onChanged: (idx) {
              setState(() {
                crownChecked[idx] = !crownChecked[idx];
                // Update subTreatments with selected Crown sittings
                widget.appointment.subTreatments = [
                  for (int i = 0; i < crownSittings.length; i++)
                    if (crownChecked[i]) crownSittings[i]
                ];
              });
            },
          ),
        ],
        _LastAppointmentCard(lastAppointment: lastAppointment),
        const SizedBox(height: 8),
        _AppointmentTimeline(appointments: timelineAppointments),
        const SizedBox(height: 8),
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
              widget.appointment.selectedTeeth = selectedTeethSet.toList();
              updateSelectedTreatments();
            });
          },
        ),
        const SizedBox(height: 16),
        InfoLabel(
          label: "${txt("postOperativeNotes")}:",
          child: CupertinoTextField(
            key: WK.fieldAppointmentPostOpNotes,
            expands: true,
            maxLines: null,
            controller: postOpNotesController,
            onChanged: (v) {
              setState(() {
                widget.appointment.postOpNotes = v;
                widget.appointment.isDone = true;
              });
            },
            placeholder: txt("postOperativeNotes"),
          ),
        ),
        InfoLabel(
          label: txt("discount"),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CupertinoTextField(
                controller: discountController,
                placeholder: txt("discount"),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))
                ],
                onChanged: (v) {
                  setState(() {
                    _applyDiscount();
                  });
                },
                style: const TextStyle(fontWeight: FontWeight.bold),
                prefix: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Icon(material.Icons.discount,
                      color: material.Colors.blue, size: 18),
                ),
                suffix: Tooltip(
                  message: discountType == 'percent'
                      ? txt("percentDiscount")
                      : txt("flatDiscount"),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        discountType =
                            discountType == 'percent' ? 'flat' : 'percent';
                        _applyDiscount();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: discountType == 'percent'
                              ? material.Colors.blue.withValues(alpha: 0.15)
                              : material.Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          discountType == 'percent' ? "%" : txt("₹"),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: material.Colors.grey.shade300),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              ),
              // Add error messages here
              if (discountType == 'flat' &&
                  (double.tryParse(discountController.text) ?? 0) >
                      originalPrice)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(
                    txt("discountMoreThanPrice"),
                    style: const TextStyle(
                      color: material.Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (discountType == 'percent' &&
                  (double.tryParse(discountController.text) ?? 0) > 100)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8),
                  child: Text(
                    txt("discountPercentMoreThan100"),
                    style: const TextStyle(
                      color: material.Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (discountController.text.trim().isNotEmpty &&
            discountValue <= originalPrice)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: material.Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(material.Icons.attach_money,
                        color: material.Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      txt("totalPrice"),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      originalPrice == 0
                          ? ''
                          : "${originalPrice.toStringAsFixed(0)} ${globalSettings.get("currency_______").value}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(material.Icons.discount,
                        color: material.Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      txt("discountedPrice"),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: material.Colors.red),
                    ),
                    const Spacer(),
                    Text(
                      discountValue == 0
                          ? "0 ${globalSettings.get("currency_______").value}"
                          : "-${discountValue.toStringAsFixed(0)} ${globalSettings.get("currency_______").value}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: material.Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(material.Icons.check_circle,
                        color: material.Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      txt("priceAfterDiscount"),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: material.Colors.green),
                    ),
                    const Spacer(),
                    Text(
                      discountedPrice == 0
                          ? "0 ${globalSettings.get("currency_______").value}"
                          : "${discountedPrice.toStringAsFixed(0)} ${globalSettings.get("currency_______").value}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: material.Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // if (widget.appointment.prescriptions.isNotEmpty)
        //   FilledButton(
        //       style: const ButtonStyle(elevation: WidgetStatePropertyAll(2)),
        //       child: Row(
        //         mainAxisSize: MainAxisSize.min,
        //         children: [
        //           const Icon(FluentIcons.print),
        //           const SizedBox(width: 10),
        //           Txt(txt("printPrescription"))
        //         ],
        //       ),
        //       onPressed: () {
        //         printingPrescription(
        //           context,
        //           widget.appointment.prescriptions,
        //           widget.appointment.patient?.title ?? "",
        //           widget.appointment.patient?.age.toString() ?? "",
        //           widget.appointment.patient?.webPageLink.toString() ?? "",
        //       });
        //       }),
        const Divider(direction: Axis.horizontal),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label:
                    "${txt("priceIn")} ${globalSettings.get("currency_______").value}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPrice,
                  controller: priceController,
                  onChanged: (v) {
                    setState(() {
                      widget.appointment.price = double.tryParse(v) ?? 0;
                      if (didNotEditPaidYet) {
                        widget.appointment.paid = double.tryParse(v) ?? 0;
                        paidController.text =
                            widget.appointment.paid.toStringAsFixed(0);
                      }
                      widget.appointment.isDone = true;
                    });
                  },
                  placeholder: txt("price"),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InfoLabel(
                label:
                    "${txt("paidIn")} ${globalSettings.get("currency_______").value}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPayment,
                  controller: paidController,
                  onChanged: (v) {
                    setState(() {
                      didNotEditPaidYet = false;
                      widget.appointment.paid = double.tryParse(v) ?? 0;
                      widget.appointment.isDone = true;
                    });
                  },
                  placeholder: txt("paid"),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(direction: Axis.horizontal),
        Checkbox(
          checked: widget.appointment.treatmentGpayPaid,
          onChanged: (checked) {
            setState(() {
              widget.appointment.treatmentGpayPaid = checked ?? false;
            });
          },
          content: const Txt("Paid via UPI"),
        ),

        const Divider(direction: Axis.horizontal),
        Checkbox(
          checked: widget.appointment.isDone,
          onChanged: (checked) {
            setState(() {
              widget.appointment.isDone = checked == true;
            });
          },
          content: Txt(txt("isDone")),
        ),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: () async {
              appointments.set(widget.appointment);
              routes.closePanel(widget.appointment.id);
              // Create a new appointment with the same patient ID
              final newAppointment = Appointment.fromJson({});
              newAppointment.patientID = widget.appointment.patientID;

              // Open the new appointment panel with the patient pre-selected
              openAppointment(newAppointment);
            },
            style: ButtonStyle(
              textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
              backgroundColor: WidgetStatePropertyAll(Colors.blue),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.save),
                SizedBox(width: 8),
                Txt("Save & Book New Appointment"),
              ],
            )),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}

class _LastAppointmentCard extends StatelessWidget {
  final Appointment? lastAppointment;

  const _LastAppointmentCard({required this.lastAppointment});

  @override
  Widget build(BuildContext context) {
    if (lastAppointment == null) {
      return const Text(
        'No previous appointment history available.',
        style: TextStyle(
          color: Color(0xFF5B7394),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final item = lastAppointment!;
    final treatmentSummary = item.selectedTreatments
        .where((v) => v.trim().isNotEmpty)
        .join(', ');
    final subTreatmentSummary =
        item.subTreatments.where((v) => v.trim().isNotEmpty).join(', ');
    final doctorSummary = item.operators.isEmpty
        ? 'Unassigned'
        : item.operators
            .map((d) => d.title.trim().isEmpty ? 'Unnamed doctor' : d.title)
            .join(', ');
    final teethSummary =
        item.selectedTeeth.where((v) => v.trim().isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Last Appointment',
          style: TextStyle(
            color: Color(0xFF223B5E),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatClinicDateTime(item.date, pattern: 'dd MMM yyyy • h:mm a'),
          style: const TextStyle(
            color: Color(0xFF355279),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Doctor: $doctorSummary',
          style: const TextStyle(
            color: Color(0xFF5B7394),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Treatment: ${treatmentSummary.isEmpty ? '-' : treatmentSummary}',
          style: const TextStyle(
            color: Color(0xFF5B7394),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subTreatmentSummary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Sub-treatment: $subTreatmentSummary',
            style: const TextStyle(
              color: Color(0xFF5B7394),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Teeth: ${teethSummary.isEmpty ? '-' : teethSummary}',
          style: const TextStyle(
            color: Color(0xFF5B7394),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AppointmentTimeline extends StatelessWidget {
  final List<Appointment> appointments;

  const _AppointmentTimeline({required this.appointments});

  @override
  Widget build(BuildContext context) {
    final rows = appointments.take(6).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Journey Timeline',
          style: TextStyle(
            color: Color(0xFF2C4E76),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            'No timeline data available.',
            style: TextStyle(color: Color(0xFF6D84A8), fontSize: 12),
          )
        else
          ...rows.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == rows.length - 1;
            final treatments = item.selectedTreatments
                .where((v) => v.trim().isNotEmpty)
                .join(', ');
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D7BD8),
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: const Color(0xFFCFE0F3),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatClinicDateTime(
                            item.date,
                            pattern: 'dd MMM yyyy • h:mm a',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF1F446E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          treatments.isEmpty ? '-' : treatments,
                          style: const TextStyle(
                            color: Color(0xFF5F789B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }
}

class PrescriptionInput extends StatefulWidget {
  final List<String> allPrescriptions;
  final List<String> initialPrescriptions;
  final ValueChanged<List<String>> onChanged;
  final Appointment appointment;
  final Panel panel;

  const PrescriptionInput({
    super.key,
    required this.allPrescriptions,
    required this.initialPrescriptions,
    required this.onChanged,
    required this.panel,
    required this.appointment,
  });

  @override
  State<PrescriptionInput> createState() => _PrescriptionInputState();
}

class _PrescriptionInputState extends State<PrescriptionInput> {
  late TextEditingController priceController;
  late TextEditingController paidController;

  @override
  void initState() {
    super.initState();
    priceController = TextEditingController(
      text: widget.appointment.prescriptionPrice == 0
          ? ''
          : widget.appointment.prescriptionPrice.toStringAsFixed(0),
    );
    paidController = TextEditingController(
      text: widget.appointment.prescriptionPaid == 0
          ? ''
          : widget.appointment.prescriptionPaid.toStringAsFixed(0),
    );
    widget.appointment.prescriptionGpayPaid =
        widget.appointment.prescriptionGpayPaid;
  }

  @override
  void didUpdateWidget(covariant PrescriptionInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if the model changes from outside
    final priceText = widget.appointment.prescriptionPrice == 0
        ? ''
        : widget.appointment.prescriptionPrice.toStringAsFixed(0);
    if (priceController.text != priceText) {
      priceController.text = priceText;
    }
    final paidText = widget.appointment.prescriptionPaid == 0
        ? ''
        : widget.appointment.prescriptionPaid.toStringAsFixed(0);
    if (paidController.text != paidText) {
      paidController.text = paidText;
    }
  }

  @override
  void dispose() {
    priceController.dispose();
    paidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TagInputWidget(
          key: WK.fieldAppointmentPrescriptions,
          suggestions: widget.allPrescriptions
              .map((p) => TagInputItem(value: p, label: p))
              .toList(),
          onChanged: (s) {
            widget.onChanged(
              s.where((x) => x.value != null).map((x) => x.value!).toList(),
            );
            widget.panel.hasUnsavedChanges(true);
          },
          initialValue: widget.initialPrescriptions
              .map((p) => TagInputItem(value: p, label: p))
              .toList(),
          strict: false,
          limit: 999,
          placeholder: "${txt("prescription")}...",
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label:
                    "${txt("priceIn")} ${globalSettings.get("currency_______").value}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPrice,
                  controller: priceController,
                  onChanged: (v) {
                    final val = double.tryParse(v) ?? 0;
                    widget.appointment.prescriptionPrice = val;
                    widget.panel.hasUnsavedChanges(true);
                  },
                  placeholder: txt("price"),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InfoLabel(
                label:
                    "${txt("paidIn")} ${globalSettings.get("currency_______").value}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPayment,
                  controller: paidController,
                  onChanged: (v) {
                    final val = double.tryParse(v) ?? 0;
                    widget.appointment.prescriptionPaid = val;
                    widget.panel.hasUnsavedChanges(true);
                  },
                  placeholder: txt("paid"),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(direction: Axis.horizontal),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Checkbox(
            checked: widget.appointment.prescriptionGpayPaid,
            onChanged: (checked) {
              setState(() {
                widget.appointment.prescriptionGpayPaid = checked ?? false;
              });
            },
            content: const Txt("Paid via UPI"),
          ),
        ),
      ],
    );
  }
}
