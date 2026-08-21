import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horn/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeMode = await ThemePreference.load();
  runApp(MyApp(initialThemeMode: themeMode));
}

class ThemePreference {
  static const _key = 'theme_mode';

  static Future<ThemeMode> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedMode = preferences.getString(_key);
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      return ThemeMode.system;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key, mode.name);
    } catch (_) {
      // A storage failure should not prevent changing the active theme.
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialThemeMode = ThemeMode.system});

  final ThemeMode initialThemeMode;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;

  void _setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
    unawaited(ThemePreference.save(mode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Horn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: HomePage(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _offset = 10.0;
  static const _pulserOffset = 5.0;
  static const _holdThreshold = Duration(milliseconds: 500);
  static const _holdToastCooldown = Duration(seconds: 2);

  var animationValue = _offset;
  Timer? _ticker;
  Timer? _holdTimer;
  Timer? _holdToastCooldownTimer;
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
    _holdToastCooldownTimer?.cancel();
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
      final showToast = _holdToastCooldownTimer == null;
      if (showToast) {
        _holdToastCooldownTimer = Timer(_holdToastCooldown, () {
          _holdToastCooldownTimer = null;
        });
      }
      unawaited(HoldNudge.show(showToast: showToast));
    } else {
      unawaited(HornVibrator.end());
    }

    setState(() {
      animationValue = _offset;
    });
  }

  Future<void> _showThemeSettings() async {
    Navigator.pop(context);
    final selectedMode = await showDialog<ThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Choose theme'),
        children: ThemeMode.values.map((mode) {
          final selected = widget.themeMode == mode;
          return SimpleDialogOption(
            key: Key('theme-${mode.name}'),
            onPressed: () => Navigator.pop(dialogContext, mode),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_themeIcon(mode)),
              title: Text(_themeLabel(mode)),
              trailing: selected ? const Icon(Icons.check) : null,
            ),
          );
        }).toList(),
      ),
    );

    if (selectedMode != null) {
      widget.onThemeModeChanged(selectedMode);
    }
  }

  void _showAbout() {
    Navigator.pop(context);
    showAboutDialog(
      context: context,
      applicationName: 'Air Horn',
      applicationIcon: Image.asset('assets/icon.png', width: 56, height: 56),
      children: const [
        Text('A pocket air horn. Press and hold the button to sound it.'),
      ],
    );
  }

  Future<void> _openStoreListing() async {
    Navigator.pop(context);
    const appId = 'dev.thecodepapaya.horn';
    final openedApp = await _launchExternal(
      Uri.parse('market://details?id=$appId'),
    );
    final opened = openedApp ||
        await _launchExternal(
          Uri.https('play.google.com', '/store/apps/details', {'id': appId}),
        );

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the store listing.')),
      );
    }
  }

  static Future<bool> _launchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System default',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_outlined,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Air Horn')),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/icon.png', width: 72, height: 72),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Air Horn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme'),
                subtitle: Text(_themeLabel(widget.themeMode)),
                onTap: _showThemeSettings,
              ),
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('Rate Air Horn'),
                onTap: _openStoreListing,
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About'),
                onTap: _showAbout,
              ),
            ],
          ),
        ),
      ),
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF8F2525)
                            : Colors.black,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/icon.png',
                      key: const Key('horn-image'),
                    ),
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
