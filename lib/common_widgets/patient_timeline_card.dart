import 'package:apexo/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PatientTimelineCard extends StatefulWidget {
  final List<TimelineItem> items;
  final int collapsedVisibleCount;
  final String viewMoreLabel;
  final String showLessLabel;

  const PatientTimelineCard({
    super.key,
    this.items = const [],
    this.collapsedVisibleCount = 4,
    this.viewMoreLabel = 'View More History',
    this.showLessLabel = 'Show Less',
  });

  @override
  State<PatientTimelineCard> createState() => _PatientTimelineCardState();
}

class _PatientTimelineCardState extends State<PatientTimelineCard> {
  bool expanded = false;

  List<TimelineItem> get _resolvedItems {
    if (widget.items.isNotEmpty) {
      return widget.items;
    }
    return [
      TimelineItem.today(),
      TimelineItem.followUp(),
      TimelineItem.procedure(),
      TimelineItem.impression(),
      TimelineItem.irrigation(),
      TimelineItem.calculus(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _resolvedItems;
    final canExpand = items.length > widget.collapsedVisibleCount;
    final visibleItems = expanded || !canExpand
        ? items
        : items.take(widget.collapsedVisibleCount).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _TimelineColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _TimelineColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < visibleItems.length; i++) ...[
            visibleItems[i].copyWith(
              showConnector: i != visibleItems.length - 1,
            ),
            if (i != visibleItems.length - 1) const SizedBox(height: 16),
          ],
          if (canExpand) ...[
            const SizedBox(height: 10),
            ViewMoreButton(
              expanded: expanded,
              viewMoreLabel: widget.viewMoreLabel,
              showLessLabel: widget.showLessLabel,
              onTap: () => setState(() => expanded = !expanded),
            ),
          ],
        ],
      ),
    );
  }
}

class TimelineItem extends StatelessWidget {
  final String title;
  final String date;
  final String time;
  final Color color;
  final bool isToday;
  final String doctor;
  final String visitType;
  final String? notes;
  final List<String>? teeth;
  final bool showStatus;
  final bool showConnector;
  final String statusText;
  final IconData icon;

  const TimelineItem({
    super.key,
    required this.title,
    required this.date,
    required this.time,
    required this.color,
    required this.doctor,
    required this.visitType,
    this.notes,
    this.teeth,
    this.isToday = false,
    this.showStatus = false,
    this.showConnector = true,
    this.statusText = 'In Progress',
    this.icon = Icons.medical_services,
  });

  factory TimelineItem.today() => const TimelineItem(
        title: 'Current Visit - Consultation',
        date: '21 Apr 2026',
        time: '10:00 AM',
        color: _TimelineColors.accentPurple,
        doctor: 'Unassigned',
        visitType: 'Follow-up Visit',
        isToday: true,
        showStatus: true,
      );

  factory TimelineItem.followUp() => const TimelineItem(
        title: 'Follow-up Check',
        date: '18 Apr 2026',
        time: '02:44 PM',
        color: _TimelineColors.accentOrange,
        doctor: 'Amudhan',
        visitType: 'Follow-up Visit',
        notes: 'Healing satisfactory. Continue oral hygiene.',
      );

  factory TimelineItem.procedure() => const TimelineItem(
        title: 'RPD Delivery',
        date: '12 Apr 2026',
        time: '07:09 AM',
        color: _TimelineColors.accentBlue,
        doctor: 'Karmugilan',
        visitType: 'Procedure',
        teeth: ['11', '12'],
      );

  factory TimelineItem.impression() => const TimelineItem(
        title: 'Impression Taken',
        date: '08 Jan 2026',
        time: '10:45 PM',
        color: _TimelineColors.accentPurple,
        doctor: 'Karmugilan',
        visitType: 'Procedure',
        teeth: ['11', '12'],
      );

  factory TimelineItem.irrigation() => const TimelineItem(
        title: 'Saline Irrigation',
        date: '30 Nov 2025',
        time: '10:45 PM',
        color: _TimelineColors.accentBlue,
        doctor: 'Karmugilan',
        visitType: 'Procedure',
      );

  factory TimelineItem.calculus() => const TimelineItem(
        title: 'Calculus Removal',
        date: '24 Nov 2025',
        time: '09:57 PM',
        color: _TimelineColors.accentGreen,
        doctor: 'Insyirah',
        visitType: 'Procedure',
        teeth: ['25'],
      );

  TimelineItem copyWith({
    bool? showConnector,
  }) {
    return TimelineItem(
      key: key,
      title: title,
      date: date,
      time: time,
      color: color,
      doctor: doctor,
      visitType: visitType,
      notes: notes,
      teeth: teeth,
      isToday: isToday,
      showStatus: showStatus,
      showConnector: showConnector ?? this.showConnector,
      statusText: statusText,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _timelineIndicator(),
        const SizedBox(width: 16),
        Expanded(child: _card()),
      ],
    );
  }

  Widget _timelineIndicator() {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(
            date,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: _TimelineColors.textPrimary,
            ),
          ),
          Text(
            time,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TimelineColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          if (showConnector)
            const VerticalTimelineLine(
              height: 72,
            ),
        ],
      ),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isToday ? _TimelineColors.todayBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? _TimelineColors.primary : _TimelineColors.border,
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _TimelineColors.textPrimary,
                  ),
                ),
              ),
              if (showStatus)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: _TimelineColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Doctor: $doctor',
            style: const TextStyle(color: _TimelineColors.textSecondary),
          ),
          const SizedBox(height: 6),
          _chip('Visit Type: $visitType'),
          if (notes != null) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: $notes',
              style: const TextStyle(color: _TimelineColors.textSecondary),
            ),
          ],
          if (teeth != null && teeth!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teeth!.map((t) => _chip(t)).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: _TimelineColors.textPrimary,
        ),
      ),
    );
  }
}

class VerticalTimelineLine extends StatelessWidget {
  final double height;
  final Color color;

  const VerticalTimelineLine({
    super.key,
    this.height = 60,
    this.color = _TimelineColors.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: height,
      color: color,
      margin: const EdgeInsets.only(top: 4),
    );
  }
}

class ViewMoreButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final String viewMoreLabel;
  final String showLessLabel;

  const ViewMoreButton({
    super.key,
    required this.expanded,
    required this.onTap,
    this.viewMoreLabel = 'View More History',
    this.showLessLabel = 'Show Less',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _TimelineColors.border),
        ),
        child: Center(
          child: Text(
            expanded ? showLessLabel : viewMoreLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: _TimelineColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineColors {
  static const primary = AppColors.primary500;
  static const accentPurple = Color(0xFF7C6CF6);
  static const accentOrange = Color(0xFFF59E0B);
  static const accentBlue = Color(0xFF60A5FA);
  static const accentGreen = Color(0xFF34D399);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const surface = Colors.white;
  static const todayBg = Color(0xFFF1F5FF);
}
