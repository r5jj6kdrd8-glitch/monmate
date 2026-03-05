import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mongo_mate/screens/intro.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mongo_mate/helpers/toast.dart';
import 'package:mongo_mate/screens/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mongo_mate/utilities/app_theme.dart';
import 'package:mongo_mate/utilities/subscription_service.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SubscriptionService.instance.init();

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ToastHelper.scaffoldMessengerKey,
      home: const InitialScreen(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
        );
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool _isLoading = true;
  bool _isIntroSeen = false;

  @override
  void initState() {
    super.initState();
    _checkIntroStatus();
  }

  Future<void> _checkIntroStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool seen = prefs.getBool('intro_seen') ?? false;

    setState(() {
      _isIntroSeen = seen;
      _isLoading = false; // Loading complete
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading screen while checking the intro status
    if (_isLoading) {
      return Scaffold(
        body: AppBackground(
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }

    // Navigate to the appropriate page based on the intro status
    return _isIntroSeen ? const HomePage() : const IntroPage();
  }
}
