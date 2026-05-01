import 'package:apexo/common_widgets/patient_report.dart';
import 'package:apexo/core/model.dart';
import 'package:apexo/features/labwork/labworks_store.dart';
import 'package:apexo/services/archived.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/utils/encode.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/appointments/appointment_model.dart';
import 'package:apexo/features/appointments/appointments_store.dart';

class Patient extends Model {
  List<Appointment>? _allAppointmentsCached;
  List<Appointment> get allAppointments {
    return _allAppointmentsCached ??= (appointments.byPatient[id]?["all"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ReportDetailRow> get patientDetails => [
        ...allAppointments.map((appointment) {
          final dateStr = appointment.date;

          final costStr = '₹${appointment.price.toStringAsFixed(2)}';
          final paidStr = '₹${appointment.paid.toStringAsFixed(2)}';

          final prescriptionStr = (appointment.prescriptions.isNotEmpty)
              ? appointment.prescriptions.join(', ')
              : '';
          final treatmentStr = (appointment.selectedTreatments.isNotEmpty)
              ? appointment.subTreatments.isNotEmpty
                  ? "${appointment.selectedTreatments.join(', ')} - ${appointment.subTreatments.join(', ')}"
                  : appointment.selectedTreatments.join(', ')
              : '';

          final teethStr = (appointment.selectedTeeth.isNotEmpty)
              ? appointment.selectedTeeth.join(', ')
              : '';

          final treatmentPaymentMode =
              appointment.treatmentGpayPaid == true ? 'GPay' : 'Cash';
          final preceptionPaymentMode =
              appointment.prescriptionGpayPaid == true ? 'GPay' : 'Cash';

          final doctorNameStr = appointment.operators.isEmpty
              ? ''
              : appointment.operators.map((d) => d.title.trim()).join(', ');
            final chiefComplaintStr = appointment.chiefComplaints.isEmpty
              ? ''
              : appointment.chiefComplaints.join(', ');

          return ReportDetailRow(
            appointmentId: appointment.id,
            date: dateStr,
            cost: costStr,
            paid: paidStr,
            prescription: prescriptionStr,
            treatment: treatmentStr,
            teeth: teethStr,
            isDone: appointment.isDone,
            treatmentPaymentMode: treatmentPaymentMode,
            preceptionPaymentMode: preceptionPaymentMode,
            doctorName: doctorNameStr,
            chiefComplaint: chiefComplaintStr,
          );
        }),
        ...labworks.present.values.where((lw) => lw.patientID == id).map((lw) {
          final costStr = '₹${lw.price.toStringAsFixed(2)}';
          final paidStr = lw.paid ? costStr : '₹0.00';
          final workType =
              lw.typeOfWork.trim().isEmpty ? 'Labwork' : lw.typeOfWork;
          final labName = lw.lab.trim().isEmpty ? '-' : lw.lab;
          final teeth = lw.selectedTeeth.join(', ');

          return ReportDetailRow(
            date: lw.date,
            cost: costStr,
            paid: paidStr,
            prescription: '',
            treatment: 'Labwork: $workType • $labName',
            teeth: teeth,
            isDone: lw.deliveredToPatient,
            treatmentPaymentMode: lw.paid ? 'Paid' : 'Due',
            preceptionPaymentMode: '',
          );
        }),
      ]..sort((a, b) => a.date.compareTo(b.date));

  List<Appointment>? _doneAppointmentsCached;
  List<Appointment> get doneAppointments {
    return _doneAppointmentsCached ??= (appointments.byPatient[id]?["done"] ??
            [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get upcomingAppointments {
    return (appointments.byPatient[id]?["upcoming"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<Appointment> get pastAppointments {
    return (appointments.byPatient[id]?["past"] ?? [])
        .where((appointment) => appointment.archived != true || showArchived())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int get age {
    return birth;
  }

  double get paymentsMade => _financialStats.paymentsMade;

  double get pricesGiven => _financialStats.pricesGiven;

  bool get overPaid {
    return paymentsMade > pricesGiven;
  }

  bool get fullPaid {
    return paymentsMade == pricesGiven;
  }

  bool get underPaid {
    return paymentsMade < pricesGiven;
  }

  double get outstandingPayments {
    return pricesGiven - paymentsMade;
  }

  int? get daysSinceLastAppointment => _financialStats.daysSinceLastAppointment;

  @override
  get avatar {
    if (launch.isDemo) return "https://person.alisaleem.workers.dev/";
    final appointmentsWithImages =
        allAppointments.where((a) => a.imgs.isNotEmpty);
    if (appointmentsWithImages.isEmpty) return null;
    return appointmentsWithImages.first.imgs.first;
  }

  @override
  get imageRowId {
    final appointmentsWithImages =
        allAppointments.where((a) => a.imgs.isNotEmpty);
    if (appointmentsWithImages.isEmpty) return null;
    return appointmentsWithImages.first.id;
  }

  get webPageLink {
    return "https://patient.apexo.app/${encode("$id|$title|${login.url}")}";
  }

  @override
  Map<String, String> get labels {
    Map<String, String> buildingLabels = {
      "Age": birth.toString(),
    };

    if (daysSinceLastAppointment == null) {
      buildingLabels["Last visit"] = txt("noVisits");
    } else {
      buildingLabels["Last visit"] =
          "$daysSinceLastAppointment ${txt("daysAgo")}";
    }

    if (gender == 0) {
      buildingLabels["Gender"] = "♀";
    } else {
      buildingLabels["Gender"] = "♂️";
    }

    if (outstandingPayments > 0) {
      buildingLabels["Pay"] = txt("underpaid");
    }
    if (outstandingPayments < 0) {
      buildingLabels["Pay"] = txt("overpaid");
    }

    buildingLabels["Price"] = "Price";

    if (paymentsMade != 0) {
      buildingLabels["Total payments"] = "$paymentsMade";
    }
    final specialTreatments = ["RCT", "Ortho", "Crown"];
    final foundSpecials = <String>{};

    for (final appointment in allAppointments) {
      for (final treatment in appointment.selectedTreatments) {
        for (final special in specialTreatments) {
          if (treatment.toLowerCase().contains(special.toLowerCase())) {
            foundSpecials.add(special);
          }
        }
      }
    }
    int specialIndex = 1;
    for (final special in specialTreatments) {
      if (foundSpecials.contains(special)) {
        buildingLabels[List.generate(specialIndex, (_) => "\u200C").join("")] =
            special;
        specialIndex++;
      }
    }

    for (var i = 0; i < tags.length; i++) {
      buildingLabels[List.generate(i + 1, (_) => "\u200B").join("")] = tags[i];
    }

    final labworksCount =
        labworks.present.values.where((lw) => lw.patientID == id).length;
    if (labworksCount > 0) {
      buildingLabels["Labworks"] = labworksCount.toString();
    }

    return buildingLabels;
  }

  // id: id of the patient (inherited from Model)
  // title: name of the patient (inherited from Model)
  /* 1 */ int birth = 0;
  /* 2 */ int gender = 0; // 0 for female, 1 for male
  /* 3 */ String phone = "";
  /* 4 */ String email = "";
  /* 5 */ String address = "";
  /* 6 */ List<String> tags = [];
  /* 7 */ Map<String, String> teeth = {};
  /* 8 */ String referralSource = '';
  /* 9 */ List<String> drugHistorySuggestions = [];
  /* 10 */ List<String> maternalHistorySuggestions = [];
  /* 11 */ List<String> habitsSuggestions = [];

  @override
  Patient.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    nullifyCachedAppointments(_) {
      _doneAppointmentsCached = null;
      _allAppointmentsCached = null;
      _financialStatsCached = null;
    }

    showArchived.observe(nullifyCachedAppointments);
    appointments.observableMap.observe(nullifyCachedAppointments);

    /* 1 */ birth = json['birth'] ?? birth;
    /* 2 */ gender = json['gender'] ?? gender;
    /* 3 */ phone = json['phone'] ?? phone;
    /* 4 */ email = json['email'] ?? email;
    /* 5 */ address = json['address'] ?? address;
    /* 6 */ tags = List<String>.from(json['tags'] ?? tags);
    /* 7 */ teeth = Map<String, String>.from(json['teeth'] ?? teeth);
    /* 8 */ referralSource = json['referralSource'] ?? referralSource;
    /* 9 */ drugHistorySuggestions =
      List<String>.from(json['drugHistorySuggestions'] ?? []);
    /* 10 */ maternalHistorySuggestions =
      List<String>.from(json['maternalHistorySuggestions'] ?? []);
    /* 11 */ habitsSuggestions =
      List<String>.from(json['habitsSuggestions'] ?? []);
  }
  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Patient.fromJson({});

    /* 1 */ if (birth != d.birth) json['birth'] = birth;
    /* 2 */ if (gender != d.gender) json['gender'] = gender;
    /* 3 */ if (phone != d.phone) json['phone'] = phone;
    /* 4 */ if (email != d.email) json['email'] = email;
    /* 5 */ if (address != d.address) json['address'] = address;
    /* 6 */ if (tags.toString() != d.tags.toString()) json['tags'] = tags;
    /* 7 */ if (teeth.isNotEmpty) json['teeth'] = teeth;
    /* 8 */ if (referralSource != d.referralSource) {
      json['referralSource'] = referralSource;
    }
    /* 9 */ if (drugHistorySuggestions.toString() !=
        d.drugHistorySuggestions.toString()) {
      json['drugHistorySuggestions'] = drugHistorySuggestions;
    }
    /* 10 */ if (maternalHistorySuggestions.toString() !=
        d.maternalHistorySuggestions.toString()) {
      json['maternalHistorySuggestions'] = maternalHistorySuggestions;
    }
    /* 11 */ if (habitsSuggestions.toString() != d.habitsSuggestions.toString()) {
      json['habitsSuggestions'] = habitsSuggestions;
    }
    return json;
  }

  _PatientFinancialStats? _financialStatsCached;

  _PatientFinancialStats get _financialStats {
    if (_financialStatsCached != null) return _financialStatsCached!;

    double paid = 0.0;
    double price = 0.0;
    DateTime? lastDoneDate;

    for (final appointment in allAppointments) {
      if (appointment.isDone != true) continue;

      paid += appointment.paid;
      price += appointment.price;

      if (lastDoneDate == null || appointment.date.isAfter(lastDoneDate)) {
        lastDoneDate = appointment.date;
      }
    }

    _financialStatsCached = _PatientFinancialStats(
      paymentsMade: paid,
      pricesGiven: price,
      daysSinceLastAppointment: lastDoneDate == null
          ? null
          : DateTime.now().difference(lastDoneDate).inDays,
    );

    return _financialStatsCached!;
  }
}

class _PatientFinancialStats {
  final double paymentsMade;
  final double pricesGiven;
  final int? daysSinceLastAppointment;

  const _PatientFinancialStats({
    required this.paymentsMade,
    required this.pricesGiven,
    required this.daysSinceLastAppointment,
  });
}
