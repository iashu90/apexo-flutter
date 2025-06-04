import 'dart:convert';

import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/dialogs/import_photos_dialog.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/utils/imgs.dart';
import 'package:apexo/utils/logger.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/utils/print/print_prescription.dart';
import 'package:apexo/common_widgets/acrylic_button.dart';
import 'package:apexo/common_widgets/date_time_picker.dart';
import 'package:apexo/common_widgets/grid_gallery.dart';
import 'package:apexo/common_widgets/operators_picker.dart';
import 'package:apexo/common_widgets/patient_picker.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/utils/uuid.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart' as material;

void openAppointment([Appointment? appointment]) {
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
      body: _OperativeDetails(editingCopy),
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
                  AcrylicButton(
                      icon: FluentIcons.add_friend,
                      text: txt("newPatient"),
                      onPressed: () async {
                        final newPatientId = uuid();
                        final newPatient = await openPatient(
                            Patient.fromJson({"id": newPatientId}));
                        routes.closePanel(newPatientId);
                        widget.appointment.patientID = newPatient.id;
                      })
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateSelectedTreatments();
    });
  }

  void updateSelectedTreatments() {
    widget.appointment.selectedTreatments = selectedTreatments.toList();
    double total = 0;
    for (final treatment in widget.appointment.treatments) {
      if (selectedTreatments.contains(treatment.name)) {
        total += treatment.price;
      }
      for (final sub in treatment.subTreatments) {
        final key = '${treatment.name}::${sub.name}';
        if (selectedTreatments.contains(key)) {
          total += sub.price;
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

    priceController.text = finalPrice == 0 ? '' : finalPrice.toStringAsFixed(0);
    widget.appointment.price = finalPrice;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${txt("treatment")}:"),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.appointment.treatments.map((treatment) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Checkbox(
                        checked: selectedTreatments.contains(treatment.name),
                        onChanged: (isChecked) {
                          setState(() {
                            if (isChecked == true) {
                              selectedTreatments.add(treatment.name);
                            } else {
                              selectedTreatments.remove(treatment.name);
                            }
                            updateSelectedTreatments();
                          });
                        },
                        content:
                            Text('${treatment.name} - \₹${treatment.price}'),
                      ),
                    ),
                    ...treatment.subTreatments.map((sub) => Padding(
                          padding:
                              const EdgeInsets.only(left: 24.0, bottom: 8.0),
                          child: Checkbox(
                            checked: selectedTreatments
                                .contains('${treatment.name}::${sub.name}'),
                            onChanged: (isChecked) {
                              setState(() {
                                final key = '${treatment.name}::${sub.name}';
                                if (isChecked == true) {
                                  selectedTreatments.add(key);
                                } else {
                                  selectedTreatments.remove(key);
                                }
                                updateSelectedTreatments();
                              });
                            },
                            content: Text('${sub.name} - \₹${sub.price}'),
                          ),
                        )),
                  ],
                );
              }).toList(),
            ),
          ],
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
            placeholder: "${txt("postOperativeNotes")}",
          ),
        ),
        InfoLabel(
          label: "${txt("prescription")}:",
          child: TagInputWidget(
            key: WK.fieldAppointmentPrescriptions,
            suggestions: appointments.allPrescriptions
                .map((p) => TagInputItem(value: p, label: p))
                .toList(),
            onChanged: (s) {
              setState(() {
                widget.appointment.prescriptions = s
                    .where((x) => x.value != null)
                    .map((x) => x.value!)
                    .toList();
                widget.appointment.isDone = true;
              });
            },
            initialValue: widget.appointment.prescriptions
                .map((p) => TagInputItem(value: p, label: p))
                .toList(),
            strict: false,
            limit: 999,
            placeholder: "${txt("prescription")}...",
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
                prefix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              ? material.Colors.blue.withOpacity(0.15)
                              : material.Colors.green.withOpacity(0.15),
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
        if (discountController.text.trim().isNotEmpty && discountedPrice > 0)
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
                          ? ''
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
                          ? ''
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
        if (widget.appointment.prescriptions.isNotEmpty)
          FilledButton(
              style: const ButtonStyle(elevation: WidgetStatePropertyAll(2)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.print),
                  const SizedBox(width: 10),
                  Txt(txt("printPrescription"))
                ],
              ),
              onPressed: () {
                printingPrescription(
                  context,
                  widget.appointment.prescriptions,
                  widget.appointment.patient?.title ?? "",
                  widget.appointment.patient?.age.toString() ?? "",
                  widget.appointment.patient?.webPageLink.toString() ?? "",
                );
              }),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(FluentIcons.save),
              SizedBox(width: 8),
              Txt("Save & Book New Appointment"),
            ],
          ),
          onPressed: () async {
            appointments.set(widget.appointment);
            routes.closePanel(widget.appointment.id);
            // Create a new appointment with the same patient ID
            final newAppointment = Appointment.fromJson({});
            newAppointment.patientID = widget.appointment.patientID;

            // Open the new appointment panel with the patient pre-selected
            openAppointment(newAppointment);
          },
        ),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}
