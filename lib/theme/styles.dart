import 'package:flutter/material.dart';

class DiarioEstilo {
  // Colores principales
  static const Color primario = Colors.pinkAccent;
  static const Color fondo = Color(0xFFF8F0F2);

  // Configuración de las tarjetas
  static const double alturaImagen = 150.0; // Fotos más pequeñas
  static const double radioBorde = 15.0;

  // Estilo de texto para la fecha
  static TextStyle estiloFecha = TextStyle(
    fontSize: 12,
    color: Colors.grey[600],
    fontWeight: FontWeight.w400,
  );

  // Decoración de la tarjeta (el "CSS" de la caja)
  static BoxDecoration decoracionTarjeta = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radioBorde),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.5),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );
}