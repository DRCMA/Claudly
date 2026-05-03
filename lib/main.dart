import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import "services/config_controller.dart";
import 'screens/home.dart';
import 'package:intl/date_symbol_data_local.dart';
// IMPORTANTE: Estos dos son necesarios para el idioma
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 1. Inicialización de Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. CONFIGURACIÓN PARA AHORRO DE ANCHO DE BANDA (Firestore Cache)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 3. Cargas de configuración e inicialización de fecha en español
  await Future.wait([
    ConfigController.cargarConfiguracion(),
    initializeDateFormatting('es', null),
  ]);

  runApp(const MiDiarioApp());
}

class MiDiarioApp extends StatelessWidget {
  const MiDiarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claud',
      debugShowCheckedModeBanner: false,

      // --- CONFIGURACIÓN DE IDIOMA (LOCALIZATION) ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'), // Español
        Locale('en', 'US'), // Inglés
      ],
      locale: const Locale('es', 'ES'), // Forzamos el idioma a español
      // ----------------------------------------------

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      home: const HomeScreen(),
      
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: _NoGlowScrollBehavior(),
          child: child!,
        );
      },
    );
  }
}

/// Ayuda a mejorar el rendimiento visual en listas largas quitando el efecto de brillo
class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}