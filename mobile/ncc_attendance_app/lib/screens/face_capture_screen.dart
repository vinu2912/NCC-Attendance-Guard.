import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cadet.dart';
import '../services/face_service.dart';

/// Take a photo (one cadet or a group). Recognised cadets are shown for the
/// staff member to confirm, and confirmed cadets are returned to be marked present.
class FaceCaptureScreen extends StatefulWidget {
  final List<Cadet> cadets;
  const FaceCaptureScreen({super.key, required this.cadets});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final _picker = ImagePicker();
  Uint8List? _photo;
  FaceResult? _result;
  final Set<String> _confirmed = {};
  bool _busy = false;
  String? _error;

  Future<void> _capture(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1920, // keep enough detail for faces at the back of a group
      imageQuality: 92,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _photo = bytes;
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await faceService.recognize(
        bytes,
        cadetIds: widget.cadets.map((c) => c.id).toList(),
      );
      setState(() {
        _result = r;
        _confirmed
          ..clear()
          ..addAll(r.recognizedIds);
      });
    } catch (e) {
      setState(() => _error = 'Could not reach face service.\n$e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matched =
        widget.cadets.where((c) => _result?.recognizedIds.contains(c.id) ?? false).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Face Attendance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photo == null
                  ? const Center(child: Icon(Icons.face_retouching_natural, size: 80))
                  : Image.memory(_photo!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tips: good light, faces looking at the camera, no caps or masks covering the face.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _capture(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _capture(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          if (_busy) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          if (_result != null) ...[
            Text(
              '${_result!.facesDetected} faces · ${matched.length} recognised · '
              '${_result!.unknown} unknown · ${_result!.rejected} unclear',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...matched.map((c) => CheckboxListTile(
                  value: _confirmed.contains(c.id),
                  title: Text(c.name),
                  subtitle: Text(c.rollNo),
                  onChanged: (v) => setState(
                      () => v! ? _confirmed.add(c.id) : _confirmed.remove(c.id)),
                )),
            if (_result!.unknown + _result!.rejected > 0)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Some faces could not be identified. Retake the photo or mark them manually.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _confirmed.isEmpty ? null : () => Navigator.pop(context, _confirmed),
            child: Text('Mark ${_confirmed.length} present'),
          ),
        ),
      ),
    );
  }
}
