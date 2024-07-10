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

class _HomePageState extends State<HomePage> {
  static const _offset = 10.0;
  static const _pulserOffset = 5.0;

  var animationValue = _offset;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    Player.init();
    _restartPulser();
  }

  void _restartPulser() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 3), (timer) async {
      setState(() {
        animationValue -= _pulserOffset;
      });
      await Future.delayed(Durations.medium1);
      setState(() {
        animationValue += _pulserOffset;
      });
    });
  }

  void _pausePulser() {
    _ticker?.cancel();
  }

  @override
  void dispose() {
    super.dispose();

    _ticker?.cancel();
  }

  void _begin() {
    Player.play();
    HornVibrator.start();

    setState(() {
      animationValue = 0;
    });
  }

  void _end() {
    Player.onEnd();
    _restartPulser();
    HornVibrator.end();

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
          child: GestureDetector(
            onTapDown: (details) {
              _begin();
            },
            onTapUp: (details) {
              _end();
            },
            onTapCancel: () {
              _end();
            },
            onLongPress: () {
              _begin();
              _pausePulser();
            },
            onLongPressEnd: (details) {
              _end();
            },
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
