import 'package:flutter/material.dart';

import '../models/cadet.dart';
import '../services/api_service.dart';
import 'face_capture_screen.dart';
import 'summary_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<List<Cadet>> _future;
  List<Cadet> _cadets = [];
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _future = api.fetchCadets();
  }

  void _markAll(AttendanceStatus s) {
    setState(() {
      for (final c in _cadets) {
        c.status = s;
      }
    });
  }

  Future<void> _openFaceCapture() async {
    if (_cadets.isEmpty) return;
    final ids = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute(builder: (_) => FaceCaptureScreen(cadets: _cadets)),
    );
    if (ids == null || ids.isEmpty) return;
    setState(() {
      for (final c in _cadets) {
        if (ids.contains(c.id)) c.status = AttendanceStatus.present;
      }
    });
  }

  Future<void> _submit() async {
    // paradeId is optional: pass a real Parade UUID (from POST /api/parades) to update its totals.
    await api.submitAttendance(_cadets);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryScreen(cadets: _cadets, date: _date),
      ),
    );
  }

  Color _color(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => Colors.green,
        AttendanceStatus.absent => Colors.red,
        AttendanceStatus.late => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parade ${_date.day}/${_date.month}/${_date.year}'),
        actions: [
          IconButton(
            tooltip: 'Face attendance',
            icon: const Icon(Icons.face),
            onPressed: _openFaceCapture,
          ),
          IconButton(
            tooltip: 'Mark all present',
            icon: const Icon(Icons.done_all),
            onPressed: () => _markAll(AttendanceStatus.present),
          ),
        ],
      ),
      body: FutureBuilder<List<Cadet>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_cadets.isEmpty) _cadets = snap.data!;
          return ListView.separated(
            itemCount: _cadets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = _cadets[i];
              return ListTile(
                leading: CircleAvatar(child: Text(c.name[0])),
                title: Text(c.name),
                subtitle: Text(c.rollNo),
                trailing: SegmentedButton<AttendanceStatus>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: AttendanceStatus.present, label: Text('P')),
                    ButtonSegment(value: AttendanceStatus.absent, label: Text('A')),
                    ButtonSegment(value: AttendanceStatus.late, label: Text('L')),
                  ],
                  selected: {c.status},
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(_color(c.status)),
                  ),
                  onSelectionChanged: (s) => setState(() => c.status = s.first),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submit,
        icon: const Icon(Icons.send),
        label: const Text('Submit'),
      ),
    );
  }
}
