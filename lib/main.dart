import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'features/shell/home_shell.dart';
import 'core/save_service.dart';
import 'features/tutorial/tutorial_overlay.dart';
// Hive is re-exported by hive_flutter; direct hive import unnecessary

void main() async {
  // Keep initialization and runApp in the same zone to avoid zone mismatch.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Global error handlers to surface crashes
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      // ignore: avoid_print
      print('FlutterError: ${details.exceptionAsString()}');
      // ignore: avoid_print
      if (details.stack != null) print(details.stack);
    };
    // Catch unhandled async errors outside Flutter framework
    WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
      // ignore: avoid_print
      print('PlatformDispatcher error: $error');
      // ignore: avoid_print
      print(stack);
      return true; // handled
    };

  // Use an app-specific subdirectory to avoid global file locks in Documents
  await Hive.initFlutter('ProcDealer');
    await SaveService.init();
    runApp(ProviderScope(observers: const [AppProviderObserver()], child: const ProcDealerApp()));
  }, (error, stack) async {
    // ignore: avoid_print
    print('runZonedGuarded error: $error');
    // ignore: avoid_print
    print(stack);
  });
}

class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(ProviderBase provider, Object error, StackTrace stackTrace, ProviderContainer container) {
    // ignore: avoid_print
    print('Provider error from ${provider.name ?? provider.runtimeType}: $error');
    // ignore: avoid_print
    print(stackTrace);
  }

  @override
  void didAddProvider(ProviderBase provider, Object? value, ProviderContainer container) {
    // no-op (could log if needed)
  }

  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container) {
    // no-op to avoid log noise
  }

  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    // no-op
  }
}

class ProcDealerApp extends StatefulWidget {
  const ProcDealerApp({Key? key}) : super(key: key);
  @override
  State<ProcDealerApp> createState() => _ProcDealerAppState();
}

class _ProcDealerAppState extends State<ProcDealerApp> {
  bool _showTutorial = true;
  Timer? _hb;
  @override
  void initState() {
    super.initState();
    // Check if tutorial should be shown (first run)
    try {
      final seen = Hive.box(SaveService.metaBox).get('tutorialSeen', defaultValue: false) as bool;
      _showTutorial = !seen;
    } catch (e, st) {
      // ignore: avoid_print
      print('Error reading tutorialSeen: $e');
      // ignore: avoid_print
      print(st);
      _showTutorial = true;
    }
    // Debug heartbeat to detect unexpected disposal/crash while attached
    if (kDebugMode) {
      _hb = Timer.periodic(const Duration(seconds: 5), (_) {
        // ignore: avoid_print
        print('heartbeat: app alive ${DateTime.now()}');
      });
    }
  }

  @override
  void dispose() {
    _hb?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proc Dealer',
      theme: AppTheme.darkTheme,
      home: Stack(
        children: [
          const HomeShell(),
          if (_showTutorial)
            TutorialOverlay(
              onDismiss: () {
                Hive.box(SaveService.metaBox).put('tutorialSeen', true);
                setState(() => _showTutorial = false);
              },
            ),
        ],
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
// ...existing code...
