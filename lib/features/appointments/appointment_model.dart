import 'package:apexo/core/model.dart';
import 'package:apexo/services/launch.dart';
import 'package:apexo/services/login.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/features/appointments/treatment_model.dart';

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
    if (patientID != null &&
        patientID!.isNotEmpty &&
        patients.get(patientID!) == null &&
        patientID!.length == 15) {
      patients.set(Patient.fromJson({"id": patientID}));
    }
    return patients.get(patientID ?? "return null when null");
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
  /* 3 */ String preOpNotes = "";
  /* 4 */ String postOpNotes = "";
  /* 5 */ List<String> prescriptions = [];
  /* 6 */ double price = 0;
  /* 7 */ double paid = 0;
  /* 8 */ List<String> imgs = [];
  /* 9 */ DateTime date = DateTime.now();
  /* 10 */ bool isDone = false;
  double discount = 0.0;
  String discountType = 'flat'; // or 'percent'
  /* 11 */ List<Treatment> treatments = [
    Treatment(
      name: 'Regular Exams and Cleanings',
      price: 50,
      subTreatments: [
        Treatment(name: 'Child Cleaning', price: 30),
        Treatment(name: 'Adult Cleaning', price: 60),
      ],
    ),
    Treatment(
      name: 'Dental X-rays',
      price: 40,
      subTreatments: [
        Treatment(name: 'Bitewing X-ray', price: 20),
        Treatment(name: 'Panoramic X-ray', price: 60),
      ],
    ),
    Treatment(
      name: 'Fluoride Treatments',
      price: 25,
    ),
    Treatment(
      name: 'Tooth Fillings',
      price: 120,
      subTreatments: [
        Treatment(name: 'Composite Filling', price: 130),
        Treatment(name: 'Amalgam Filling', price: 110),
      ],
    ),
    Treatment(
      name: 'Root Canal Therapy',
      price: 350,
      subTreatments: [
        Treatment(name: 'Anterior Tooth', price: 300),
        Treatment(name: 'Premolar Tooth', price: 350),
        Treatment(name: 'Molar Tooth', price: 400),
      ],
    ),
    Treatment(
      name: 'Dental Crowns',
      price: 500,
      subTreatments: [
        Treatment(name: 'Porcelain Crown', price: 600),
        Treatment(name: 'Metal Crown', price: 450),
        Treatment(name: 'Zirconia Crown', price: 700),
      ],
    ),
    Treatment(
      name: 'Teeth Whitening',
      price: 200,
      subTreatments: [
        Treatment(name: 'In-office Whitening', price: 250),
        Treatment(name: 'Take-home Kit', price: 180),
      ],
    ),
    Treatment(
      name: 'Dental Implants',
      price: 1500,
      subTreatments: [
        Treatment(name: 'Single Tooth Implant', price: 1500),
        Treatment(name: 'Multiple Teeth Implant', price: 4000),
      ],
    ),
    Treatment(
      name: 'Braces',
      price: 2500,
      subTreatments: [
        Treatment(name: 'Metal Braces', price: 2500),
        Treatment(name: 'Ceramic Braces', price: 3000),
        Treatment(name: 'Lingual Braces', price: 3500),
      ],
    ),
    Treatment(
      name: 'Dentures',
      price: 800,
      subTreatments: [
        Treatment(name: 'Partial Denture', price: 600),
        Treatment(name: 'Full Denture', price: 1000),
      ],
    ),
    Treatment(
      name: 'Tooth Extraction',
      price: 100,
      subTreatments: [
        Treatment(name: 'Simple Extraction', price: 100),
        Treatment(name: 'Surgical Extraction', price: 250),
      ],
    ),
    // ...add other treatments as needed...
  ];
  /* 12 */ List<String> selectedTreatments = [];

  Appointment.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    /* 1 */ operatorsIDs =
        List<String>.from(json["operatorsIDs"] ?? operatorsIDs);
    /* 2 */ prescriptions =
        List<String>.from(json["prescriptions"] ?? prescriptions);
    /* 3 */ patientID = json["patientID"] ?? patientID;
    /* 4 */ preOpNotes = json["preOpNotes"] ?? preOpNotes;
    /* 5 */ postOpNotes = json["postOpNotes"] ?? postOpNotes;
    /* 6 */ price = double.parse((json["price"] ?? price).toString());
    /* 7 */ paid = double.parse((json["paid"] ?? paid).toString());
    /* 8 */ imgs = List<String>.from(json["imgs"] ?? imgs);
    /* 9 */ date = (json["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch((json["date"] * 60000).toInt())
        : date);
    /* 10 */ isDone = (json["isDone"] ?? isDone);
    /* 11 */ if (json.containsKey("treatments") && json["treatments"] != null) {
      treatments = (json["treatments"] as List<dynamic>)
          .map((e) => Treatment.fromJson(e))
          .toList();
    }
    /* 12 */ selectedTreatments =
        List<String>.from(json["selectedTreatments"] ?? []);
    // In fromJson:
    discount = (json['discount'] ?? 0).toDouble();
    discountType = json['discountType'] ?? 'flat';
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Appointment.fromJson({});
    /* 1 */ if (operatorsIDs.isNotEmpty) json['operatorsIDs'] = operatorsIDs;
    /* 2 */ if (prescriptions.isNotEmpty) json['prescriptions'] = prescriptions;
    /* 3 */ if (patientID != d.patientID) json['patientID'] = patientID;
    /* 4 */ if (preOpNotes != d.preOpNotes) json['preOpNotes'] = preOpNotes;
    /* 5 */ if (postOpNotes != d.postOpNotes) json['postOpNotes'] = postOpNotes;
    /* 6 */ if (price != d.price) json['price'] = price;
    /* 7 */ if (paid != d.paid) json['paid'] = paid;
    /* 8 */ if (imgs.isNotEmpty) json['imgs'] = imgs;
    /* 9 */ if (isDone != d.isDone) json['isDone'] = isDone;
    /* 10 */ json['date'] = (date.millisecondsSinceEpoch / 60000).round();
    /* 11 */ if (treatments.isNotEmpty) {
      json['treatments'] = treatments.map((e) => e.toJson()).toList();
    }
    /* 12 */ if (selectedTreatments.isNotEmpty)
      json['selectedTreatments'] = selectedTreatments;
    if (discount != d.discount) json['discount'] = discount;
    if (discountType != d.discountType) json['discountType'] = discountType;
    json.remove("title"); // remove since it is a computed value in this case

    return json;
  }
}
