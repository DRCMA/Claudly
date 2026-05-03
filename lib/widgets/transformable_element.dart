import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TransformableElement extends StatefulWidget {
  final Map<String, dynamic> item;
  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;
  final Function(bool) onDraggingChanged;
  // NUEVO: Para que el padre sepa dónde está el elemento y active la papelera
  final Function(double y) onPositionChanged;

  const TransformableElement({
    super.key,
    required this.item,
    required this.child,
    required this.maxWidth,
    required this.maxHeight,
    required this.isSelected,
    required this.onSelect,
    required this.onChanged,
    required this.onDraggingChanged,
    required this.onPositionChanged,
    this.onDelete,
  });

  @override
  State<TransformableElement> createState() => _TransformableElementState();
}

class _TransformableElementState extends State<TransformableElement> {
  double _baseAngulo = 0.0;
  double _baseAncho = 0.0;
  bool _puedeMover = false;
  Timer? _timerDeEspera; 
  double _ultimoAnguloVibrado = -1.0;

  @override
  void dispose() {
    _timerDeEspera?.cancel();
    super.dispose();
  }

@override
  Widget build(BuildContext context) {
    final double ancho = (widget.item['ancho'] as num? ?? 160.0).toDouble();
    final double angulo = (widget.item['angulo'] as num? ?? 0.0).toDouble();
    final double x = (widget.item['x'] as num? ?? 0.0).toDouble();
    final double y = (widget.item['y'] as num? ?? 0.0).toDouble();

    // LÓGICA DE ESCALA DINÁMICA:
    // 1. Si está en la zona de la papelera (aprox > 75% de la pantalla) y seleccionado: se encoge.
    // 2. Si solo se está moviendo: crece un poquito (1.08).
    // 3. Reposo: 1.0.
    double escalaVisual = 1.0;
    bool estaEnZonaEliminacion = y > (widget.maxHeight * 0.75);

    if (widget.isSelected && estaEnZonaEliminacion && _puedeMover) {
      escalaVisual = 0.5; // Se encoge para la papelera
    } else if (_puedeMover) {
      escalaVisual = 1.08; // Efecto de levante al arrastrar
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: x,
          top: y,
          child: GestureDetector(
            onScaleStart: (details) {
              widget.onSelect();
              _baseAngulo = (widget.item['angulo'] as num? ?? 0.0).toDouble();
              _baseAncho = (widget.item['ancho'] as num? ?? 160.0).toDouble();

              _timerDeEspera?.cancel();
              _timerDeEspera = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() => _puedeMover = true);
                  widget.onDraggingChanged(true);
                  HapticFeedback.heavyImpact(); 
                }
              });
            },
            onScaleUpdate: (details) {
              if (details.pointerCount > 1) {
                _timerDeEspera?.cancel();
                if (_puedeMover) {
                  setState(() => _puedeMover = false);
                  widget.onDraggingChanged(false);
                }
              }

              setState(() {
                if (_puedeMover && details.pointerCount == 1) {
                  widget.item['x'] += details.focalPointDelta.dx;
                  widget.item['y'] += details.focalPointDelta.dy;
                  
                  // Notificamos la posición para que el padre gestione la papelera
                  widget.onPositionChanged(widget.item['y']);
                }

                if (details.pointerCount > 1) {
                  double nuevoAncho = _baseAncho * details.scale;
                  widget.item['ancho'] = nuevoAncho.clamp(80.0, widget.maxWidth * 2.0).toDouble();

                  double anguloActual = _baseAngulo + details.rotation;
                  const double sensibilidad = 0.08;
                  double snapshot = (anguloActual / (math.pi / 2)).round() * (math.pi / 2);

                  if ((anguloActual - snapshot).abs() < sensibilidad) {
                    widget.item['angulo'] = snapshot;
                    if (_ultimoAnguloVibrado != snapshot) {
                      HapticFeedback.lightImpact();
                      _ultimoAnguloVibrado = snapshot;
                    }
                  } else {
                    widget.item['angulo'] = anguloActual;
                    _ultimoAnguloVibrado = -1.0;
                  }
                }
              });
              widget.onChanged();
            },
            onScaleEnd: (details) {
              _timerDeEspera?.cancel();

              if (_puedeMover && estaEnZonaEliminacion) {
                widget.onDelete?.call();
                HapticFeedback.vibrate(); 
              }

              setState(() => _puedeMover = false);
              widget.onDraggingChanged(false);
            },
            child: Transform.rotate(
              angle: angulo,
              // Movemos el AnimatedScale para que envuelva al Container (con su borde)
              child: AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: escalaVisual, 
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: _puedeMover ? 0.7 : 1.0,
                  child: Container(
                    width: ancho,
                    padding: const EdgeInsets.all(10), 
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            border: Border.all(
                              color: Colors.indigo.withAlpha(150),
                              width: 2,
                            ),
                            // Agregamos un fondo muy tenue para que el marco sea más visible al encogerse
                            color: Colors.indigo.withAlpha(10), 
                          )
                        : null,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}