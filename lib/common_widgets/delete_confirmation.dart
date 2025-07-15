import 'package:apexo/core/activity_logger.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

Future<bool?> showConfirmDeleteDialog(
  BuildContext context, {
  String? message,
  String?
      customDetails, // Pass details about what is being deleted (newline-separated)
}) {
  final baseMessage = message ?? 'Are you sure you want to delete this item?';

  // Prepare highlighted details if present
  Widget? detailsWidget;
  if (customDetails != null && customDetails.trim().isNotEmpty) {
    // Split by newlines and remove empty lines
    final lines =
        customDetails.split('\n').where((l) => l.trim().isNotEmpty).toList();
    detailsWidget = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...lines.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "${entry.key + 1}. ${entry.value}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: material.Colors.black,
                      fontSize: 15, // Bigger and bolder for focus
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => ContentDialog(
      title: const Text('Confirm Delete'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(baseMessage),
          if (detailsWidget != null) detailsWidget,
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancel'),
          onPressed: () {
            ActivityLogger.logAction(
              "Delete Confirmation Cancelled",
              screen: "DeleteConfirmationDialog",
              data: {"message": baseMessage, "details": customDetails},
            );
            Navigator.pop(context, false);
          },
        ),
        FilledButton(
          style: ButtonStyle(
            backgroundColor:
                ButtonState.all(material.Colors.red), // Make button red
          ),
          child: const Text('Delete'),
          onPressed: () {
            ActivityLogger.logAction(
              "Delete Confirmed",
              screen: "DeleteConfirmationDialog",
              data: {"message": baseMessage, "details": customDetails},
            );
            Navigator.pop(context, true);
          },
        ),
      ],
    ),
  );
}
