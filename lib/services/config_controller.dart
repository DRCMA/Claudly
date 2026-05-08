import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigController {
  static double fontSize = 20.0;
  static bool isDarkMode = false;

  static Future<void> cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt('fontSize') ?? 0;
    fontSize = index == 1 ? 26.0 : 20.0;
    isDarkMode = prefs.getBool('darkMode') ?? false;
  }
  static final ValueNotifier<bool> darkModeListenable = ValueNotifier<bool>(isDarkMode);
  static final ValueNotifier<double> fontSizeListenable = ValueNotifier<double>(20.0);

  // Modifica tu función de cambiar tema para que "avise" del cambio
  static void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    // IMPORTANTE: Al cambiar el .value, todos los ValueListenableBuilder se activan
    darkModeListenable.value = isDarkMode; 
  }

  static double getAdaptedSize(double base) => fontSize > 20.0 ? base + 6.0 : base;

  // Fondo de AppBars y Menús (Marrón en claro, Gris muy oscuro en dark)
  static Color getHeaderColor() => isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFF3E2723);

  // Texto principal (Negro en claro, Blanco en dark)
  static Color getTextColor() => isDarkMode ? Colors.white : Colors.black;

  // Fondo de tarjetas en Social y Profile (Marrón en claro, Gris oscuro en dark)
  static Color getBrownDark() => isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFF3E2723);


  static Color getIconColor() => isDarkMode ? Colors.white70 : Colors.white;

  // Fondo de diarios en Home (Blanco en claro, Oscuro con borde en dark)
  static Color getDiaryColor() => isDarkMode ? const Color(0xFF2C2C2C) : Colors.white;

  // Fondo de la página (Imagen Scrapbook en claro, Gris sólido en dark)
  static Color getPageBgColor() => isDarkMode ? const Color(0xFF121212) : Colors.transparent;
}