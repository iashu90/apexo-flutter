import 'package:apexo/core/theme/app_theme.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/services/permissions.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PermissionsSettings extends StatefulWidget {
  const PermissionsSettings({super.key});

  @override
  State<PermissionsSettings> createState() => _PermissionsSettingsState();
}

class _PermissionsSettingsState extends State<PermissionsSettings> {
  int _roleTabIndex = 0;

  static const List<String> _permissionTitles = [
    'Doctors',
    'Patients',
    'Appointments / Checkin',
    'Labworks',
    'Expenses',
    'Reports',
    'Dashboard',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
        color: AppTheme.light.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: Expander(
            leading: const Icon(FluentIcons.permissions),
            header: Txt(txt("permissions")),
            contentPadding: const EdgeInsets.all(10),
            content: SizedBox(
              width: 400,
              child: StreamBuilder(
                  stream: permissions.stream,
                  builder: (context, snapshot) {
                    final selectedValues = _roleTabIndex == 0
                        ? permissions.editingList
                        : permissions.editingDoctorList;

                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoBar(
                            title: Txt(txt("permissions")),
                            severity: InfoBarSeverity.warning,
                            content: Txt(txt("permissionsNotice")),
                          ),
                          InfoLabel(
                            label: 'Current role',
                            child: Text(permissions.currentRoleLabel),
                          ),
                          const SizedBox(height: 6),
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
                          const SizedBox(height: 6),
                          ...List.generate(
                            _permissionTitles.length,
                            (index) => ToggleSwitch(
                              checked: index < selectedValues.length
                                  ? selectedValues[index]
                                  : false,
                              onChanged: (val) {
                                if (_roleTabIndex == 0) {
                                  permissions.editingList[index] = val;
                                } else {
                                  permissions.editingDoctorList[index] = val;
                                }
                                permissions.notifyAndPersist();
                              },
                              content: Txt(
                                "${txt("usersCanAccess")} ${_permissionTitles[index]}",
                              ),
                            ),
                          ),
                          if (permissions.edited) ...[
                            const SizedBox(),
                            Row(
                              children: [
                                AppButton(
                                  leading: const Icon(FluentIcons.save),
                                  label: txt("save"),
                                  onPressed: () {
                                    permissions.save();
                                  },
                                ),
                                const SizedBox(width: 10),
                                AppButton(
                                  variant: AppButtonVariant.secondary,
                                  leading: const Icon(FluentIcons.reset),
                                  label: txt("reset"),
                                  onPressed: () {
                                    permissions.reset();
                                  },
                                ),
                              ],
                            )
                          ]
                        ]
                            .map((e) => [e, const SizedBox(height: 10)])
                            .expand((e) => e)
                            .toList());
                  }),
            ),
          ),
        ));
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
            color: selected ? const Color(0xFF2D7BD8) : const Color(0xFFD6E2F0),
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
