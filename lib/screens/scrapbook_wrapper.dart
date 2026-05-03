import 'package:flutter/material.dart';

class ScrapbookWrapper extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const ScrapbookWrapper({
    super.key, 
    required this.child, 
    this.appBar, 
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Capa base de color (Respaldo)
        Container(color: const Color(0xFFBC9A73)),
        
        // 2. Textura de papel
        Image.asset(
          'assets/images/kraft_paper_background.jpg',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFFBC9A73)),
        ),

        // 3. Capa sutil de oscuridad para contraste
        Container(color: Colors.black.withValues(alpha: 0.08)),

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