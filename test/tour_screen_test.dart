import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/screens/tour_screen.dart';
import 'package:restaurant_tracker/widgets/tap_rating_bar.dart';
import 'package:restaurant_tracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tour advances with Next and dismisses with Let\'s eat',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => TourScreen.show(context),
              child: const Text('open tour'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open tour'));
    await tester.pumpAndSettle();
    expect(find.byType(TourScreen), findsOneWidget);

    // Tap Next until the last page.
    var guard = 0;
    while (find.text('Next').evaluate().isNotEmpty && guard < 12) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      guard++;
    }
    expect(guard < 12, true, reason: 'Next never reached the last page');

    // Last page: the finish button must dismiss the tour.
    final finish = find.textContaining('Let\'s eat');
    expect(finish, findsOneWidget);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.byType(TourScreen), findsNothing);
  });

  testWidgets('Skip dismisses the tour from page one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => TourScreen.show(context),
              child: const Text('open tour'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open tour'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(TourScreen), findsNothing);
  });

  testWidgets('demo rating bar takes taps and drags without page flips',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => TourScreen.show(context),
              child: const Text('open tour'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open tour'));
    await tester.pumpAndSettle();

    // Demo starts at 7. The tappable segments are the bottom strip of the
    // TapRatingBar — tap the far right to hit 10.
    expect(find.text('7'), findsOneWidget);
    final rect = tester.getRect(find.byType(TapRatingBar));
    await tester.tapAt(Offset(rect.right - 6, rect.bottom - 10));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);

    // Drag leftwards across the segments: the value should drop and the
    // PageView must NOT flip to page 2 (still shows "1 / 5").
    await tester.timedDragFrom(
      Offset(rect.right - 6, rect.bottom - 10),
      Offset(-(rect.width * 0.8), 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(find.text('10'), findsNothing);
    expect(find.text('1 / 5'), findsOneWidget);
  });
}
