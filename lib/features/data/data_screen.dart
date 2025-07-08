import 'package:apexo/features/appointments/treatment_model.dart';
import 'package:apexo/features/data/prescriptions_store.dart';
import 'package:apexo/features/data/prescriptions_model.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final TextEditingController prescriptionController = TextEditingController();
  final TextEditingController treatmentController = TextEditingController();

  final List<Treatment> treatments = [];
  @override
  Widget build(BuildContext context) {
    // Get all prescriptions from the appointments store
    // final prescriptions = appointments.allPrescriptions;

    return ScaffoldPage(
      header: PageHeader(title: Text(txt("data"))),
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        child: const Text("Add"),
                        onPressed: () {
                          final val = prescriptionController.text.trim();
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
                  StreamBuilder(
                    stream: prescriptionsStore.observableMap.stream,
                    builder: (context, snapshot) {
                      final prescriptions = prescriptionsStore.present.values
                          .map((p) => p.prescription)
                          .toList();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: prescriptions
                            .map(
                              (prescription) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: FluentTheme.of(context)
                                      .accentColor
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: FluentTheme.of(context).accentColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      prescription,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 6),
                                    Button(
                                      style: ButtonStyle(
                                        padding:
                                            ButtonState.all(EdgeInsets.zero),
                                        backgroundColor:
                                            ButtonState.all(Colors.transparent),
                                      ),
                                      child: const Icon(FluentIcons.cancel,
                                          size: 16),
                                      onPressed: () {
                                        setState(() {
                                          Prescriptions? toDelete;
                                          for (final p in prescriptionsStore
                                              .present.values) {
                                            if (p.prescription ==
                                                prescription) {
                                              toDelete = p;
                                              break;
                                            }
                                          }
                                          if (toDelete != null) {
                                            prescriptionsStore
                                                .hardDelete(toDelete.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            DataSectionItem(
              title: "Treatment",
              description: "Add and manage treatments.",
              icon: FluentIcons.table,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Remove the TextBox, just keep the Add button
                      Button(
                        child: const Text("Add"),
                        onPressed: () async {
                          final val = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (context) {
                              final dialogController = TextEditingController();
                              final priceController = TextEditingController();
                              bool isMultiple = false;
                              return StatefulBuilder(
                                builder: (context, setState) => ContentDialog(
                                  title: const Text("Add Treatment"),
                                  content: IntrinsicHeight(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 160,
                                          child: TextBox(
                                            controller: dialogController,
                                            placeholder: "Enter treatment",
                                            autofocus: true,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 80,
                                          child: TextBox(
                                            controller: priceController,
                                            placeholder: "Price",
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Checkbox(
                                          checked: isMultiple,
                                          onChanged: (v) => setState(
                                              () => isMultiple = v ?? false),
                                        ),
                                        const Text("Multiple"),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    Button(
                                      child: const Text("Cancel"),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    FilledButton(
                                      child: const Text("Add"),
                                      onPressed: () {
                                        final name =
                                            dialogController.text.trim();
                                        final price =
                                            priceController.text.trim();
                                        if (name.isNotEmpty) {
                                          Navigator.pop(context, {
                                            'name': name,
                                            'price': price,
                                            'multiple': isMultiple,
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                          if (val != null &&
                              val['name'].isNotEmpty &&
                              !treatments.any((t) => t.name == val['name'])) {
                            setState(() {
                              treatments.add(
                                Treatment(
                                  name: val['name'],
                                  price:
                                      double.tryParse(val['price'] ?? '') ?? 0,
                                  multiplier: val['multiple'] ?? false,
                                ),
                              );
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: treatments
                        .map(
                          (treatment) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: FluentTheme.of(context)
                                  .accentColor
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: FluentTheme.of(context).accentColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${treatment.name} (₹${treatment.price.toStringAsFixed(0)})"
                                  "${treatment.multiplier ? ' ×' : ''}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                                Button(
                                  style: ButtonStyle(
                                    padding: ButtonState.all(EdgeInsets.zero),
                                    backgroundColor:
                                        ButtonState.all(Colors.transparent),
                                  ),
                                  child:
                                      const Icon(FluentIcons.cancel, size: 16),
                                  onPressed: () {
                                    setState(() {
                                      treatments.remove(treatment);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  )
                ],
              ),
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
