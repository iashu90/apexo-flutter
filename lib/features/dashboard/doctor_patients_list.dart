import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class DoctorPatientsList extends StatefulWidget {
  final Doctor? doctor;
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
    final doctorAppointments = widget.doctor != null
        ? widget.appointmentsForDay
            .where((a) => a.operatorsIDs.contains(widget.doctor!.id))
            .toList()
        : widget.appointmentsForDay
            .where((a) => a.operatorsIDs.isEmpty)
            .toList();

    // Filter appointments based on selection
    final filteredAppointments = showCompleted == null
        ? doctorAppointments
        : doctorAppointments.where((a) => a.isDone == showCompleted).toList();

    filteredAppointments.sort((a, b) => a.date.compareTo(b.date));

    return Card(
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and completed/pending counts
            Row(
              children: [
                Expanded(
                  child: Text(
                    (widget.doctor != null
                            ? "${widget.doctor!.title}'s "
                            : "Unassigned ") +
                        txt("patients"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                Tooltip(
                  message: txt("addAppointment"),
                  child: IconButton(
                    icon: Icon(FluentIcons.add, color: Colors.blue),
                    onPressed: () {
                      if (widget.doctor != null) {
                        openAppointment(Appointment.fromJson({
                          "operatorsIDs": [widget.doctor!.id],
                        }));
                      } else {
                        openAppointment(Appointment.fromJson({
                          "operatorsIDs": [],
                        }));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Patient list
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 150,
                maxHeight: 400, // set your desired max height
              ),
              child: _PatientListWithHover(
                doctorAppointments: filteredAppointments,
              ),
            )
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
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Divider(
            direction: Axis.horizontal,
            style: DividerThemeData(
              thickness: 1.0,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
            ),
          )),
      itemBuilder: (context, index) {
        final a = widget.doctorAppointments[index];
        final patient = patients.present[a.patientID];
        final patientName = patient?.title ?? 'Unknown';
        final apptTime = DateFormat('hh:mm a').format(a.date);

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (a.preOpNotes != null && a.preOpNotes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1.0),
                            child: Text(
                              a.preOpNotes,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 70, // Set a fixed width for time to align all times
                    child: Text(
                      apptTime,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 116, 114, 111),
                        fontSize: 14,
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
