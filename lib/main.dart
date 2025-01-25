import 'package:apexo/app/app.dart';
import 'package:apexo/sentry_dsn.dart';
import 'package:apexo/utils/init_stores.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('>>> ${record.level.name}: ${record.time}: ${record.message}');
  });

  initializeStores();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  if (kDebugMode) {
    runApp(const ApexoApp());
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDSN;
        // options.tracesSampleRate = 1.0;
        // options.profilesSampleRate = 1.0;
      },
      appRunner: () => runApp(const ApexoApp()),
    );
  }
}
