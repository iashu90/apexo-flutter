import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/core/ui/components/app_button.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../services/login.dart';

class CurrentUser extends StatelessWidget {
  const CurrentUser({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(FluentIcons.contact),
        const SizedBox(width: 5),
        StreamBuilder(stream: login.stream, builder: (context, _) => Txt(login.email)),
        const SizedBox(width: 5),
        AppButton(
          key: WK.btnLogout,
          label: txt("logout"),
          variant: AppButtonVariant.danger,
          onPressed: login.logout,
          leading: const Icon(FluentIcons.sign_out, size: 14),
        ),
      ],
    );
  }
}
