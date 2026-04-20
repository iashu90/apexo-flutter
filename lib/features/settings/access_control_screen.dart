import 'package:apexo/services/permissions.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  static const List<String> _featureLabels = [
    'Doctors',
    'Patients',
    'Appointments / Checkin',
    'Labwork',
    'Expenses',
    'Statistics / Report',
  ];

  @override
  Widget build(BuildContext context) {
    if (permissions.currentRole != UserRole.admin) {
      return const ScaffoldPage(
        content: Center(
          child: Text('Access denied. Only admin/super admin can manage access control.'),
        ),
      );
    }

    return ScaffoldPage(
      header: const PageHeader(title: Text('Setting')),
      content: _buildAccessControlBody(),
    );
  }

  Widget _buildAccessControlBody() {
    return StreamBuilder(
      stream: permissions.stream,
      builder: (context, _) {
        final receptionist = permissions.editingList;
        final doctor = permissions.editingDoctorList;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enable or disable modules per role',
                style: TextStyle(
                  color: Color(0xFF4D6488),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _roleCard(
                title: 'Receptionist Access',
                values: receptionist,
                onToggle: (index, value) {
                  setState(() {
                    permissions.editingList[index] = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              _roleCard(
                title: 'Doctor Access',
                values: doctor,
                onToggle: (index, value) {
                  setState(() {
                    permissions.editingDoctorList[index] = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  FilledButton(
                    onPressed: permissions.edited
                        ? () async {
                            await permissions.save();
                            if (!mounted) return;
                            displayInfoBar(
                              context,
                              builder: (context, close) => const InfoBar(
                                title: Text('Saved'),
                                content: Text('Access control updated.'),
                                severity: InfoBarSeverity.success,
                              ),
                            );
                          }
                        : null,
                    child: const Text('Save Changes'),
                  ),
                  const SizedBox(width: 8),
                  Button(
                    onPressed: permissions.edited
                        ? () {
                            setState(() {
                              permissions.reset();
                            });
                          }
                        : null,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roleCard({
    required String title,
    required List<bool> values,
    required void Function(int index, bool value) onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E2F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF183A67),
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(_featureLabels.length, (index) {
            final enabled = index < values.length ? values[index] : false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _featureLabels[index],
                      style: const TextStyle(
                        color: Color(0xFF355279),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ToggleSwitch(
                    checked: enabled,
                    onChanged: (value) => onToggle(index, value),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
