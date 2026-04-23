import 'package:apexo/services/permissions.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  int _roleTabIndex = 0;

  static const List<String> _featureLabels = [
    'Dashboard',
    'Doctors',
    'Patients',
    'Appointments / Checkin',
    'Labwork',
    'Expenses',
    'Reports',
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
        final selectedValues = _roleTabIndex == 0
            ? permissions.editingList
            : permissions.editingDoctorList;

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
              Row(
                children: [
                  _roleTab(
                    label: 'Receptionist',
                    selected: _roleTabIndex == 0,
                    onTap: () => setState(() => _roleTabIndex = 0),
                  ),
                  const SizedBox(width: 6),
                  _roleTab(
                    label: 'Doctor',
                    selected: _roleTabIndex == 1,
                    onTap: () => setState(() => _roleTabIndex = 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _roleCard(
                title: _roleTabIndex == 0
                    ? 'Receptionist Access'
                    : 'Doctor Access',
                values: selectedValues,
                onToggle: (index, value) {
                  setState(() {
                    if (_roleTabIndex == 0) {
                      permissions.editingList[index] = value;
                    } else {
                      permissions.editingDoctorList[index] = value;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AppButton(
                    label: 'Save Changes',
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
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Reset',
                    variant: AppButtonVariant.secondary,
                    onPressed: permissions.edited
                        ? () {
                            setState(() {
                              permissions.reset();
                            });
                          }
                        : null,
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

  Widget _roleTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFEFF4FB),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF2D7BD8)
                : const Color(0xFFD6E2F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF355279),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
