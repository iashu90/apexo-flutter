import 'package:apexo/core/multi_stream_builder.dart';
import 'package:apexo/services/localization/locale.dart';
import 'package:apexo/features/stats/widgets/charts/bar.dart';
import 'package:apexo/features/stats/widgets/charts/line.dart';
import 'package:apexo/features/stats/widgets/charts/pie.dart';
import 'package:apexo/features/stats/widgets/charts/radar.dart';
import 'package:apexo/features/stats/widgets/charts/stacked.dart';
import 'package:apexo/features/stats/widgets/range_selector.dart';
import 'package:apexo/features/stats/charts_controller.dart';
import 'package:apexo/features/settings/settings_stores.dart';
import 'package:apexo/features/doctors/doctors_store.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  final List<IconData> _icons = const [
    FluentIcons.calendar_day,
    FluentIcons.calendar_week,
    FluentIcons.calendar,
    FluentIcons.calendar_agenda,
    FluentIcons.calendar_year,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _buildHeader(context),
      ChartsRangeSelector(
          color: FluentTheme.of(context).inactiveColor.withValues(alpha: 0.5),
          textStyle: _textStyle.copyWith(color: FluentTheme.of(context).inactiveColor.withValues(alpha: 0.5)),
          icons: _icons),
      const Divider(size: 1500),
      Expanded(
        child: ListView(
          scrollDirection: Axis.vertical,
          children: [
            MStreamBuilder(
                streams: [
                  chartsCtrl.start.stream,
                  chartsCtrl.end.stream,
                  chartsCtrl.interval.stream,
                  chartsCtrl.doctorID.stream
                ],
                builder: (context, snapshot) {
                  return Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSingleChart(
                        "${txt("appointmentsPer")} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        "${txt("total")}: ${chartsCtrl.filteredAppointments.length} ${txt("appointments")} ${txt("in_Duration_")} ${chartsCtrl.periods.length} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        StyledBarChart(
                          labels: chartsCtrl.periods.map((p) => p.label).toList(),
                          yAxis: chartsCtrl.groupedAppointments.map((g) => g.length.toDouble()).toList(),
                        ),
                        FluentIcons.date_time,
                      ),
                      _buildSingleChart(
                        "${txt("paymentsAndExpensesPer")} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        "${txt("total")}: ${chartsCtrl.groupedPayments.reduce((v, e) => v += e)} ${globalSettings.get("currency_______").value} ${txt("in_Duration_")} ${chartsCtrl.periods.length} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        StyledLineChart(
                          labels: chartsCtrl.periods.map((p) => p.label).toList(),
                          datasets: [chartsCtrl.groupedPayments.toList(), chartsCtrl.groupedExpenses.toList()],
                          datasetLabels: [
                            "${txt("payments")} ${globalSettings.get("currency_______").value}",
                            "${txt("expenses")} ${globalSettings.get("currency_______").value}"
                          ],
                        ),
                        FluentIcons.currency,
                      ),
                      _buildSingleChart(
                        "${txt("newPatientsPer")} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        "${txt("acquiredPatientsIn")} ${chartsCtrl.periods.length} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        StyledLineChart(
                          labels: chartsCtrl.periods.map((p) => p.label).toList(),
                          datasets: [chartsCtrl.newPatients.toList()],
                          datasetLabels: [txt("patients")],
                        ),
                        FluentIcons.people,
                      ),
                      _buildSingleChart(
                        "${txt("doneMissedPer")} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        "${txt("doneAndMissedAppointmentsIn")} ${chartsCtrl.periods.length} ${txt(chartsCtrl.intervalString.toLowerCase())}",
                        StyledStackedChart(
                          labels: chartsCtrl.periods.map((p) => p.label).toList(),
                          datasets: chartsCtrl.doneAndMissedAppointments,
                          datasetLabels: [txt("done"), txt("all")],
                        ),
                        FluentIcons.check_list,
                      ),
                      _buildSingleChart(
                        txt("timeOfDay"),
                        txt("distributionOfAppointments"),
                        StyledRadarChart(
                          data: [chartsCtrl.timeOfDayDistribution],
                          labels: List.generate(
                              24, (index) => DateFormat("hh a", locale.s.$code).format(DateTime(0, 0, 0, index))),
                        ),
                        FluentIcons.clock,
                      ),
                      _buildSingleChart(
                        txt("dayOfWeek"),
                        txt("distributionOfAppointments"),
                        StyledRadarChart(
                          data: [chartsCtrl.dayOfWeekDistribution],
                          labels: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                              .map((e) => txt(e))
                              .toList(),
                        ),
                        FluentIcons.calendar_day,
                      ),
                      _buildSingleChart(
                        txt("dayOfMonth"),
                        txt("distributionOfAppointments"),
                        StyledRadarChart(
                            data: [chartsCtrl.dayOfMonthDistribution],
                            labels: List.generate(31, (index) => (index + 1).toString())),
                        FluentIcons.calendar_day,
                      ),
                      _buildSingleChart(
                        txt("monthOfYear"),
                        txt("distributionOfAppointments"),
                        StyledRadarChart(
                          data: [chartsCtrl.monthOfYearDistribution],
                          labels: const [
                            "January",
                            "February",
                            "March",
                            "April",
                            "May",
                            "June",
                            "July",
                            "August",
                            "September",
                            "October",
                            "November",
                            "December"
                          ].map((e) => txt(e)).toList(),
                        ),
                        FluentIcons.calendar_year,
                      ),
                      _buildSingleChart(
                        txt("patientsGender"),
                        txt("maleAndFemalePatients"),
                        StyledPie(data: {
                          txt("female"): chartsCtrl.femaleMale[0].toDouble(),
                          txt("male"): chartsCtrl.femaleMale[1].toDouble(),
                        }),
                        FluentIcons.people_external_share,
                      ),
                    ],
                  );
                })
          ],
        ),
      ),
    ]);
  }

  SizedBox _buildSingleChart(String title, String subtitle, Widget chart, [IconData icon = FluentIcons.chart]) {
    return SizedBox(
      width: 600,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Acrylic(
          blurAmount: 20,
          elevation: 10,
          luminosityAlpha: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            color: Colors.white.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 10, 7),
                  child: Row(
                    children: [
                      Icon(icon),
                      const SizedBox(width: 10),
                      const Divider(size: 20, direction: Axis.vertical),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Txt(
                            title,
                            style: TextStyle(fontSize: 15, color: Colors.grey.withValues(alpha: 0.7)),
                          ),
                          Txt(
                            subtitle,
                            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(size: 600),
                SizedBox(
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: chart,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Acrylic _buildHeader(BuildContext context) {
    return Acrylic(
      elevation: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPickRangeButton(context),
            _buildFarItems(),
          ],
        ),
      ),
    );
  }

  Row _buildFarItems() {
    return Row(
      children: [
        _buildMemberFilter(),
        const SizedBox(width: 5),
      ],
    );
  }

  Widget _buildMemberFilter() {
    return StreamBuilder(
        stream: chartsCtrl.doctorID.stream,
        builder: (context, snapshot) {
          return ComboBox<String>(
            style: const TextStyle(overflow: TextOverflow.ellipsis),
            items: [
              ComboBoxItem<String>(
                value: "",
                child: Txt(txt("allDoctors")),
              ),
              ...doctors.present.values.map((e) {
                var doctorName = e.title;
                if (doctorName.length > 20) {
                  doctorName = "${doctorName.substring(0, 17)}...";
                }
                return ComboBoxItem(value: e.id, child: Txt(doctorName));
              }),
            ],
            onChanged: chartsCtrl.filterByDoctor,
            value: chartsCtrl.doctorID(),
          );
        });
  }

  IconButton _buildPickRangeButton(BuildContext context) {
    return IconButton(
      icon: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(
            FluentIcons.public_calendar,
            size: 17,
          ),
          const SizedBox(width: 5),
          Txt(txt("pickRange"))
        ],
      ),
      onPressed: () => chartsCtrl.rangePicker(context),
    );
  }

  TextStyle get _textStyle => TextStyle(
        color: _color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  Color get _color => Colors.grey.withValues(alpha: 0.5);
}
