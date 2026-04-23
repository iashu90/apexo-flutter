import 'package:flutter/material.dart';

import 'app_card.dart';

class TopWidgetSmallCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final Color cardColor;
  final Color borderColor;
  final Color titleColor;
  final double width;

  const TopWidgetSmallCard({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
    this.cardColor = Colors.white,
    this.borderColor = const Color(0xFFD7E3F0),
    this.titleColor = const Color(0xFF5A7397),
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        backgroundColor: cardColor,
        borderColor: borderColor,
        child: SizedBox(
          height: 66,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopWidgetMediumCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color valueColor;
  final double width;

  const TopWidgetMediumCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    this.valueColor = const Color(0xFF1D3E67),
    this.width = 176,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 98,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF3C5E87),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: value.length > 12 ? 22 : 28,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B778C),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopWidgetLargeCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;
  final Widget? badge;
  final Widget? footer;
  final VoidCallback? onTap;
  final double minWidth;
  final double maxWidth;

  const TopWidgetLargeCard({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
    this.badge,
    this.footer,
    this.onTap,
    this.minWidth = 180,
    this.maxWidth = 220,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: SizedBox(
          height: 168,
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF496489),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge != null) badge!,
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 30,
                    color: valueColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (footer != null) footer!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
