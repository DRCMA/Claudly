import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import "services/config_controller.dart";
import 'screens/home.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

void main() async {
  // Solo llamamos al método sin asignar la variable si no la vamos a usar.
  WidgetsFlutterBinding.ensureInitialized();

  // Bloqueamos la orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 1. Inicialización de Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Configuración de persistencia de Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 3. Cargas paralelas de configuración
  await Future.wait([
    ConfigController.cargarConfiguracion(),
    initializeDateFormatting('es', null),
  ]);

  runApp(const MiDiarioApp());
}

class MiDiarioApp extends StatefulWidget {
  const MiDiarioApp({super.key});

  // Método estático para refrescar desde cualquier parte de la app
  static void refresh(BuildContext context) {
    context.findAncestorStateOfType<_MiDiarioAppState>()?.refrescar();
  }

  @override
  State<MiDiarioApp> createState() => _MiDiarioAppState();
}

class _MiDiarioAppState extends State<MiDiarioApp> {
  void refrescar() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Claud',
      debugShowCheckedModeBanner: false,

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
        Locale('ca', 'ES'),
      ],
      locale: const Locale('es', 'ES'), 

      // Control del tema global basado en el controlador estático
      themeMode: ConfigController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        fontFamily: 'Georgia',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
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

class _NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}