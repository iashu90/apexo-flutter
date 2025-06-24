import 'package:apexo/features/data/prescriptions_store.dart';
import 'package:apexo/features/data/prescriptions_model.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final TextEditingController prescriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // Get all prescriptions from the appointments store
    // final prescriptions = appointments.allPrescriptions;

    return ScaffoldPage(
      header: PageHeader(title: Text("App Data")),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ListView(
          children: [
            DataSectionItem(
              title: txt("prescription"),
              description: "Add and manage prescriptions.",
              icon: FluentIcons.database,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: prescriptionController,
                          placeholder: "Enter prescription",
                          onSubmitted: (value) {
                            final val = value.trim();
                            // Prescriptions prescriptions = Prescriptions();
                            // prescriptions.title = val;
                            // //if (val.isNotEmpty && !prescriptions.contains(val)) {
                            // if (val.isNotEmpty) {
                            //   setState(() {
                            //     prescriptionController.clear();
                            //   });
                            // }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text("Add"),
                        onPressed: () {
                          final val = prescriptionController.text.trim();
                          //if (val.isNotEmpty && !prescriptions.contains(val)) {
                          if (val.isNotEmpty) {
                            setState(() {
                              Prescriptions prescriptions = Prescriptions();
                              prescriptions.prescription = val;
                              prescriptionsStore.set(prescriptions);
                              prescriptionController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Wrap(
                  //   spacing: 8,
                  //   runSpacing: 8,
                  //   children: prescriptions
                  //       .map(
                  //         (prescription) => Container(
                  //           padding: const EdgeInsets.symmetric(
                  //               horizontal: 12, vertical: 6),
                  //           decoration: BoxDecoration(
                  //             color: FluentTheme.of(context)
                  //                 .accentColor
                  //                 .withOpacity(0.12),
                  //             borderRadius: BorderRadius.circular(20),
                  //             border: Border.all(
                  //               color: FluentTheme.of(context).accentColor,
                  //               width: 1,
                  //             ),
                  //           ),
                  //           child: Row(
                  //             mainAxisSize: MainAxisSize.min,
                  //             children: [
                  //               Text(
                  //                 prescription,
                  //                 style: const TextStyle(
                  //                     fontWeight: FontWeight.w500),
                  //               ),
                  //               const SizedBox(width: 6),
                  //               Button(
                  //                 style: ButtonStyle(
                  //                   padding: ButtonState.all(EdgeInsets.zero),
                  //                   backgroundColor:
                  //                       ButtonState.all(Colors.transparent),
                  //                 ),
                  //                 child:
                  //                     const Icon(FluentIcons.cancel, size: 16),
                  //                 onPressed: () {
                  //                   setState(() {
                  //                     // Remove from your backend/store here if needed
                  //                     // appointments.removePrescription(prescription); // You need to implement this method
                  //                   });
                  //                 },
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       )
                  //       .toList(),
                  // ),
                ],
              ),
            ),
            DataSectionItem(
              title: "Treatment",
              description: "Description for section 2.",
              icon: FluentIcons.table,
              content: const Text("Content of Section 2"),
            ),
          ],
        ),
      ),
    );
  }
}

class DataSectionItem extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Widget content;

  const DataSectionItem({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.content,
  });

  @override
  State<DataSectionItem> createState() => _DataSectionItemState();
}

class _DataSectionItemState extends State<DataSectionItem> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Expander(
        leading: Icon(widget.icon),
        header: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.normal)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description,
                  style: const TextStyle(
                      fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              widget.content,
            ],
          ),
        ),
        initiallyExpanded: false,
      ),
    );
  }
}
