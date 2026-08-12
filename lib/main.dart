import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'core/theme.dart';
import 'core/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/pending_confirmation_screen.dart';
import 'features/navigation/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable full screen rotation for phones and tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Initialize Supabase configuration
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: TfcCrmApp(),
    ),
  );
}

class TfcCrmApp extends ConsumerWidget {
  const TfcCrmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Determine which screen to show
    Widget homeScreen;
    if (!authState.isAuthenticated) {
      homeScreen = const LoginScreen();
    } else if (!authState.isConfirmed) {
      homeScreen = const PendingConfirmationScreen();
    } else {
      homeScreen = const MainNavigationWrapper();
    }

    return MaterialApp(
      title: 'TFC Financial CRM',
      debugShowCheckedModeBanner: false,
      theme: TfcTheme.darkTheme,
      
      // Localization setup for Arabic support
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Dynamic Authentication Routing with global glass background
      home: TfcGlassBackground(child: homeScreen),
    );
  }
}

