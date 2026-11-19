import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main/main_navigation.dart';

/// Entry point aplikasi Markas Endog.
/// Inisialisasi Firebase sebelum runApp.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  String? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    startupError = error.toString();
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
  }

  runApp(MarkasEndogApp(startupError: startupError));

  // Requesting notification permission can wait for user input on web. Start
  // the app first so that this optional step never leaves a blank page.
  if (startupError == null) {
    FCMService.instance.initialize().catchError((Object error, StackTrace stackTrace) {
      debugPrint('FCM initialization failed: $error\n$stackTrace');
    });
  }
}

/// Root widget aplikasi Markas Endog.
class MarkasEndogApp extends StatelessWidget {
  const MarkasEndogApp({super.key, this.startupError});

  final String? startupError;

  // --- Palet warna peternakan (oranye hangat) ---
  static const Color primaryOrange = Color(0xFFE8611A);
  static const Color primaryOrangeLight = Color(0xFFFFF3ED);
  static const Color primaryOrangeDark = Color(0xFFC04D10);
  static const Color surfaceWhite = Color(0xFFF9FAFB);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF10B981);
  static const Color dangerRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markas Endog',
      debugShowCheckedModeBanner: false,

      // === Tema Material 3 bernuansa oranye peternakan ===
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryOrange,
          primary: primaryOrange,
          surface: surfaceWhite,
          brightness: Brightness.light,
        ),

        // Font modern — Poppins untuk heading, Inter untuk body
        textTheme: TextTheme(
          headlineLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
          headlineMedium: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          titleLarge: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          titleMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          bodyLarge: GoogleFonts.inter(color: textDark),
          bodyMedium: GoogleFonts.inter(color: textGrey),
          labelLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        // AppBar bersih tanpa elevasi
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: textDark,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),

        // Card dengan sudut lembut
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),

        // Elevated button oranye
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryOrange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),

        // Input field styling
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryOrange, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: dangerRed),
          ),
        ),

        // Bottom nav bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primaryOrange,
          unselectedItemColor: textGrey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),

        scaffoldBackgroundColor: surfaceWhite,
      ),

      // === Auth Gate: cek status login ===
      home: startupError == null
          ? const _AuthGate()
          : _StartupErrorScreen(message: startupError!),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Aplikasi gagal terhubung ke Firebase',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget yang mendengarkan status autentikasi Firebase.
/// Jika sudah login → MainNavigation, belum → LoginScreen.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Menunggu koneksi awal
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: MarkasEndogApp.primaryOrange,
              ),
            ),
          );
        }

        // Jika error koneksi Firebase
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal terhubung ke server',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Periksa koneksi internet Anda',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        // User sudah login → tampilkan navigasi utama
        if (snapshot.hasData) {
          return const MainNavigation();
        }

        // User belum login → tampilkan halaman login
        return const LoginScreen();
      },
    );
  }
}
