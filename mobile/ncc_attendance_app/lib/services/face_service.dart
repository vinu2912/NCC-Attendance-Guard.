import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the Python face recognition service (`face-recognition/`).
class FaceService {
  // Android emulator -> host machine. Change to your PC's LAN IP for a real phone.
  static const String baseUrl = 'http://10.0.2.2:8000';

  /// Sends one photo (single cadet or whole platoon) and returns the
  /// cadet IDs the service recognised with high confidence.
  Future<FaceResult> recognize(List<int> imageBytes, {List<String>? cadetIds}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/recognize'))
      ..files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: 'capture.jpg'));
    if (cadetIds != null && cadetIds.isNotEmpty) {
      req.fields['cadet_ids'] = cadetIds.join(',');
    }
    final res = await http.Response.fromStream(
      await req.send().timeout(const Duration(seconds: 30)),
    );
    if (res.statusCode != 200) {
      throw Exception('Face service error ${res.statusCode}: ${res.body}');
    }
    return FaceResult.fromJson(jsonDecode(res.body));
  }
}

class FaceResult {
  final int facesDetected;
  final List<String> recognizedIds;
  final int unknown;
  final int rejected;

  FaceResult({
    required this.facesDetected,
    required this.recognizedIds,
    required this.unknown,
    required this.rejected,
  });

  factory FaceResult.fromJson(Map<String, dynamic> j) {
    final faces = (j['faces'] as List).cast<Map<String, dynamic>>();
    return FaceResult(
      facesDetected: j['faces_detected'],
      recognizedIds: (j['recognized_cadet_ids'] as List).map((e) => e.toString()).toList(),
      unknown: faces.where((f) => f['status'] == 'unknown').length,
      rejected: faces.where((f) => f['status'] == 'rejected').length,
    );
  }
}

final faceService = FaceService();
