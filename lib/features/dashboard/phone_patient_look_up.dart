import 'package:fluent_ui/fluent_ui.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class PhonePatientLookup extends StatefulWidget {
  final void Function(Patient?) patientCheckIn;
  final void Function(String phone)? onCreateNew;
  final void Function(Patient patient)? addAppointment;

  const PhonePatientLookup({
    super.key,
    required this.patientCheckIn,
    this.onCreateNew,
    this.addAppointment,
  });

  @override
  State<PhonePatientLookup> createState() => _PhonePatientLookupState();
}

class _PhonePatientLookupState extends State<PhonePatientLookup>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Patient> _matchedPatients = [];
  String _lastInput = '';

  bool _showBanner = false;

  void _showSuccessBanner() {
    setState(() => _showBanner = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  void _onChanged(String value) {
    setState(() {
      _lastInput = value.trim();
      _matchedPatients = patients.present.values
          .where((p) => p.phone.trim().contains(_lastInput))
          .cast<Patient>()
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSlide(
                  offset: _showBanner ? Offset(0, 0) : Offset(0, -1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _showBanner ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: _showBanner
                        ? Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.7),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(FluentIcons.accept,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Appointment added!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8.0), // Padding below title
                  child: Text(
                    "Check in",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 8.0), // Padding below TextBox
                  child: TextBox(
                    placeholder: "Enter phone number",
                    controller: _controller,
                    onChanged: _onChanged,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 13),
                    suffix: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(FluentIcons.clear),
                            onPressed: () {
                              setState(() {
                                _controller.clear();
                                _lastInput = '';
                                _matchedPatients = [];
                              });
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                if (_lastInput.isNotEmpty)
                  _matchedPatients.isNotEmpty
                      ? SizedBox(
                          height: 250,
                          child: ListView.separated(
                            itemCount: _matchedPatients.length > 6
                                ? 6
                                : _matchedPatients.length,
                            separatorBuilder: (context, idx) => Divider(
                              direction: Axis.horizontal,
                              style: DividerThemeData(
                                thickness: 1.0,
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1)),
                              ),
                            ),
                            itemBuilder: (context, idx) {
                              final patient = _matchedPatients[idx];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                child: Row(
                                  children: [
                                    const Icon(FluentIcons.contact,
                                        color: material.Colors.green, size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        toTitleCase(patient.title),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        FluentIcons.profile_search,
                                        color: material.Colors.blue,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        if (widget.addAppointment != null) {
                                          widget.addAppointment!(patient);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(
                                        FluentIcons.accept,
                                        color: material.Colors.green,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        widget.patientCheckIn(patient);
                                        _showSuccessBanner();
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      : Card(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          backgroundColor: Colors.orange.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(7),
                          child: Row(
                            children: [
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "No patient found.",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                  icon: const Icon(FluentIcons.add_friend,
                                      color: material.Colors.orange, size: 18),
                                  onPressed: widget.onCreateNew != null
                                      ? () => widget.onCreateNew!(_lastInput)
                                      : null),
                            ],
                          ),
                        ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
