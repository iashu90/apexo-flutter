import 'package:apexo/core/model.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';

class Appointment extends Model {
  @override
  String? get avatar {
    if (launch.isDemo) return "https://person.alisaleem.workers.dev/";
    if (imgs.isEmpty) return null;
    return imgs.first;
  }

  @override
  String get title {
    if (patient == null) {
      return "  ";
    } else if (patient!.title.isEmpty) {
      return "  ";
    } else {
      return patient!.title;
    }
  }

  Patient? get patient {
    if (patientID == null || patientID!.isEmpty) return null;
    return patients.get(patientID!);
  }

  @override
  bool get locked {
    if (operators.isEmpty) return false;
    if (login.isAdmin) return false;
    return operators.every((element) => element.locked);
  }

  List<Doctor> get operators {
    List<Doctor> foundOperators = [];
    for (var id in operatorsIDs) {
      var found = doctors.get(id);
      if (found != null) {
        foundOperators.add(found);
      }
    }
    return foundOperators;
  }

  Set<int> get availableWeekDays {
    return operators
        .expand((element) => element.dutyDays)
        .toSet()
        .map((day) => allDays.indexOf(day) + 1)
        .toSet();
  }

  String get subtitleLine1 {
    return "${isDone ? "✔️ " : ""}${isDone && postOpNotes.isNotEmpty ? postOpNotes : preOpNotes}";
  }

  String get subtitleLine2 {
    if (operatorsIDs.isEmpty) return "";
    return "👨‍⚕️ ${operatorsIDs.map((id) => doctors.get(id)?.title).join(", ")}";
  }

  bool get fullPaid {
    return paid == price;
  }

  bool get overPaid {
    return paid > price;
  }

  bool get underPaid {
    return paid < price;
  }

  double get paymentDifference {
    return (paid - price).abs();
  }

  bool get isMissed {
    return date.isBefore(DateTime.now()) &&
        date.difference(DateTime.now()).inDays.abs() > 0 &&
        !isDone;
  }

  bool get firstAppointmentForThisPatient {
    if (patient == null) return false;
    return patient!.allAppointments.first == this;
  }

  // id: id of the appointment (inherited from Model)

  /* 1 */ List<String> operatorsIDs = [];
  /* 2 */ String? patientID;
  String? consultantDoctorID;
  /* 3 */ String preOpNotes = "";
  /* 4 */ String postOpNotes = "";
  /* 5 */ List<String> prescriptions = [];
  /* 6 */ double price = 0;
  double discountedPrice = 0;
  /* 7 */ double paid = 0;
  double priceToPayDoctor = 0;
  double paidToDoctor = 0;
  /* 6a */ double prescriptionPrice = 0;
/* 7a */ double prescriptionPaid = 0;
  /* 8 */ List<String> imgs = [];
  /* 9 */ DateTime date = DateTime.now();
  /* 10 */ bool isDone = false;
  double discount = 0.0;
  String discountType = 'flat'; // or 'percent'
  List<String> diagnosis = [];

  /* 12 */ List<String> selectedTreatments = [];
  List<String> subTreatments = [];
  /* 13 */ List<String> selectedTeeth = [];
  bool treatmentGpayPaid = false;
  bool prescriptionGpayPaid = false;
  bool isCheckedIn = false;
  String checkinStage = 'pending';
  String visitType = 'Follow-up Visit';
  DateTime? checkedInAt;

  Appointment.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    /* 1 */ operatorsIDs =
        List<String>.from(json["operatorsIDs"] ?? operatorsIDs);
    /* 2 */ prescriptions =
        List<String>.from(json["prescriptions"] ?? prescriptions);
    /* 3 */ patientID = json["patientID"] ?? patientID;
    consultantDoctorID = json['consultantDoctorID'] ?? consultantDoctorID;
    /* 4 */ preOpNotes = json["preOpNotes"] ?? preOpNotes;
    /* 5 */ postOpNotes = json["postOpNotes"] ?? postOpNotes;
    /* 6 */ price = double.parse((json["price"] ?? price).toString());
    discountedPrice =
        double.parse((json["discountedPrice"] ?? discountedPrice).toString());
    /* 7 */ paid = double.parse((json["paid"] ?? paid).toString());
    priceToPayDoctor =
        double.parse((json["priceToPayDoctor"] ?? priceToPayDoctor).toString());

    paidToDoctor =
        double.parse((json["paidToDoctor"] ?? paidToDoctor).toString());
    prescriptionPrice = double.parse(
        (json["prescriptionPrice"] ?? prescriptionPrice).toString());
    prescriptionPaid =
        double.parse((json["prescriptionPaid"] ?? prescriptionPaid).toString());

    /* 8 */ imgs = List<String>.from(json["imgs"] ?? imgs);
    int? raw = json["date"];
    if (raw != null) {
      if (raw < 100000000000) {
        // Old data: minutes since epoch
        date = DateTime.fromMillisecondsSinceEpoch(raw * 60000);
      } else {
        // New data: milliseconds since epoch
        date = DateTime.fromMillisecondsSinceEpoch(raw);
      }
    }
    /* 10 */ isDone = (json["isDone"] ?? isDone);
    /* 12 */ selectedTreatments =
        List<String>.from(json["selectedTreatments"] ?? []);
    /* 13 */ selectedTeeth = List<String>.from(json['selectedTeeth'] ?? []);
    subTreatments = List<String>.from(json['subTreatments'] ?? []);
    // In fromJson:
    discount = (json['discount'] ?? 0).toDouble();
    discountType = json['discountType'] ?? 'flat';
    treatmentGpayPaid = json['treatmentGpayPaid'] ?? false;
    prescriptionGpayPaid = json['prescriptionGpayPaid'] ?? false;
    isCheckedIn = json['isCheckedIn'] ?? false;
    checkinStage = (json['checkinStage'] ?? '').toString().trim();
    visitType = (json['visitType'] ?? visitType).toString().trim();
    if (visitType.isEmpty) {
      visitType = 'Follow-up Visit';
    }
    if (checkinStage.isEmpty) {
      checkinStage = isDone ? 'completed' : 'pending';
    }
    final rawCheckedInAt = json['checkedInAt'];
    if (rawCheckedInAt is int) {
      checkedInAt = DateTime.fromMillisecondsSinceEpoch(rawCheckedInAt);
    }
    diagnosis = List<String>.from(json['diagnosis'] ?? []);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Appointment.fromJson({});
    /* 1 */ if (operatorsIDs.isNotEmpty) json['operatorsIDs'] = operatorsIDs;
    /* 2 */ if (prescriptions.isNotEmpty) json['prescriptions'] = prescriptions;
    /* 3 */ if (patientID != d.patientID) json['patientID'] = patientID;
    if (consultantDoctorID != d.consultantDoctorID) {
      json['consultantDoctorID'] = consultantDoctorID;
    }
    /* 4 */ if (preOpNotes != d.preOpNotes) json['preOpNotes'] = preOpNotes;
    /* 5 */ if (postOpNotes != d.postOpNotes) json['postOpNotes'] = postOpNotes;
    /* 6 */ if (price != d.price) json['price'] = price;
    if (discountedPrice != d.discountedPrice) {
      json['discountedPrice'] = discountedPrice;
    }
    /* 7 */ if (paid != d.paid) json['paid'] = paid;
    if (priceToPayDoctor != d.priceToPayDoctor) {
      json['priceToPayDoctor'] = priceToPayDoctor;
    }
    if (paidToDoctor != d.paidToDoctor) json['paidToDoctor'] = paidToDoctor;
    if (prescriptionPrice != d.prescriptionPrice) {
      json['prescriptionPrice'] = prescriptionPrice;
    }
    if (prescriptionPaid != d.prescriptionPaid) {
      json['prescriptionPaid'] = prescriptionPaid;
    }
    /* 8 */ if (imgs.isNotEmpty) json['imgs'] = imgs;
    /* 9 */ if (isDone != d.isDone) json['isDone'] = isDone;
    json['date'] = date.millisecondsSinceEpoch;
    /* 12 */ if (selectedTreatments.isNotEmpty) {
      json['selectedTreatments'] = selectedTreatments;
    }
    json['subTreatments'] = subTreatments;
    /* 13 */ if (selectedTeeth.isNotEmpty) {
      json['selectedTeeth'] = selectedTeeth;
    }
    if (discount != d.discount) json['discount'] = discount;
    if (discountType != d.discountType) json['discountType'] = discountType;
    json['treatmentGpayPaid'] = treatmentGpayPaid;
    json['prescriptionGpayPaid'] = prescriptionGpayPaid;
    if (isCheckedIn != d.isCheckedIn) json['isCheckedIn'] = isCheckedIn;
    if (checkinStage != d.checkinStage) json['checkinStage'] = checkinStage;
    if (visitType != d.visitType) json['visitType'] = visitType;
    if (checkedInAt != null) {
      json['checkedInAt'] = checkedInAt!.millisecondsSinceEpoch;
    }
    json['diagnosis'] = diagnosis;
    json.remove("title"); // remove since it is a computed value in this case

    return json;
  }
}
