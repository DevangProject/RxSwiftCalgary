import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';
import 'service/background_location_service.dart';
import 'service/notification_service.dart';
import 'widgets/connectivity_banner.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  BackgroundLocationService().initialize();

  // Keep the screen on for as long as the app is in the foreground.
  WakelockPlus.enable();

  runApp(
    const ProviderScope(
      child: RxSwiftApp(),
    ),
  );
}

class RxSwiftApp extends ConsumerStatefulWidget {
  const RxSwiftApp({super.key});

  @override
  ConsumerState<RxSwiftApp> createState() => _RxSwiftAppState();
}

class _RxSwiftAppState extends ConsumerState<RxSwiftApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(notificationServiceProvider).initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The OS can drop the wakelock while the app is backgrounded — re-acquire
  // it every time the driver comes back to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) WakelockPlus.enable();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxSwift Calgary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0AA99B)),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      builder: (context, child) =>
          ConnectivityBanner(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}