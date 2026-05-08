import 'package:flutter/material.dart';

class ScrapbookWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool isDarkMode; // Nueva propiedad para el control de tono

  const ScrapbookWrapper({
    super.key, 
    required this.child, 
    this.appBar, 
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.isDarkMode = false,  
    this.backgroundColor, // Por defecto desactivado
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Capa base de color (Tono madera o carbón)
        Container(color: isDarkMode ? const Color(0xFF2C251E) : const Color(0xFFBC9A73)),
        
        // 2. Textura de papel con filtro de color dinámico
        Image.asset(
          'assets/images/kraft_paper_background.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          color: isDarkMode ? Colors.black.withValues(alpha: 0.6) : null,
          colorBlendMode: isDarkMode ? BlendMode.darken : null,
          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFBC9A73)),
        ),

        // 3. Capa de contraste adaptable
        Container(
          color: isDarkMode 
            ? Colors.black.withValues(alpha: 0.3) 
            : Colors.black.withValues(alpha: 0.08)
        ),

        // 4. El Scaffold real (Transparente)
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: child,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        ),
      ],
    );
  }
}