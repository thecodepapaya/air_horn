import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horn/utils.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Horn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _offset = 10.0;
  static const _pulserOffset = 5.0;
  static const _holdThreshold = Duration(milliseconds: 500);

  var animationValue = _offset;
  Timer? _ticker;
  Timer? _holdTimer;
  var _pulserGeneration = 0;
  int? _activePointer;
  var _heldLongEnough = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(Player.prepare());
    _restartPulser();
  }

  void _restartPulser() {
    _ticker?.cancel();
    final generation = ++_pulserGeneration;
    _ticker = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || generation != _pulserGeneration) {
        return;
      }
      setState(() {
        animationValue -= _pulserOffset;
      });
      await Future.delayed(Durations.medium1);
      if (!mounted || generation != _pulserGeneration) {
        return;
      }
      setState(() {
        animationValue += _pulserOffset;
      });
    });
  }

  void _pausePulser() {
    _ticker?.cancel();
    _pulserGeneration++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restartPulser();
      return;
    }

    _activePointer = null;
    _holdTimer?.cancel();
    _pausePulser();
    unawaited(Player.onEnd());
    unawaited(HornVibrator.end());

    if (mounted) {
      setState(() {
        animationValue = _offset;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _holdTimer?.cancel();
    _pausePulser();
    unawaited(Player.onEnd());
    unawaited(HornVibrator.end());
    super.dispose();
  }

  void _begin() {
    _pausePulser();
    unawaited(VolumeNudge.showIfMuted());
    unawaited(Player.play());
    unawaited(HornVibrator.start());

    setState(() {
      animationValue = 0;
    });
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }

    _activePointer = event.pointer;
    _heldLongEnough = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdThreshold, () {
      _heldLongEnough = true;
    });
    _begin();
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }

    _holdTimer?.cancel();
    _activePointer = null;
    final wasQuickTap = !_heldLongEnough;
    _end(showHoldNudge: wasQuickTap);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }

    _holdTimer?.cancel();
    _activePointer = null;
    _end();
  }

  void _end({bool showHoldNudge = false}) {
    unawaited(Player.onEnd());
    _restartPulser();
    if (showHoldNudge) {
      unawaited(HoldNudge.show());
    } else {
      unawaited(HornVibrator.end());
    }

    setState(() {
      animationValue = _offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(left: _offset * 2),
        child: Center(
          child: Listener(
            key: const Key('horn-button'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: Stack(
              children: [
                AnimatedContainer(
                  margin: EdgeInsets.only(
                    top: (_offset - animationValue) * 2,
                    right: (_offset - animationValue) * 2,
                  ),
                  duration: Durations.short2,
                  height: 150,
                  width: 150,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(-animationValue, animationValue),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset('assets/icon.png'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
