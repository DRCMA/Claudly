import 'package:flutter/material.dart';

class NotebookBackground extends StatelessWidget {
  final Widget child;
  final String tipoFondo;

  const NotebookBackground({
    super.key,
    required this.child,
    required this.tipoFondo, // Ahora es requerido
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // Imagen de fondo (paper, travel o love)
          Positioned.fill(
            child: Image.asset(
              'assets/images/$tipoFondo.jpg', 
              fit: BoxFit.cover,
              // Esto evita que se vea blanco mientras carga la imagen
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.white),
            ),
          ),
          // El contenido del editor
          child,
        ],
      ),
    );
  }
}