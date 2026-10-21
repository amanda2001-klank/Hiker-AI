import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_venture_flutter/features/hiking/presentation/live_monitoring_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets(
    'LiveMonitoringScreen Dashboard Renders Correctly with Risk Panels',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LiveMonitoringScreen())),
      );
      await tester.pumpAndSettle();

      // Verify dashboard title and main sections
      expect(find.text('Live Fitness & Hike Monitoring'), findsOneWidget);
      expect(find.text('Live Sensor Telemetry'), findsOneWidget);

      // Scroll down to find risk indicators and recommendations
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Physiological Risk Indicators'), findsOneWidget);
      expect(find.text('Model not connected'), findsNWidgets(3));
    },
  );

  testWidgets('LiveMonitoringScreen End Hike Confirmation Dialog Test', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LiveMonitoringScreen())),
    );
    await tester.pumpAndSettle();

    // Scroll down to End Hike button
    await tester.scrollUntilVisible(
      find.text('End Hike'),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Hike'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.text('End Hiking Session?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Finish Hike'), findsOneWidget);
  });
}
