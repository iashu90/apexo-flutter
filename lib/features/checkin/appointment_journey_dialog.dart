import 'package:fluent_ui/fluent_ui.dart';
import 'package:apexo/core/ui/components/app_button.dart';

typedef AppointmentJourneyStepBuilder = Widget Function(
  BuildContext context,
  int currentStep,
  double panelHeight,
);

typedef AppointmentJourneyAssignHandler = Future<void> Function(
  BuildContext context,
  void Function(int step) setStep,
);

typedef AppointmentJourneyBeforeAdvance = Future<void> Function(
  BuildContext context,
  int currentStep,
  int nextStep,
);

Future<void> showAppointmentJourneyDialog({
  required BuildContext context,
  required String title,
  required String patientName,
  required String patientContext,
  required int initialStep,
  required AppointmentJourneyStepBuilder stepBuilder,
  AppointmentJourneyAssignHandler? onAssignFromWaiting,
  AppointmentJourneyBeforeAdvance? onBeforeStepAdvance,
}) async {
  var currentStep = initialStep.clamp(0, 2);
  const labels = ['Step 1', 'Step 2', 'Step 3', 'Step 4'];
  const subtitles = [
    'Checked In',
    'Treatment',
    'Billing',
    'Completed',
  ];

  List<Color> headerGradient(int step) {
    switch (step) {
      case 0:
        return const [Color(0xFF5A84E6), Color(0xFF3F68CC)];
      case 1:
        return const [Color(0xFF14B8A6), Color(0xFF0F9D8B)];
      case 2:
        return const [Color(0xFF8B5CF6), Color(0xFF6D3FD2)];
      case 3:
        return const [Color(0xFF2BA58D), Color(0xFF1D8D77)];
      default:
        return const [Color(0xFFE4A11B), Color(0xFFD28C02)];
    }
  }

  Color stepColor(int step) {
    switch (step) {
      case 0:
        return const Color(0xFF2D7BD8);
      case 1:
        return const Color(0xFF0F9D8B);
      case 2:
        return const Color(0xFF6D3FD2);
      case 3:
        return const Color(0xFF1D8D77);
      default:
        return const Color(0xFFD28C02);
    }
  }

  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x660A1B33),
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setStateDialog) {
        final screen = MediaQuery.of(context).size;
        final dialogWidth = (screen.width - 30).clamp(760.0, 1020.0);
        final dialogHeight = (screen.height * 0.9).clamp(560.0, screen.height);
        final panelHeight = (dialogHeight * 0.58).clamp(320.0, 620.0);

        Widget stepNode(int index) {
          final isCheckinStep = index == 0;
          final logicalStep = isCheckinStep ? -1 : index - 1;
          final selected = !isCheckinStep && logicalStep == currentStep;
          final complete = isCheckinStep || logicalStep < currentStep;
          final selectedColor = stepColor(logicalStep < 0 ? 0 : logicalStep);

          return GestureDetector(
            // Keep top stepper display-only; progression is controlled by footer actions.
            onTap: null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? selectedColor
                        : complete
                            ? const Color(0xFF2BA58D)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? selectedColor
                          : complete
                              ? const Color(0xFF2BA58D)
                              : const Color(0xFFB8C2D1),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: complete
                      ? const Icon(FluentIcons.check_mark, size: 12, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: selected ? Colors.white : const Color(0xFF5E6E85),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  style: TextStyle(
                    color: selected
                        ? selectedColor
                        : complete
                            ? const Color(0xFF1D8D77)
                            : const Color(0xFF233B5F),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitles[index],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7E8795),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        Future<void> handleContinue() async {
          if (currentStep < 2) {
            final beforeAdvance = onBeforeStepAdvance;
            if (beforeAdvance != null) {
              await beforeAdvance(context, currentStep, currentStep + 1);
            }
            setStateDialog(() {
              currentStep += 1;
            });
            return;
          }

          Navigator.pop(dialogContext);
        }

        String? currentPrimaryLabel() {
          if (currentStep == 0) return 'Treatment Complete';
          if (currentStep == 1) return 'Billing Complete';
          return null;
        }

        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              margin: const EdgeInsets.fromLTRB(10, 12, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2A0D2F5B),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: headerGradient(currentStep)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$patientName • $patientContext',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEAF2FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(FluentIcons.cancel, size: 12),
                          style: ButtonStyle(
                            foregroundColor: WidgetStateProperty.all(Colors.white),
                          ),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: dialogWidth - 28,
                              child: Stack(
                                children: [
                                  Positioned(
                                    top: 20,
                                    left: 40,
                                    right: 40,
                                    child: Row(
                                      children: List.generate(
                                        labels.length - 1,
                                        (index) => Expanded(
                                          child: Container(
                                            height: 2,
                                            color: (index == 0 || index - 1 < currentStep)
                                                ? const Color(0xFF2BA58D)
                                                : const Color(0xFFC9D3E0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      labels.length,
                                      (index) => Expanded(
                                        child: Center(child: stepNode(index)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: stepBuilder(context, currentStep, panelHeight),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (currentPrimaryLabel() != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFE2ECF8))),
                      ),
                      child: Row(
                        children: [
                          AppButton(
                            label: 'Cancel',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                          const SizedBox(width: 8),
                          if (currentStep > 0)
                            AppButton(
                              label: 'Back',
                              variant: AppButtonVariant.secondary,
                              onPressed: () {
                                setStateDialog(() {
                                  currentStep -= 1;
                                });
                              },
                            ),
                          const Spacer(),
                          AppButton(
                            label: currentPrimaryLabel()!,
                            onPressed: handleContinue,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
