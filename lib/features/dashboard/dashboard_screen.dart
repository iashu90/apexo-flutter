import 'package:apexo/app/routes.dart';
import 'package:apexo/common_widgets/appointment_card.dart';
import 'package:apexo/features/dashboard/dashboard_controller.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
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
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime selectedDate = DateTime.now();

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
                        Txt(
                          DateFormat("MMMM d yyyy, hh:mm:a", locale.s.$code)
                              .format(DateTime.now()),
                          style: const TextStyle(fontSize: 14),
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
                    outlineColor: Colors.grey.withValues(alpha: 0.1),
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
                    outlineColor: Colors.grey.withValues(alpha: 0.1),
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
      AccentColor color, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
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

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;
    // Map of doctorId to count (for selectedDate's appointments only)
    final Map<String, int> doctorAppointmentCounts = {};

    final dayAppointments = appointments.present.values.where((appointment) {
      return appointment.date.year == selectedDate.year &&
          appointment.date.month == selectedDate.month &&
          appointment.date.day == selectedDate.day;
    }).toList();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: SizedBox(
              height: 250,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Doctors summary
                  Expanded(
                    flex: 2,
                    child: Card(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (doctorList.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text(
                                  txt("noAppointmentsToday"),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            )
                          else
                            // Make the doctor list scrollable with fixed height
                            SizedBox(
                              height:
                                  150, // <-- Set your desired fixed height here
                              child: ListView.separated(
                                itemCount: doctorList.length,
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
                                              width: 36,
                                              height: 36,
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
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
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
                                                        FontWeight.w500),
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
                                                  fontWeight: FontWeight.bold,
                                                  color: color,
                                                  fontSize: 15,
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
                    child: selectedDoctor != null
                        ? DoctorPatientsList(
                            doctor: selectedDoctor!,
                            selectedDate: selectedDate,
                            appointmentsForDay: dayAppointments,
                          )
                        : Container(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Show the completed vs pending bar for the selected date
        CompletedVsPendingAppointmentsBar(
          appointments: dayAppointments,
        ),
      ],
    );
  }
}

// Use this DateSelectorRow widget (already in your codebase)
class DateSelectorRow extends StatelessWidget {
  final DateTime selectedDate;
  final void Function(DateTime newDate) onChange;

  const DateSelectorRow({
    super.key,
    required this.selectedDate,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
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
                if (picked != null) {
                  onChange(picked);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d MMM yyyy').format(selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: material.Colors.blue,
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
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.chevron_right),
              onPressed: () =>
                  onChange(selectedDate.add(const Duration(days: 1))),
            ),
            const SizedBox(width: 8),
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

class DoctorPatientsList extends StatefulWidget {
  final Doctor doctor;
  final DateTime selectedDate;
  final List appointmentsForDay;

  const DoctorPatientsList({
    super.key,
    required this.doctor,
    required this.selectedDate,
    required this.appointmentsForDay,
  });

  @override
  State<DoctorPatientsList> createState() => _DoctorPatientsListState();
}

class _DoctorPatientsListState extends State<DoctorPatientsList> {
  // null = show all, true = show completed, false = show pending
  bool? showCompleted;

  @override
  Widget build(BuildContext context) {
    final doctorAppointments = widget.appointmentsForDay
        .where((a) => a.operatorsIDs.contains(widget.doctor.id))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate completed and pending counts for this doctor on this day
    int completedCount = 0;
    int pendingCount = 0;
    for (final appt in doctorAppointments) {
      if (appt.isDone == true) {
        completedCount++;
      } else {
        pendingCount++;
      }
    }

    // Filter appointments based on selection
    final filteredAppointments = showCompleted == null
        ? doctorAppointments
        : doctorAppointments.where((a) => a.isDone == showCompleted).toList();

    if (doctorAppointments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          txt("noPatientsForDoctor"),
          style: TextStyle(
            color: material.Colors.grey[600],
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
      );
    }

    return Card(
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and completed/pending counts
            Row(
              children: [
                Expanded(
                  child: Txt(
                    "${widget.doctor.title}'s ${txt("patients")}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showCompleted = true;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: showCompleted == true
                          ? Colors.green.withOpacity(0.25)
                          : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: showCompleted == true
                          ? Border.all(color: Colors.green, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(FluentIcons.check_mark,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          completedCount.toString(),
                          style: const TextStyle(
                              color: Colors.successPrimaryColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showCompleted = false;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: showCompleted == false
                          ? Colors.orange.withOpacity(0.25)
                          : Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: showCompleted == false
                          ? Border.all(color: Colors.orange, width: 1.5)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(FluentIcons.clock, color: Colors.orange, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          pendingCount.toString(),
                          style: const TextStyle(
                              color: Colors.warningPrimaryColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Reset filter button if filtered
                if (showCompleted != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: () {
                      setState(() {
                        showCompleted = null;
                      });
                    },
                  ),
                ]
              ],
            ),
            const SizedBox(height: 12),
            // Patient list
            SizedBox(
              height: 150,
              child: _PatientListWithHover(
                  doctorAppointments: filteredAppointments),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientListWithHover extends StatefulWidget {
  final List doctorAppointments;
  const _PatientListWithHover({required this.doctorAppointments});

  @override
  State<_PatientListWithHover> createState() => _PatientListWithHoverState();
}

class _PatientListWithHoverState extends State<_PatientListWithHover> {
  int? hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.doctorAppointments.length,
      separatorBuilder: (context, idx) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Divider(
            direction: Axis.horizontal,
            style: DividerThemeData(
              thickness: 1.0,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
              horizontalMargin: const EdgeInsets.symmetric(horizontal: 8.0),
            ),
          )),
      itemBuilder: (context, index) {
        final a = widget.doctorAppointments[index];
        final patient = patients.present[a.patientID];
        final patientName = patient?.title ?? 'Unknown';
        final apptTime = DateFormat('hh:mm a').format(a.date);

        // Count completed and pending appointments for this doctor on this day
        final doctorId =
            a.operatorsIDs.isNotEmpty ? a.operatorsIDs.first : null;
        int completedCount = 0;
        int pendingCount = 0;
        if (doctorId != null) {
          for (final appt in widget.doctorAppointments) {
            if (appt.operatorsIDs.contains(doctorId)) {
              if (appt.isDone == true) {
                completedCount++;
              } else {
                pendingCount++;
              }
            }
          }
        }

        return MouseRegion(
          onEnter: (_) => setState(() => hoveredIndex = index),
          onExit: (_) => setState(() => hoveredIndex = null),
          child: GestureDetector(
            onTap: () {
              if (patient != null) {
                openPatient(patient, 2);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: hoveredIndex == index
                  ? Colors.blue.withOpacity(0.15)
                  : Colors.transparent,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxTheme(
                    data: CheckboxThemeData(
                      checkedDecoration: WidgetStateProperty.all(
                        BoxDecoration(
                          color: a.isDone == true
                              ? Colors.green
                              : Colors.transparent,
                          border: Border.all(
                            color:
                                a.isDone == true ? Colors.green : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    child: Checkbox(
                      checked: a.isDone == true,
                      onChanged: null, // disables interaction
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 70, // Set a fixed width for time to align all times
                    child: Text(
                      apptTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CompletedVsPendingAppointmentsBar extends StatelessWidget {
  final List appointments;

  const CompletedVsPendingAppointmentsBar({
    super.key,
    required this.appointments,
  });

  @override
  Widget build(BuildContext context) {
    final total = appointments.length;
    final completed = appointments.where((a) => a.isDone == true).length;
    final pending = total - completed;
    final completedPercent = total == 0 ? 0.0 : completed / total;
    final pendingPercent = total == 0 ? 0.0 : pending / total;

    // Hide the bar if there are no appointments
    if (total == 0) return const SizedBox.shrink();

    // Define your custom colors
    final completedColor = Colors.teal;
    final pendingColor = Colors.red;

    return Container(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Card(
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Txt(
                  txt("completedVsPendingAppointments"),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (completed == total)
                      // Only completed bar (full width)
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: completedColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${txt("completed")}: $completed",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else if (pending == total)
                      // Only pending bar (full width)
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: pendingColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "${txt("pending")}: $pending",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Both bars
                      Expanded(
                        flex: (completedPercent * 100).round(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: completedColor,
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(12)),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              "${txt("completed")}: $completed",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: (pendingPercent * 100).round(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: pendingColor,
                            borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(12)),
                          ),
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              "${txt("pending")}: $pending",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${(completedPercent * 100).toStringAsFixed(1)}% ${txt("completed")}, "
                  "${(pendingPercent * 100).toStringAsFixed(1)}% ${txt("pending")}",
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
