/// Matches the `status` ENUM in app/backend/models/Attendance.js.
enum AttendanceStatus { present, absent, late }

/// Mirrors the backend `Student` model (app/backend/models/Student.js).
class Cadet {
  final String id;          // Student.id (UUID) – also used as the face-recognition cadet_id
  final String name;        // firstName + lastName
  final String rollNo;      // Student.roll
  final String instituteCode;
  AttendanceStatus status;

  Cadet({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.instituteCode,
    this.status = AttendanceStatus.absent,
  });

  factory Cadet.fromJson(Map<String, dynamic> json) => Cadet(
        id: json['id'].toString(),
        name: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
        rollNo: json['roll'] ?? '',
        instituteCode: json['instituteCode'] ?? '',
      );

  /// One item of `attendanceRecords` for POST /api/attendance/mark.
  Map<String, dynamic> toAttendanceRecord(String markedBy) => {
        'studentId': id,
        'roll': rollNo,
        'instituteCode': instituteCode,
        'status': status.name,
        'markedBy': markedBy,
        'paradeType': 'regular',
      };
}
