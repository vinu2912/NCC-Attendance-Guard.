import 'package:flutter_test/flutter_test.dart';
import 'package:ncc_attendance_app/main.dart';

void main() {
  testWidgets('Login screen shows title', (tester) async {
    await tester.pumpWidget(const NccAttendanceApp());
    expect(find.text('NCC Attendance'), findsOneWidget);
  });
}
