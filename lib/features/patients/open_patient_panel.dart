import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/appointments_list_footer.dart';
import 'package:apexo/common_widgets/labwork_card.dart';
import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/labwork/labwork_model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/utils/color_based_on_payment.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/utils/print/print_link.dart';
import 'package:apexo/common_widgets/appointment_card.dart';
import 'package:apexo/common_widgets/call_button.dart';
import 'package:apexo/common_widgets/qrlink.dart';
import 'package:apexo/common_widgets/tag_input.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patient_history_suggestions.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart' hide TextBox;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

Future<Patient> openPatient([Patient? patient, int initialTabIndex = 0]) {
  final editingCopy = Patient.fromJson(patient?.toJson() ?? {});
  late Panel panel;

  // Create a placeholder for the tabs
  late List<PanelTab> tabs;

  panel = Panel<Patient>(
    item: editingCopy,
    store: patients,
    icon: FluentIcons.medication_admin,
    title: patients.get(editingCopy.id) == null
        ? txt("newPatient")
        : editingCopy.title,
    tabs: [],
  );

  // Now that panel is assigned, create the tabs
  tabs = [
    PanelTab(
      title: txt("patientDetails"),
      icon: FluentIcons.medication_admin,
      body: _PatientDetails(editingCopy, panel),
    ),
    // PanelTab(
    //   title: txt("dentalNotes"),
    //   icon: FluentIcons.teeth,
    //   body: DentalChart(patient: editingCopy),
    // ),
    // Add other tabs as needed...
    PanelTab(
      title: txt("appointments"),
      icon: FluentIcons.calendar,
      body: _PatientAppointments(editingCopy),
      footer: AppointmentsListFooter(forPatientID: editingCopy.id),
      onlyIfSaved: true,
      padding: 0,
    ),
    // PanelTab(
    //   title: txt("patientPage"),
    //   icon: FluentIcons.q_r_code,
    //   body: _PatientWebPage(editingCopy),
    //   onlyIfSaved: true,
    //   footer: _PrintQRButton(editingCopy),
    // ),
  ];

  // Assign the tabs to the panel
  panel.tabs.clear();
  panel.tabs.addAll(tabs);

  panel.selectedTab(initialTabIndex);
  routes.openPanel(panel);
  return panel.result.future as Future<Patient>;
}

class _PrintQRButton extends StatelessWidget {
  final Patient patient;
  const _PrintQRButton(this.patient);

  @override
  Widget build(BuildContext context) {
    return Acrylic(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
                child: Row(
                  children: [
                    const Icon(FluentIcons.print),
                    const SizedBox(width: 5),
                    Txt(txt("printQR"))
                  ],
                ),
                onPressed: () {
                  printingQRCode(
                    context,
                    patient.webPageLink,
                    "Access your information",
                    "Scan to visit link:\n${patient.webPageLink}\nto access your appointments, payments and photos.",
                  );
                }),
          ],
        ),
      ),
    );
  }
}

class _PatientWebPage extends StatelessWidget {
  final Patient patient;
  const _PatientWebPage(this.patient);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InfoBar(
        title: Txt(txt("patientCanUseTheFollowing")),
      ),
      const SizedBox(height: 30),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(5),
        ),
        child: SelectableText(patient.webPageLink),
      ),
      QRLink(link: patient.webPageLink)
    ]);
  }
}

class _PatientAppointments extends StatefulWidget {
  final Patient patient;
  const _PatientAppointments(this.patient);

  @override
  _PatientAppointmentsState createState() => _PatientAppointmentsState();
}

class _PatientAppointmentsState extends State<_PatientAppointments> {
  int filterType = 1;
  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        appointments.observableMap.stream,
        showArchived.stream,
        labworks.observableMap.stream
      ],
      builder: (context, snapshot) {
        final patient = widget.patient;
        // Gather all appointments and labworks, sort by date descending
        final allAppointments = patient.allAppointments;
        final allLabworks = labworks.present.values
            .where((lw) => lw.patientID == patient.id)
            .toList();
// Add these state variables in your _PatientAppointments widget (if using StatefulWidget, else convert to one)
        final allItems = [
          if (filterType == 0 || filterType == 1)
            ...allAppointments.map((a) => {
                  "type": "appointment",
                  "date": a.date,
                  "appointment": a,
                }),
          if (filterType == 0 || filterType == 2)
            ...allLabworks.map((lw) => {
                  "type": "labwork",
                  "date": lw.date ?? DateTime.now(),
                  "labwork": lw,
                }),
        ];

        allItems.sort((a, b) {
          final dateA = a["date"] as DateTime?;
          final dateB = b["date"] as DateTime?;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        if (allItems.isEmpty) {
          return Column(
            children: [
              InfoBar(title: Txt(txt("noAppointmentsFound"))),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        filterType = filterType == 1
                            ? 0
                            : 1; // Toggle between both and appointments only
                      });
                    },
                    child: Acrylic(
                      elevation: filterType == 1 ? 40 : 20,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.calendar,
                              color:
                                  filterType == 1 ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Txt(
                              "Treatments: ${allAppointments.length}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: filterType == 1
                                    ? Colors.blue
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        filterType = filterType == 2
                            ? 0
                            : 2; // Toggle between both and labworks only
                      });
                    },
                    child: Acrylic(
                      elevation: filterType == 2 ? 40 : 20,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.test_beaker,
                              color:
                                  filterType == 2 ? Colors.blue : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Txt(
                              "Labworks: ${allLabworks.length}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: filterType == 2
                                    ? Colors.blue
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(allItems.length, (index) {
              final item = allItems[index];
              final isAppointment = item["type"] == "appointment";
              final date = item["date"] as DateTime;

              String? difference;
              if (index != 0) {
                final prevDate = allItems[index - 1]["date"] as DateTime;
                int differenceInDays = date.difference(prevDate).inDays.abs();
                difference =
                    "${txt("before")} $differenceInDays ${txt("day${(differenceInDays > 1) ? "s" : ""}")}";
              }

              if (isAppointment) {
                final appointment = item["appointment"] as Appointment;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppointmentCard(
                      key: Key(appointment.id),
                      appointment: appointment,
                      difference: difference,
                      hide: const [
                        AppointmentSections.patient,
                        AppointmentSections.doctorsPaid
                      ],
                      number: index + 1,
                    ),
                  ],
                );
              } else {
                final lw = item["labwork"] as Labwork;
                return LabworkCard(
                  labwork: lw,
                  number: index + 1,
                  difference: difference,
                );
              }
            }),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 50),
              child: Acrylic(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                elevation: 50,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: kElevationToShadow[4],
                      border: Border(
                          top: BorderSide(
                        color: (colorBasedOnPayments(patient.paymentsMade,
                                    patient.pricesGiven) ??
                                FluentTheme.of(context).cardColor)
                            .withValues(alpha: 0.3),
                        width: 5,
                      ))),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Txt(
                            "${txt("paymentSummary")} (${globalSettings.get("currency_______").value})",
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 15),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          PaymentPill(
                            finalTextColor: Colors.grey,
                            title: txt("cost"),
                            amount: patient.pricesGiven.toString(),
                            color: Colors.white,
                          ),
                          PaymentPill(
                            finalTextColor: Colors.grey,
                            title: txt("paid"),
                            amount: patient.paymentsMade.toString(),
                            color: Colors.white,
                          ),
                          PaymentPill(
                            finalTextColor: Colors.grey,
                            title: patient.overPaid
                                ? txt("overpaid")
                                : patient.underPaid
                                    ? txt("underpaid")
                                    : txt("fullyPaid"),
                            amount: (patient.paymentsMade - patient.pricesGiven)
                                .abs()
                                .toString(),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PatientDetails extends StatefulWidget {
  final Patient patient;
  final Panel panel;
  const _PatientDetails(this.patient, this.panel);

  @override
  State<_PatientDetails> createState() => _PatientDetailsState();
}

class _PatientDetailsState extends State<_PatientDetails> {
  bool showSuccessInfoBar = false;

  bool get _isNameValid => widget.patient.title.trim().isNotEmpty;
  bool get _isAgeValid => (widget.patient.birth ?? 0) > 0;
  bool get _isPhoneValid => widget.patient.phone.trim().isNotEmpty;

  void _refreshValidation() {
    widget.panel.hasValidTitle(_isNameValid && _isAgeValid && _isPhoneValid);
  }

  @override
  void initState() {
    super.initState();
    if (widget.patient.referralSource.trim().isEmpty) {
      widget.patient.referralSource = 'None';
    }
    _refreshValidation();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: "${txt("name")}:",
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldPatientName,
            placeholder: "${txt("name")}...",
            controller: TextEditingController(text: widget.patient.title),
            onChanged: (value) {
              widget.patient.title = value;
              _refreshValidation();
            },
          ),
        ),
        if (!_isNameValid)
          const Text(
            'Patient name is required.',
            style: TextStyle(color: Color(0xFFD6455D), fontSize: 11),
          ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Expanded(
            child: InfoLabel(
              label: "${txt("age")}:",
              isHeader: true,
              child: CupertinoTextField(
                key: WK.fieldPatientYOB,
                placeholder: "${txt("age")}...",
                controller: TextEditingController(
                  text: (widget.patient.birth != null &&
                          widget.patient.birth != 0)
                      ? widget.patient.birth.toString()
                      : '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 3,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                onChanged: (value) {
                  widget.patient.birth = int.tryParse(value) ?? 0;
                  _refreshValidation();
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InfoLabel(
              label: "${txt("gender")}:",
              isHeader: true,
              child: ComboBox<int>(
                key: WK.fieldPatientGender,
                isExpanded: true,
                items: [
                  ComboBoxItem<int>(
                    value: 1,
                    child: Txt("♂️ ${txt("male")}"),
                  ),
                  ComboBoxItem<int>(
                    value: 0,
                    child: Txt("♀️ ${txt("female")}"),
                  )
                ],
                value: widget.patient.gender,
                onChanged: (value) {
                  setState(() {
                    widget.patient.gender = value ?? widget.patient.gender;
                  });
                },
              ),
            ),
          ),
        ]),
        if (!_isAgeValid)
          const Text(
            'Age is required.',
            style: TextStyle(color: Color(0xFFD6455D), fontSize: 11),
          ),
        Row(children: [
          Expanded(
            child: InfoLabel(
              label: "${txt("phone")}:",
              isHeader: true,
              child: CupertinoTextField(
                key: WK.fieldPatientPhone,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                placeholder: "${txt("phone")}...",
                controller: TextEditingController(text: widget.patient.phone),
                onChanged: (value) {
                  widget.patient.phone = value;
                  _refreshValidation();
                },
                prefix: CallIconButton(phoneNumber: widget.patient.phone),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ]),
        if (!_isPhoneValid)
          const Text(
            'Phone number is required.',
            style: TextStyle(color: Color(0xFFD6455D), fontSize: 11),
          ),
        InfoLabel(
          label: "${txt("address")}:",
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldPatientAddress,
            controller: TextEditingController(text: widget.patient.address),
            onChanged: (value) => widget.patient.address = value,
            placeholder: "${txt("address")}...",
          ),
        ),
        InfoLabel(
          label: "${txt("notes")}:",
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldPatientNotes,
            controller: TextEditingController(text: widget.patient.notes),
            onChanged: (value) => widget.patient.notes = value,
            maxLines: null,
            placeholder: "${txt("notes")}...",
          ),
        ),
        InfoLabel(
          label: 'Referral:',
          isHeader: true,
          child: ComboBox<String>(
            isExpanded: true,
            value: (widget.patient.referralSource.trim().isEmpty)
                ? null
                : widget.patient.referralSource,
            placeholder: const Text('Select referral source'),
            items: const [
              ComboBoxItem(value: 'None', child: Text('None')),
              ComboBoxItem(value: 'Google', child: Text('Google')),
              ComboBoxItem(value: 'Social Media', child: Text('Social Media')),
              ComboBoxItem(value: 'Friends', child: Text('Friends')),
              ComboBoxItem(value: 'Camps', child: Text('Camps')),
              ComboBoxItem(value: 'Name Board', child: Text('Name Board')),
            ],
            onChanged: (value) {
              setState(() {
                widget.patient.referralSource = value ?? '';
              });
            },
          ),
        ),
        InfoLabel(
          label: "Medical History:",
          isHeader: true,
          child: TagInputWidget(
            key: WK.fieldPatientTags,
            suggestions: {
              ...patientMedicalHistorySuggestions,
              ...patients.allTags,
            }
                .map((t) => TagInputItem(value: t, label: t))
                .toList(growable: false),
            onChanged: (tags) {
              widget.patient.tags = List<String>.from(
                  tags.map((e) => e.value).where((e) => e != null));
            },
            initialValue: widget.patient.tags
                .map((e) => TagInputItem(value: e, label: e))
                .toList(),
            strict: false,
            limit: 9999,
            placeholder: 'Add medical history...',
          ),
        ),
        InfoLabel(
          label: 'Drug History:',
          isHeader: true,
          child: TagInputWidget(
            suggestions: patientDrugHistorySuggestions
                .map((t) => TagInputItem(value: t, label: t))
                .toList(growable: false),
            onChanged: (tags) {
              widget.patient.drugHistorySuggestions = List<String>.from(
                tags.map((e) => e.value).where((e) => e != null),
              );
            },
            initialValue: widget.patient.drugHistorySuggestions
                .map((e) => TagInputItem(value: e, label: e))
                .toList(),
            strict: false,
            limit: 9999,
            placeholder: 'Add drug history...',
          ),
        ),
        InfoLabel(
          label: 'Maternal History:',
          isHeader: true,
          child: TagInputWidget(
            suggestions: patientMaternalHistorySuggestions
                .map((t) => TagInputItem(value: t, label: t))
                .toList(growable: false),
            onChanged: (tags) {
              widget.patient.maternalHistorySuggestions = List<String>.from(
                tags.map((e) => e.value).where((e) => e != null),
              );
            },
            initialValue: widget.patient.maternalHistorySuggestions
                .map((e) => TagInputItem(value: e, label: e))
                .toList(),
            strict: false,
            limit: 9999,
            placeholder: 'Add maternal history...',
          ),
        ),
        InfoLabel(
          label: 'Habits:',
          isHeader: true,
          child: TagInputWidget(
            suggestions: patientHabitsSuggestions
                .map((t) => TagInputItem(value: t, label: t))
                .toList(growable: false),
            onChanged: (tags) {
              widget.patient.habitsSuggestions = List<String>.from(
                tags.map((e) => e.value).where((e) => e != null),
              );
            },
            initialValue: widget.patient.habitsSuggestions
                .map((e) => TagInputItem(value: e, label: e))
                .toList(),
            strict: false,
            limit: 9999,
            placeholder: 'Add habits...',
          ),
        ),
        const SizedBox(height: 30),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}
