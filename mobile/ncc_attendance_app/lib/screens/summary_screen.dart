import 'package:flutter/material.dart';

import '../models/cadet.dart';

class SummaryScreen extends StatelessWidget {
  final List<Cadet> cadets;
  final DateTime date;

  const SummaryScreen({super.key, required this.cadets, required this.date});

  int _count(AttendanceStatus s) => cadets.where((c) => c.status == s).length;

  @override
  Widget build(BuildContext context) {
    final total = cadets.length;
    final present = _count(AttendanceStatus.present);
    final pct = total == 0 ? 0 : (present * 100 / total).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Summary')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${date.day}/${date.month}/${date.year}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _row('Total cadets', total, Colors.blueGrey),
            _row('Present', present, Colors.green),
            _row('Absent', _count(AttendanceStatus.absent), Colors.red),
            _row('Late', _count(AttendanceStatus.late), Colors.orange),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: total == 0 ? 0 : present / total,
              minHeight: 10,
            ),
            const SizedBox(height: 8),
            Text('$pct% attendance'),
            const Spacer(),
            const Center(child: Text('Attendance submitted')),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value, Color color) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.circle, color: color, size: 14),
        title: Text(label),
        trailing: Text('$value',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
}
