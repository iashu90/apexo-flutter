import 'package:apexo/common_widgets/delete_confirmation.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/expenses/open_expense_panel.dart';
import 'package:apexo/common_widgets/datatable.dart';
import 'package:apexo/features/expenses/expense_model.dart';
import 'package:apexo/features/expenses/expenses_store.dart';
import 'package:apexo/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      key: WK.expensesScreen,
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          Expanded(
            child: StreamBuilder(
                stream: expenses.observableMap.stream,
                builder: (context, snapshot) {
                  return DataTable<Expense>(
                    compact: true,
                    items: expenses.present.values.toList(),
                    store: expenses,
                    actions: [
                      DataTableAction(
                        callback: (_) {
                          openExpense();
                        },
                        icon: FluentIcons.bill,
                        title: txt("add"),
                      ),
                      DataTableAction(
                        icon: FluentIcons.delete,
                        title: txt("delete"),
                        enabled: (ids) => ids.isNotEmpty,
                        callback: (ids) async {
                          final names = ids
                              .map((id) {
                                final exp = expenses.get(id);
                                if (exp == null) return null;
                                return "${exp.title} (${exp.issuer})";
                              })
                              .where((str) => str != null && str.isNotEmpty)
                              .join("\n");
                          final confirmed = await showConfirmDeleteDialog(
                            context,
                            message:
                                "Are you sure you want to delete the selected expenses?",
                            customDetails: names.isNotEmpty ? names : null,
                          );
                          if (confirmed == true) {
                            await Future.wait(
                                ids.map((id) => expenses.hardDelete(id)));
                          }
                        },
                      ),
                    ],
                    furtherActions: const [
                      SizedBox(width: 5),
                    ],
                    onSelect: (item) => {openExpense(item)},
                    itemActions: [
                      ItemAction(
                        icon: FluentIcons.phone,
                        title: txt("callIssuer"),
                        callback: (id) {
                          final receipt = expenses.get(id);
                          if (receipt == null) return;
                          launchUrl(Uri.parse('tel:${receipt.phoneNumber}'));
                        },
                      ),
                    ],
                    defaultSortDirection: -1,
                    defaultSortingName: "byDate",
                  );
                }),
          ),
        ],
      ),
    );
  }
}
