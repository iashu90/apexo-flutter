import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/permissions.dart';
import 'package:fluent_ui/fluent_ui.dart';

class PermissionsSettings extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final List<String> permissionsTitles = const [
    "doctors",
    "patients",
    "appointments",
    "labworks",
    "expenses",
    "statistics"
  ];

  PermissionsSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      const Text(
                        'Receptionist access',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      ...List.generate(
                        permissions.editingList.length,
                        (index) => ToggleSwitch(
                          checked: permissions.editingList[index],
                          onChanged: (val) {
                            permissions.editingList[index] = val;
                            permissions.notifyAndPersist();
                          },
                          content: Txt(
                            "${txt("usersCanAccess")} ${txt(permissionsTitles[index])}",
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Doctor access',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      ...List.generate(
                        permissions.editingDoctorList.length,
                        (index) => ToggleSwitch(
                          checked: permissions.editingDoctorList[index],
                          onChanged: (val) {
                            permissions.editingDoctorList[index] = val;
                            permissions.notifyAndPersist();
                          },
                          content: Txt(
                            "${txt("usersCanAccess")} ${txt(permissionsTitles[index])}",
                          ),
                        ),
                      ),
                      if (permissions.edited) ...[
                        const SizedBox(),
                        Row(
                          children: [
                            FilledButton(
                              child: Row(
                                children: [const Icon(FluentIcons.save), const SizedBox(width: 5), Txt(txt("save"))],
                              ),
                              onPressed: () {
                                permissions.save();
                              },
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              child: Row(
                                children: [const Icon(FluentIcons.reset), const SizedBox(width: 5), Txt(txt("reset"))],
                              ),
                              onPressed: () {
                                permissions.reset();
                              },
                            ),
                          ],
                        )
                      ]
                    ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList());
              }),
        ),
      ),
    );
  }
}
