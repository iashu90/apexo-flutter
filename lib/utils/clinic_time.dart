import 'package:intl/intl.dart';

const String clinicTimeZoneId = 'Asia/Kolkata';
const Duration _clinicOffset = Duration(hours: 5, minutes: 30);

DateTime toClinicTime(DateTime value) {
  return value.toUtc().add(_clinicOffset);
}

DateTime clinicNow() {
  return toClinicTime(DateTime.now());
}

DateTime utcFromClinicWallClock(DateTime clinicWallClock) {
  final assumedClinicUtc = DateTime.utc(
    clinicWallClock.year,
    clinicWallClock.month,
    clinicWallClock.day,
    clinicWallClock.hour,
    clinicWallClock.minute,
    clinicWallClock.second,
    clinicWallClock.millisecond,
    clinicWallClock.microsecond,
  );
  return assumedClinicUtc.subtract(_clinicOffset);
}

String formatClinicDate(DateTime value, {String pattern = 'dd MMM yyyy'}) {
  return DateFormat(pattern).format(toClinicTime(value));
}

String formatClinicDateTime(DateTime value,
    {String pattern = 'dd MMM yyyy, hh:mm a'}) {
  return DateFormat(pattern).format(toClinicTime(value));
}
