import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0A1E),
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription _intentDataStreamSubscription;
  String? _initialSharedText;

  @override
  void initState() {
    super.initState();

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            // We only expect text/urls to be shared
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // Listen to text data from other apps
    ReceiveSharingIntent.instance.getMediaStream().listen((
      List<SharedMediaFile> value,
    ) {
      // not used for text mostly
    });

    // To get the intent from cold start
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isNotEmpty) {
        setState(() {
          _initialSharedText = value.first.path;
        });
      }
    });
  }

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  // Custom dark color scheme matching the purple app icon
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9C6AFF),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF2D1B69),
    onPrimaryContainer: Color(0xFFE0D0FF),
    secondary: Color(0xFF7DD3FC),
    onSecondary: Color(0xFF003547),
    secondaryContainer: Color(0xFF004D67),
    onSecondaryContainer: Color(0xFFBFE8FF),
    tertiary: Color(0xFFA5F3C4),
    onTertiary: Color(0xFF003920),
    surface: Color(0xFF0F0A1E),
    onSurface: Color(0xFFE6E1E9),
    surfaceContainerHighest: Color(0xFF1E1533),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    outline: Color(0xFF3D3550),
    shadow: Colors.black,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'justDownload',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: _darkScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F0A1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1230),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF2D1B69),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1A1230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: _initialSharedText != null
          ? SplashScreen(initialUrl: _initialSharedText)
          : const SplashScreen(),
    );
  }
}
