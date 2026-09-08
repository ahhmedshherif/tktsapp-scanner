import 'package:flutter_test/flutter_test.dart';
import 'package:tktsapp_scanner/src/core/staff_session.dart';

void main() {
  test('scanner staff is restricted to scanning', () {
    const session = StaffSession('token', {
      'role': 'organizer',
      'staff_role': 'scanner',
    });

    expect(session.canScan, isTrue);
    expect(session.canSeeAnalytics, isFalse);
    expect(session.canManageTeam, isFalse);
  });

  test('organizer owner may manage their team and scan', () {
    const session = StaffSession('token', {
      'role': 'organizer',
      'staff_role': null,
    });

    expect(session.canScan, isTrue);
    expect(session.canManageTeam, isTrue);
  });
}
