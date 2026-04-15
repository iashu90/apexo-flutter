import 'package:apexo/core/model.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/patients/patient_model.dart';
import 'package:apexo/features/patients/patients_store.dart';
import 'package:apexo/features/doctors/doctor_model.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:apexo/services/login.dart';
import 'package:intl/intl.dart';

class Labwork extends Model {
  @override
  bool get locked {
    if (operators.isEmpty) return false;
    if (login.isAdmin) return false;
    return operators.every((element) => element.locked);
  }

  @override
  Map<String, String> get labels {
    final map = <String, String>{
      "Patient":
          patient != null ? "${patient!.title}\n${patient!.phone}" : "Unknown",
      "Type": typeOfWork,
      "Teeth": selectedTeeth.map((e) => e.toString()).join(", "),
      "Units": noOfUnits.toString(),
      "Shade": shade,
      "Laboratory": lab,
      "Paid": paid ? txt("paid") : txt("due"),
      "Price": (paid ? "" : "-") + price.toStringAsFixed(2),
      "doctors": operators.map((e) => e.title).join(", "),
      "Delivered":
          "${deliveredToDoctor ? "Ready" : "Not ready"} / ${deliveredToPatient ? "Delivered" : "Not delivered"}",
    };
    return map;
  }

  Patient? get patient {
    if (patientID == null || patientID!.isEmpty) return null;
    return patients.get(patientID!);
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

  @override
  String get title {
    //return DateFormat(localSettings.dateFormat, locale.s.$code).format(date);
    return DateFormat("yyyy-MM-dd").format(date);
  }

  // id: id of the labwork (inherited from Model)
  // title: title of the labwork (inherited from Model)
  List<String> operatorsIDs = [];
  String? patientID;
  String note = "";
  bool paid = false;
  double price = 0;
  DateTime date = DateTime.now();
  String lab = "";
  String phoneNumber = "";
  String typeOfWork = "";
  int noOfUnits = 0;
  String shade = "";
  bool deliveredToDoctor = false;
  bool deliveredToPatient = false;
  List<String> selectedTeeth = [];

  Labwork.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    operatorsIDs = List<String>.from(json["operatorsIDs"] ?? operatorsIDs);
    patientID = json["patientID"] ?? patientID;
    note = json["note"] ?? note;
    price = double.parse((json["price"] ?? price).toString());
    paid = json["paid"] ?? paid;
    date = json["date"] != null
        ? DateTime.fromMillisecondsSinceEpoch(json["date"] * (60 * 60 * 1000))
        : date;
    lab = json["lab"] ?? lab;
    phoneNumber = json["phoneNumber"] ?? phoneNumber;
    typeOfWork = json["typeOfWork"] ?? typeOfWork;
    noOfUnits = int.tryParse(json["noOfUnits"]?.toString() ?? "") ?? noOfUnits;
    shade = json["shade"] ?? shade;
    deliveredToDoctor = json["deliveredToDoctor"] ?? false;
    deliveredToPatient = json["deliveredToPatient"] ?? false;
    selectedTeeth = List<String>.from(json['selectedTeeth'] ?? []);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    final d = Labwork.fromJson({});
    if (operatorsIDs.isNotEmpty) json['operatorsIDs'] = operatorsIDs;
    if (patientID != d.patientID) json['patientID'] = patientID;
    if (note != d.note) json['note'] = note;
    if (price != d.price) json['price'] = price;
    if (paid != d.paid) json['paid'] = paid;
    json['date'] = (date.millisecondsSinceEpoch / (60 * 60 * 1000)).round();
    if (lab != d.lab) json['lab'] = lab;
    if (phoneNumber != d.phoneNumber) json['phoneNumber'] = phoneNumber;
    if (typeOfWork != d.typeOfWork) json['typeOfWork'] = typeOfWork;
    if (noOfUnits != d.noOfUnits) json['noOfUnits'] = noOfUnits;
    if (shade != d.shade) json['shade'] = shade;
    json['deliveredToDoctor'] = deliveredToDoctor;
    json['deliveredToPatient'] = deliveredToPatient;
    if (selectedTeeth.isNotEmpty) json['selectedTeeth'] = selectedTeeth;
    return json;
  }
}
