import 'package:shared_preferences/shared_preferences.dart';

class ConfigController {
  // Ahora el Normal es 20.0 y el Grande 26.0
  static double fontSize = 20.0; 

  static Future<void> cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    // 0: Normal (20), 1: Grande (26)
    int index = prefs.getInt('fontSize') ?? 0; 
    fontSize = _convertirIndexATamano(index);
  }

  static double _convertirIndexATamano(int index) {
    // Si es 1 (Grande) devolvemos 26, si es 0 (Normal) devolvemos 20
    return (index == 1) ? 26.0 : 20.0;
  }

  // El adaptador para toda la app
  static double getAdaptedSize(double base) {
    // Si la fuente global es la "Grande" (26), sumamos 6 puntos a cualquier base
    if (fontSize > 20.0) {
      return base + 6.0; 
    }
    return base;
  }
}