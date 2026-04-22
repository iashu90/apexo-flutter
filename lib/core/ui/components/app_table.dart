import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class AppTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const AppTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.primary50),
        columns: columns,
        rows: rows,
        columnSpacing: 40,
        dataRowMinHeight: 60,
      ),
    );
  }
}
