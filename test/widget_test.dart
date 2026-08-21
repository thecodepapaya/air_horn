import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horn/main.dart';

void main() {
  testWidgets('renders the air horn control', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byKey(const Key('horn-button')), findsOneWidget);

    final image = tester.widget<Image>(find.byKey(const Key('horn-image')));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/icon.png');
  });

  testWidgets('drawer exposes theme, rate, and about actions', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Rate Air Horn'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
  });

  testWidgets('theme setting switches to dark mode', (tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('horn shadow remains visible in dark mode', (tester) async {
    await tester.pumpWidget(
      const MyApp(initialThemeMode: ThemeMode.dark),
    );

    final button = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('horn-button')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = button.decoration! as BoxDecoration;

    expect(decoration.boxShadow!.single.color, const Color(0xFF8F2525));
  });

  testWidgets('pending pulse does not update after disposal', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Durations.medium1);
  });

  testWidgets('quick tap shows the hold hint', (tester) async {
    final toastCalls = <MethodCall>[];
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async {
        toastCalls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        null,
      ),
    );

    await tester.pumpWidget(const MyApp());
    final center = tester.getCenter(find.byKey(const Key('horn-button')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(
      toastCalls.where(
        (call) =>
            call.method == 'showToast' &&
            (call.arguments as Map<Object?, Object?>)['msg'] ==
                'Press and hold the button to keep the horn sounding.',
      ),
      hasLength(1),
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('repeated quick taps debounce the hold hint toast',
      (tester) async {
    final toastCalls = <MethodCall>[];
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async {
        toastCalls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        null,
      ),
    );

    await tester.pumpWidget(const MyApp());
    final center = tester.getCenter(find.byKey(const Key('horn-button')));

    Future<void> quickTap() async {
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
    }

    await quickTap();
    await quickTap();

    Iterable<MethodCall> holdHintCalls() => toastCalls.where(
          (call) =>
              call.method == 'showToast' &&
              (call.arguments as Map<Object?, Object?>)['msg'] ==
                  'Press and hold the button to keep the horn sounding.',
        );

    expect(holdHintCalls(), hasLength(1));

    await tester.pump(const Duration(seconds: 2));
    await quickTap();

    expect(holdHintCalls(), hasLength(2));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('holding the button does not show the hint', (tester) async {
    final toastCalls = <MethodCall>[];
    const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      toastChannel,
      (call) async {
        toastCalls.add(call);
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        toastChannel,
        null,
      ),
    );

    await tester.pumpWidget(const MyApp());
    final center = tester.getCenter(find.byKey(const Key('horn-button')));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(toastCalls.where((call) => call.method == 'showToast'), isEmpty);
  });
}
