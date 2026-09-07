import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tktsapp_scanner/main.dart';
import 'package:tktsapp_scanner/src/core/api_client.dart';
import 'package:tktsapp_scanner/src/core/staff_session.dart';

class EmptyScannerApi extends ApiClient {
  @override
  Future<Map<String, dynamic>> get(String path) async => {'data': []};
}

void main() {
  testWidgets('Scan page opens without events or stations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScannerPage(
            api: EmptyScannerApi(),
            session: const StaffSession('test', {'role': 'organizer'}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('scanner-settings')), findsOneWidget);
    expect(find.text('Set up your scanner'), findsOneWidget);
    expect(find.text('Open full-screen camera'), findsOneWidget);
  });
}
