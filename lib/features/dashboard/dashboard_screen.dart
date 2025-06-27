import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/appointment_card.dart';
import 'package:apexo/common_widgets/patients_report_dialog.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/dashboard/completed_pending.dart';
import 'package:apexo/features/dashboard/completed_pending_bar.dart';
import 'package:apexo/features/dashboard/dashboard_controller.dart';
import 'package:apexo/features/dashboard/doctor_patients_list.dart';
import 'package:apexo/features/dashboard/phone_patient_look_up.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/common_widgets/item_title.dart';
import 'package:apexo/features/stats/widgets/charts/bar.dart';
import 'package:apexo/features/stats/widgets/charts/line.dart';
import 'package:apexo/features/stats/charts_controller.dart';
import 'package:apexo/services/network.dart';
import 'package:apexo/services/permissions.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show showDatePicker;
import 'package:flutter/material.dart' as material;
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedDate = DateTime.now();
  bool showSuccessBanner = false;

  void changeDate(DateTime newDate) {
    setState(() {
      selectedDate = newDate;
    });
  }

  String get currentName {
    if (login.currentMember == null) return "";
    if (login.currentMember!.title.length > 20)
      return "${login.currentMember!.title.substring(0, 17)}...";
    return login.currentMember?.title ?? "";
  }

  String get mode {
    return login.isAdmin
        ? txt("modeAdmin")
        : network.isOnline()
            ? txt("modeUser")
            : txt("modeOffline");
  }

  String get dashboardMessage {
    final onceStable =
        network.isOnline() ? "" : " ${txt("onceConnectionIsStable")}.";

    final restriction = (login.isAdmin && network.isOnline())
        ? txt("unRestrictedAccess")
        : txt("restrictedAccess");

    return "${txt("youAreCurrentlyIn")} $mode ${txt("mode")}. ${txt("youHave")} $restriction.$onceStable";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        key: WK.dashboardScreen,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(FluentIcons.medical),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Txt(
                          "${txt("hello")} $currentName",
                          style: const TextStyle(fontSize: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.18)),
                          ),
                          child: Txt(
                            DateFormat("MMMM d yyyy, hh:mm:a", locale.s.$code)
                                .format(DateTime.now()),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: material.Colors.blue,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Center(
                      child: DateSelectorRow(
                        selectedDate: selectedDate,
                        onChange: changeDate,
                      ),
                    ),
                  ],
                ),
                if (!launch.isDemo)
                  Tooltip(
                    message: dashboardMessage,
                    child: PaymentPill(
                      finalTextColor: login.isAdmin
                          ? Colors.blue
                          : Colors.warningPrimaryColor,
                      title: txt("mode"),
                      amount: mode,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),
          if (permissions.list[5] || login.isAdmin) ...[
            buildTopSquares(),
            DoctorAppointmentsSummaryWithDate(selectedDate: selectedDate),
            // buildDashboardCharts()
          ] else if (permissions.list[2] &&
              dashboardCtrl.todayAppointments.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 5, 15, 0),
              child: Txt(txt("patientsToday")),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 15),
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: dashboardCtrl.todayAppointments
                    .map((e) => ItemTitle(item: e))
                    .toList(),
              ),
            )
          ]
        ],
      ),
    );
  }

  Expanded buildDashboardCharts() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        child: StreamBuilder(
            stream: dashboardCtrl.currentOpenTab.stream,
            builder: (context, snapshot) {
              return TabView(
                currentIndex: dashboardCtrl.currentOpenTab(),
                closeButtonVisibility: CloseButtonVisibilityMode.never,
                header: const SizedBox(width: 5),
                footer: IconButton(
                  icon: Row(
                    children: [
                      const Icon(FluentIcons.chart),
                      const SizedBox(width: 5),
                      Txt(txt("fullStats"))
                    ],
                  ),
                  onPressed: () =>
                      routes.navigate(routes.getByIdentifier("statistics")!),
                ),
                onChanged: (i) => dashboardCtrl.currentOpenTab(i),
                tabs: [
                  Tab(
                    text: Txt(txt("appointments")),
                    icon: const Icon(FluentIcons.calendar),
                    closeIcon: null,
                    outlineColor:
                        WidgetStateProperty.all(Colors.grey.withAlpha(25)),
                    body: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(children: [
                          Expanded(
                              child: StyledBarChart(
                            labels:
                                chartsCtrl.periods.map((p) => p.label).toList(),
                            yAxis: chartsCtrl.groupedAppointments
                                .map((g) => g.length.toDouble())
                                .toList(),
                          ))
                        ]),
                      ),
                    ),
                  ),
                  Tab(
                    text: Txt(txt("payments")),
                    icon: const Icon(FluentIcons.money),
                    closeIcon: null,
                    outlineColor:
                        WidgetStateProperty.all(Colors.grey.withAlpha(25)),
                    body: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 30),
                        child: Column(children: [
                          Expanded(
                              child: StyledLineChart(
                            labels:
                                chartsCtrl.periods.map((p) => p.label).toList(),
                            datasets: [chartsCtrl.groupedPayments.toList()],
                            datasetLabels: [
                              "Payments in ${globalSettings.get("currency_______").value}"
                            ],
                          ))
                        ]),
                      ),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }

  SingleChildScrollView buildTopSquares() {
    final dayAppointments = appointments.forDate(selectedDate);
    final appointmentRows = dayAppointments.toPatientDetailRows();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            dashboardSquare(
              Colors.purple,
              FluentIcons.goto_today,
              dashboardCtrl.appointmentsForDate(selectedDate).length.toString(),
              txt("appointmentsToday"),
            ),
            dashboardSquare(
              Colors.blue,
              FluentIcons.people,
              dashboardCtrl.newPatientsForDate(selectedDate).toString(),
              txt("newPatientsToday"),
            ),
            dashboardSquare(
              Colors.teal,
              FluentIcons.money,
              dashboardCtrl.paymentsForDate(selectedDate).toStringAsFixed(2),
              txt("paymentsMadeToday"),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Align(
                    alignment: Alignment.center,
                    child: Container(
                      color: Colors.white,
                      child: PatientDetailsDialog(
                          rows: dayAppointments.toPatientDetailRows(),
                          patientName: "Patient",
                          hiddenColumns: ['Prescription']),
                    ),
                  ),
                );
              },
            ),
            dashboardSquare(
              Colors.green,
              FluentIcons.medical, // Or another suitable icon
              dashboardCtrl
                  .prescriptionPaymentsForDate(selectedDate)
                  .toStringAsFixed(2),
              "Prescriptions Payments",
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Align(
                    alignment: Alignment.center,
                    child: Container(
                      color: Colors.white,
                      child: PatientDetailsDialog(
                          rows: dayAppointments.toPatientDetailRows(
                              usePrescription:
                                  true), // You can filter for prescription rows if needed
                          patientName: "Patient",
                          hiddenColumns: ['Treatment']),
                    ),
                  ),
                );
              },
            ),
            dashboardSquare(
              Colors.orange,
              FluentIcons.calendar,
              dashboardCtrl
                  .appointmentsForDate(
                      selectedDate.add(const Duration(days: 1)))
                  .length
                  .toString(),
              txt("nextDayAppointments"),
            ),
          ],
        ),
      ),
    );
  }

  Padding dashboardSquare(
      AccentColor color, IconData icon, String title, String subtitle,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Acrylic(
          elevation: 50,
          luminosityAlpha: 1,
          blurAmount: 80,
          tintAlpha: 0.9,
          tint: color,
          shadowColor: color,
          child: SizedBox(
            width: 220,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: color,
                      ),
                      ...const [
                        SizedBox(width: 10),
                        Divider(size: 40, direction: Axis.vertical),
                        SizedBox(width: 10),
                      ],
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Txt(
                            title,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: color.dark),
                          ),
                          Txt(
                            subtitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: color.light,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 10),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorAppointmentsSummaryWithDate extends StatefulWidget {
  final DateTime selectedDate;
  const DoctorAppointmentsSummaryWithDate({
    super.key,
    required this.selectedDate,
  });

  @override
  State<DoctorAppointmentsSummaryWithDate> createState() =>
      _DoctorAppointmentsSummaryWithDateState();
}

class _DoctorAppointmentsSummaryWithDateState
    extends State<DoctorAppointmentsSummaryWithDate> {
  Doctor? selectedDoctor;
  int? hoveredDoctorIndex;
  bool showSuccessInfoBar = false;

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    // Map of doctorId to count (for selectedDate's appointments only)
    final Map<String, int> doctorAppointmentCounts = {};

    final dayAppointments = appointments.forDate(selectedDate);

    for (var appointment in dayAppointments) {
      for (var doctorId in appointment.operatorsIDs) {
        doctorAppointmentCounts[doctorId] =
            (doctorAppointmentCounts[doctorId] ?? 0) + 1;
      }
    }

    final doctorList = doctors.present.values
        .where((doctor) =>
            doctorAppointmentCounts[doctor.id] != null &&
            doctorAppointmentCounts[doctor.id]! > 0)
        .toList();
    // Testing
    // final doctorList = List.generate(5, (_) => baseList).expand((x) => x).toList();

    final int unassignedCount = dayAppointments
        .where((appointment) => appointment.operatorsIDs.isEmpty)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CompletedVsPendingAppointmentsBar(
        //   appointments: dayAppointments,
        // ),
        Container(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wrap numbers and phone lookup in a Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompletedVsPendingAppointmentsNumbers(
                        appointments: dayAppointments,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 320, // or your preferred width
                        child: PhonePatientLookup(
                          patientCheckIn: (patient) {
                            if (patient == null) return;
                            final newAppointment = Appointment.fromJson({
                              "patientID": patient.id,
                            });
                            setState(() {
                              appointments.set(newAppointment);
                              showSuccessInfoBar = true;
                            });
                            Future.delayed(const Duration(seconds: 3), () {
                              if (mounted) {
                                setState(() {
                                  showSuccessInfoBar = false;
                                });
                              }
                            });
                          },
                          addAppointment: (patient) => openAppointment(
                            Appointment.fromJson({
                              "patientID": patient.id,
                            }),
                          ),
                          onCreateNew: (phone) {
                            openPatient(
                              Patient.fromJson({
                                "phone": phone,
                                "title": "",
                              }),
                              0,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Left: Doctors summary
                  Expanded(
                    flex: 2,
                    child: Card(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  txt("todaysAppointments"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Tooltip(
                                message: txt("addAppointment"),
                                child: IconButton(
                                  icon:
                                      Icon(FluentIcons.add, color: Colors.blue),
                                  onPressed: () {
                                    openAppointment(Appointment.fromJson({}));
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (dayAppointments.isNotEmpty)
                            MouseRegion(
                              onEnter: (_) => setState(() =>
                                  hoveredDoctorIndex =
                                      -2), // Unique index for "All"
                              onExit: (_) => setState(() =>
                                  hoveredDoctorIndex = null), // Reset on exit
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedDoctor =
                                        null; // Select "All" doctors
                                  });
                                },
                                child: Container(
                                  color: hoveredDoctorIndex == -2
                                      ? Colors.blue
                                          .withOpacity(0.15) // light blue hover
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                            FluentIcons
                                                .user_optional, // Example icon for "All"
                                            color: Colors.white,
                                            size: 16),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Text(
                                          "All",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          dayAppointments.length.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: material.Colors.blue,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          // Separator if needed
                          // const Divider(height: 1, thickness: 1),

                          // --- "Unassigned" row ---
                          // Only show if there are unassigned items, as per your original `if` condition
                          if (unassignedCount > 0)
                            MouseRegion(
                              onEnter: (_) => setState(() =>
                                  hoveredDoctorIndex =
                                      -1), // Original index for "Unassigned"
                              onExit: (_) =>
                                  setState(() => hoveredDoctorIndex = null),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedDoctor = Doctor.fromJson(
                                        {'id': '', 'title': 'Unassigned'});
                                  });
                                },
                                child: Container(
                                  // Apply hover color based on the original index
                                  color: hoveredDoctorIndex == -1
                                      ? Colors.blue
                                          .withOpacity(0.15) // light blue hover
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 12.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.8),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                            FluentIcons
                                                .help, // Example icon for "Unassigned"
                                            color: Colors.white,
                                            size: 16),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Text(
                                          "Unassigned",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          unassignedCount.toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: material.Colors.green,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (doctorList.isEmpty && unassignedCount == 0)
                            SizedBox(
                              height: 150,
                              child: Center(
                                child: Text(
                                  txt("noAppointmentsToday"),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            // Doctor list
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: 300, // or any max height you want
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: doctorList.length,
                                physics: doctorList.length > 3
                                    ? ScrollPhysics() // enable scroll if needed
                                    : NeverScrollableScrollPhysics(),
                                separatorBuilder: (context, idx) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Divider(
                                      direction: Axis.horizontal,
                                      style: DividerThemeData(
                                        thickness: 1.0,
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.grey.withOpacity(0.1)),
                                        horizontalMargin:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                      ),
                                    )),
                                itemBuilder: (context, idx) {
                                  final doctor = doctorList[idx];
                                  final count =
                                      doctorAppointmentCounts[doctor.id] ?? 0;
                                  String initials = '';
                                  final parts = doctor.title.trim().split(' ');
                                  if (parts.length == 1) {
                                    initials = parts[0].isNotEmpty
                                        ? parts[0][0].toUpperCase()
                                        : '';
                                  } else if (parts.length > 1) {
                                    initials = (parts[0].isNotEmpty
                                            ? parts[0][0]
                                            : '') +
                                        (parts[1].isNotEmpty
                                            ? parts[1][0]
                                            : '');
                                    initials = initials.toUpperCase();
                                  }
                                  final color = Colors.accentColors[
                                      doctor.id.hashCode %
                                          Colors.accentColors.length];

                                  return MouseRegion(
                                    onEnter: (_) => setState(
                                        () => hoveredDoctorIndex = idx),
                                    onExit: (_) => setState(
                                        () => hoveredDoctorIndex = null),
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedDoctor = doctor;
                                        });
                                      },
                                      child: Container(
                                        color: hoveredDoctorIndex == idx
                                            ? Colors.blue.withOpacity(
                                                0.15) // light blue hover
                                            : Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8.0,
                                          horizontal:
                                              12.0, // horizontal padding added
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.8),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color:
                                                        color.withOpacity(0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                doctor.title,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: color.withValues(
                                                    alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                count.toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: color,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Builder(
                      builder: (context) {
                        final doctorAppointments = selectedDoctor == null
                            // All: show all appointments
                            ? dayAppointments
                            // Unassigned: doctor with id == ''
                            : selectedDoctor!.id.isEmpty
                                ? dayAppointments
                                    .where((a) => a.operatorsIDs.isEmpty)
                                    .toList()
                                // Specific doctor
                                : dayAppointments
                                    .where((a) => a.operatorsIDs
                                        .contains(selectedDoctor!.id))
                                    .toList();

                        if (doctorAppointments.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return DoctorPatientsList(
                          doctor: selectedDoctor,
                          selectedDate: selectedDate,
                          appointmentsForDay: dayAppointments,
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Show success info bar after booking
        if (showSuccessInfoBar)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24), // Adjust as needed
              child: InfoBar(
                title: const Text('Appointment booked successfully!'),
                severity: InfoBarSeverity.success,
              ),
            ),
          ),
      ],
    );
  }
}

// Use this DateSelectorRow widget (already in your codebase)
class DateSelectorRow extends StatefulWidget {
  final DateTime selectedDate;
  final void Function(DateTime newDate) onChange;

  const DateSelectorRow({
    super.key,
    required this.selectedDate,
    required this.onChange,
  });

  @override
  State<DateSelectorRow> createState() => _DateSelectorRowState();
}

class _DateSelectorRowState extends State<DateSelectorRow> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    final onChange = widget.onChange;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.chevron_left),
              onPressed: () =>
                  onChange(selectedDate.subtract(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null && picked != selectedDate) {
                  onChange(picked);
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: _isHovering
                        ? Colors.blue.withOpacity(0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d MMM yyyy').format(selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: material.Colors.blue,
                          decoration:
                              _isHovering ? TextDecoration.underline : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE').format(selectedDate) +
                            (DateUtils.isSameDay(selectedDate, DateTime.now())
                                ? " (${txt('today')})"
                                : ""),
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.chevron_right),
              onPressed: () =>
                  onChange(selectedDate.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 20),
            if (!DateUtils.isSameDay(selectedDate, DateTime.now()))
              Tooltip(
                message: txt("goToToday"),
                child: FilledButton(
                  child: Row(
                    children: [
                      Icon(FluentIcons.refresh),
                    ],
                  ),
                  onPressed: () => onChange(DateTime.now()),
                  style: ButtonStyle(
                    padding: ButtonState.all(
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    backgroundColor: ButtonState.all(Colors.blue),
                    foregroundColor: ButtonState.all(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
