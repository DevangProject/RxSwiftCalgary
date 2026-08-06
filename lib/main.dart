import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/splash/splash_screen.dart';
import 'firebase_options.dart';
import 'service/background_location_service.dart';
import 'service/notification_service.dart';


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

class _RxSwiftAppState extends ConsumerState<RxSwiftApp> {
  @override
  void initState() {
    super.initState();
    ref.read(notificationServiceProvider).initialize();
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
      home: const SplashScreen(),
    );
  }
}