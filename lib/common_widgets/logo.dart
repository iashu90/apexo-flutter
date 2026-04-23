import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Use this widget to display the logo and name of your app
class AppLogo extends StatefulWidget {
  const AppLogo({super.key});

  @override
  State<AppLogo> createState() => _AppLogoState();
}

String savedVersion = "";
String savedBuildDate = "";

class _AppLogoState extends State<AppLogo> {
  String version = savedVersion;
  String buildDate = savedBuildDate;

  @override
  void initState() {
    if (version.isEmpty) {
      PackageInfo.fromPlatform()
          .then((p) => setState(() {
                version = p.version;
                savedVersion = p.version;
              }))
          .ignore();
    }

    if (buildDate.isEmpty) {
      final parsedBuildDate = DateTime.tryParse(
        const String.fromEnvironment('BUILD_DATE', defaultValue: ''),
      );
      final resolvedBuildDate = parsedBuildDate ?? DateTime.now();
      buildDate = DateFormat('d MMMM yyyy').format(resolvedBuildDate);
      savedBuildDate = buildDate;
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
        color: (FluentTheme.of(context).iconTheme.color ?? Colors.grey)
            .withValues(alpha: 0.4),
        fontSize: 12);
    return Center(
      key: WK.appLogo,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Image.asset(
              "assets/app_icon.png",
              height: 50,
            ),
            const SizedBox(width: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Dr.Nowfar Dental Clinic", style: textStyle),
                const SizedBox(height: 2),
                Text(version, style: textStyle),
                const SizedBox(height: 2),
                Text(
                  buildDate,
                  style: textStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
