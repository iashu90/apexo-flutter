import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';
import 'package:apexo/features/appointments/open_appointment_panel.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/patients/open_patient_panel.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' as material;

final GlobalKey<_PatientListWithHoverState> _patientListWithHoverKey =
    GlobalKey();

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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final doctorAppointments = widget.doctor == null
        ? widget.appointmentsForDay // Show all for "All"
        : widget.doctor!.id.isEmpty // Unassigned
            ? widget.appointmentsForDay
                .where((a) => a.operatorsIDs.isEmpty)
                .toList()
            : widget.appointmentsForDay
                .where((a) => a.operatorsIDs.contains(widget.doctor!.id))
                .toList();

    // Filter appointments based on selection
    final filteredAppointments = showCompleted == null
        ? doctorAppointments
        : doctorAppointments.where((a) => a.isDone == showCompleted).toList();

    filteredAppointments.sort((a, b) => a.date.compareTo(b.date));

    final patientsStore = patients.present; // or your patients store
    final searchedAppointments = _searchQuery.isEmpty
        ? filteredAppointments
        : filteredAppointments.where((a) {
            final patient = patientsStore[a.patientID];
            final name = patient?.title?.toLowerCase() ?? '';
            final number = patient?.phone?.toLowerCase() ?? '';
            return name.contains(_searchQuery) || number.contains(_searchQuery);
          }).toList();

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
                    (widget.doctor == null
                            ? "All "
                            : widget.doctor!.id.isEmpty
                                ? "Unassigned "
                                : "${widget.doctor!.title}'s ") +
                        txt("patients"),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Delete selected appointments button
                Tooltip(
                  message: txt("deleteSelectedAppointments"),
                  child: IconButton(
                    icon: Icon(FluentIcons.delete, color: Colors.red),
                    onPressed: () async {
                      final state = _patientListWithHoverKey.currentState;
                      if (state != null && state.selectedIndexes.isNotEmpty) {
                        // Prepare details for dialog
                        final details = state.selectedIndexes
                            .map((idx) {
                              final a = state.widget.doctorAppointments[idx];
                              final patient = patients.present[a.patientID];
                              return patient?.title ?? 'Unknown';
                            })
                            .where((name) => name.isNotEmpty)
                            .join('\n');

                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          message:
                              "Are you sure you want to delete the selected appointments?",
                          customDetails: details.isNotEmpty ? details : null,
                        );
                        if (confirmed == true) {
                          final indexes = state.selectedIndexes.toList()
                            ..sort((a, b) => b.compareTo(a));
                          for (final idx in indexes) {
                            final appointment =
                                state.widget.doctorAppointments[idx];
                            await appointments.hardDelete(appointment.id);
                          }
                          setState(() {
                            state.selectedIndexes.clear();
                          });
                        }
                      }
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Existing addAppointment icon button
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
            const SizedBox(height: 8),
            TextBox(
              placeholder: 'Search patient by name or number',
              onChanged: (query) {
                setState(() {
                  _searchQuery = query.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            // Patient list
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 150,
                maxHeight: 400,
              ),
              child: _PatientListWithHover(
                key: _patientListWithHoverKey,
                doctorAppointments: searchedAppointments,
                selectedDate: widget.selectedDate,
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
  final DateTime selectedDate;
  const _PatientListWithHover({
    Key? key,
    required this.doctorAppointments,
    required this.selectedDate,
  }) : super(key: key);

  @override
  State<_PatientListWithHover> createState() => _PatientListWithHoverState();
}

class _PatientListWithHoverState extends State<_PatientListWithHover> {
  int? hoveredIndex;
  final Set<int> selectedIndexes = {};
  DateTime? _lastDate;

  @override
  void initState() {
    super.initState();
    _lastDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(covariant _PatientListWithHover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastDate != widget.selectedDate) {
      selectedIndexes.clear();
      _lastDate = widget.selectedDate;
      setState(() {}); // Force rebuild to update checkboxes
    }
  }

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
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Checkbox for selection
                  Checkbox(
                    checked: selectedIndexes.contains(index),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedIndexes.add(index);
                        } else {
                          selectedIndexes.remove(index);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 10), // <-- Add this line for gap
                  // Status circle close to patient name
                  if (a.isDone != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8, left: 4),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: a.isDone!
                            ? Colors.green
                            : material.Colors.grey[300],
                        border: Border.all(
                          color: a.isDone!
                              ? Colors.green
                              : material.Colors.grey[400]!,
                          width: 2,
                        ),
                      ),
                      child: a.isDone!
                          ? const Icon(FluentIcons.check_mark,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  // Patient name and notes
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
                    width: 70,
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
