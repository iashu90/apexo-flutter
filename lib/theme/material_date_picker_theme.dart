import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;

material.TransitionBuilder apexoDatePickerBuilder(BuildContext context) {
  final fluent = FluentTheme.of(context);
  final brightness = fluent.brightness == Brightness.dark
      ? material.Brightness.dark
      : material.Brightness.light;
  final seed = fluent.accentColor;

  final scheme = material.ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );

  final themed = material.ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    datePickerTheme: material.DatePickerThemeData(
      backgroundColor: scheme.surface,
      headerBackgroundColor: scheme.primary,
      headerForegroundColor: scheme.onPrimary,
      dayForegroundColor: material.WidgetStateProperty.resolveWith((states) {
        if (states.contains(material.WidgetState.selected)) {
          return scheme.onPrimary;
        }
        return scheme.onSurface;
      }),
      dayBackgroundColor: material.WidgetStateProperty.resolveWith((states) {
        if (states.contains(material.WidgetState.selected)) {
          return scheme.primary;
        }
        if (states.contains(material.WidgetState.hovered)) {
          return scheme.primaryContainer.withValues(alpha: 0.35);
        }
        return null;
      }),
      todayForegroundColor: material.WidgetStateProperty.resolveWith((states) {
        if (states.contains(material.WidgetState.selected)) {
          return scheme.onPrimary;
        }
        return scheme.primary;
      }),
      todayBorder: material.BorderSide(color: scheme.primary),
      rangeSelectionBackgroundColor: scheme.primary.withValues(alpha: 0.14),
      confirmButtonStyle: material.ButtonStyle(
        foregroundColor: material.WidgetStateProperty.all(scheme.primary),
      ),
      cancelButtonStyle: material.ButtonStyle(
        foregroundColor: material.WidgetStateProperty.all(scheme.primary),
      ),
    ),
  );

  return (context, child) {
    return material.Theme(
      data: themed,
      child: child ?? const SizedBox.shrink(),
    );
  };
}
