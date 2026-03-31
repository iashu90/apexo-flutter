import 'package:apexo/common_widgets/text_util.dart';
import 'package:apexo/core/activity_logger.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:flutter/material.dart' as material;
import 'package:intl/intl.dart';

class PatientLookup extends StatefulWidget {
  final void Function(Patient?) patientCheckIn;
  final void Function(String phone)? onCreateNew;
  final void Function(Patient patient)? addAppointment;

  const PatientLookup({
    super.key,
    required this.patientCheckIn,
    this.onCreateNew,
    this.addAppointment,
  });

  @override
  State<PatientLookup> createState() => _PatientLookupState();
}

class _PatientLookupState extends State<PatientLookup> {
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
      if (_lastInput.isEmpty) {
        _matchedPatients = [];
        return;
      }
      _matchedPatients = patients.present.values
          .where((p) =>
              p.phone.trim().contains(_lastInput) ||
              toTitleCase(p.title)
                  .toLowerCase()
                  .contains(_lastInput.toLowerCase()))
          .cast<Patient>()
          .toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: _showBanner ? const Offset(0, 0) : const Offset(0, -1),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _showBanner ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 240),
            child: _showBanner
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E9B5D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(FluentIcons.accept, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Patient checked in successfully',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        const Text(
          'Quick Check-in',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF183A67),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Search by patient name or phone, then check-in or add appointment.',
          style: TextStyle(color: Color(0xFF607B9F), fontSize: 12),
        ),
        const SizedBox(height: 10),
        TextBox(
          placeholder: 'Enter phone number or name',
          controller: _controller,
          onChanged: _onChanged,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 13),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search, size: 12, color: Color(0xFF6D84A8)),
          ),
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
        const SizedBox(height: 8),
        if (_lastInput.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD9E6F4)),
            ),
            child: const Text(
              'Start typing to find existing patients quickly.',
              style: TextStyle(color: Color(0xFF5F7C9F), fontSize: 12),
            ),
          )
        else if (_matchedPatients.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD7E5F4)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount:
                  _matchedPatients.length > 8 ? 8 : _matchedPatients.length,
              separatorBuilder: (_, __) => const Divider(
                direction: Axis.horizontal,
                style: DividerThemeData(thickness: 1),
              ),
              itemBuilder: (_, idx) {
                final patient = _matchedPatients[idx];
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F0FF),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          FluentIcons.contact,
                          color: Color(0xFF1A74DB),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: highlightMatch(
                                toTitleCase(patient.title),
                                _lastInput,
                                const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF2E4E76),
                                ),
                                const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF1A74DB),
                                ),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (patient.phone.isNotEmpty)
                              RichText(
                                text: highlightMatch(
                                  patient.phone,
                                  _lastInput,
                                  const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                    color: Color(0xFF5F7C9F),
                                  ),
                                  const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFF1A74DB),
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              'Age: ${patient.age}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 11,
                                color: Color(0xFF5F7C9F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Button(
                        onPressed: widget.addAppointment == null
                            ? null
                            : () {
                                ActivityLogger.logAction(
                                  'Add Appointment Clicked',
                                  screen: 'PatientLookup',
                                  data: {
                                    'patientId': patient.id,
                                    'patientName': patient.title,
                                    'patientPhone': patient.phone,
                                  },
                                );
                                widget.addAppointment!(patient);
                              },
                        child: const Text('Add'),
                      ),
                      const SizedBox(width: 6),
                      FilledButton(
                        onPressed: () {
                          ActivityLogger.logAction(
                            'Patient Check-In Clicked',
                            screen: 'PatientLookup',
                            data: {
                              'patientId': patient.id,
                              'patientName': patient.title,
                              'patientPhone': patient.phone,
                            },
                          );
                          widget.patientCheckIn(patient);
                          _showSuccessBanner();
                        },
                        child: const Text('Check-in'),
                      ),
                    ],
                  ),
                );
              },
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF2D5A9)),
            ),
            child: Row(
              children: [
                const Icon(FluentIcons.warning,
                    size: 14, color: Color(0xFFB87400)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'No patient found.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF845400),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: widget.onCreateNew == null
                      ? null
                      : () {
                          ActivityLogger.logAction(
                            'Add New Patient Clicked',
                            screen: 'PatientLookup',
                            data: {'input': _lastInput},
                          );
                          widget.onCreateNew!(_lastInput);
                        },
                  child: const Text('Create'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
