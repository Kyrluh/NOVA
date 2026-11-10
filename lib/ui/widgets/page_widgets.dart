import 'package:flutter/material.dart';

import '../theme.dart';

class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w600,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 8),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: novaMuted)),
    ],
  );
}

class NovaNotice extends StatelessWidget {
  const NovaNotice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF191D28),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: novaMuted, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, height: 1.6, color: novaMuted),
          ),
        ),
      ],
    ),
  );
}

String rateLabel(double rate) =>
    '${rate.toString().replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',')}×';
