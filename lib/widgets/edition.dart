import 'dart:io';
import 'dart:developer' as dev;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'transformable_element.dart';

class EditorRecuerdoPage extends StatefulWidget {
  final String diarioId;
  final String? recuerdoId;
  final Map<String, dynamic>? datosIniciales;

  const EditorRecuerdoPage({
    super.key,
    required this.diarioId,
    this.recuerdoId,
    this.datosIniciales,
  });

  @override
  State<EditorRecuerdoPage> createState() => _EditorRecuerdoPageState();
}

class _EditorRecuerdoPageState extends State<EditorRecuerdoPage> {
  List<Map<String, dynamic>> elementos = [];
  final StorageService _storageService = StorageService();
  bool _estaCargando = false;
  int? _idElementoSeleccionado;
  DateTime _fechaSeleccionada = DateTime.now();
  bool _estaArrastrando = false;
  int? _idEditandoTexto;
  bool _estaEncimaDePapelera = false;
  String _menuAbierto = ''; // 'colorTexto', 'colorFondo' o ''
  String _fondoSeleccionado = 'default';


  final Map<String, Color> coloresTexto = {
    'Negro': Colors.black,
    'Rojo': Colors.redAccent,
    'Azul': Colors.blueAccent,
    'Verde': Colors.green.shade700,
    'Indigo': Colors.indigo,
  };

  final Map<String, Color> coloresSubrayado = {
    'Ninguno': Colors.transparent,
    'Amarillo': const Color(0xFFFFFF00),
    'Verde': const Color(0xFF00FF00),
    'Azul': const Color(0xFF00FFFF),
    'Rosa': const Color(0xFFFF00FF),
  };

  @override
  void initState() {
    super.initState();
    if (widget.datosIniciales != null) {
      elementos = List<Map<String, dynamic>>.from(
          (widget.datosIniciales!['elementos'] as List)
              .map((e) => Map<String, dynamic>.from(e)));
      if (widget.datosIniciales!['fecha'] != null) {
        _fechaSeleccionada = (widget.datosIniciales!['fecha'] as Timestamp).toDate();
      }
      if (widget.datosIniciales!['fondo'] != null) {
        _fondoSeleccionado = widget.datosIniciales!['fondo'];
      }
    }
  }

  // --- LÓGICA DE NEGOCIO ---

  void _seleccionarFecha() async {
    final DateTime? nuevaFecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (nuevaFecha != null) setState(() => _fechaSeleccionada = nuevaFecha);
  }

  void _addFoto() async {
    if (elementos.length >= 12) return;
    final ImagePicker picker = ImagePicker();
    final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (img != null) {
      setState(() {
        final nuevoId = DateTime.now().millisecondsSinceEpoch;
        elementos.add({
          'id': nuevoId,
          'tipo': 'foto',
          'archivoLocal': File(img.path),
          'url': '',
          'pieFoto': '',
          'x': 50.0,
          'y': 100.0,
          'angulo': 0.0,
          'ancho': 150.0,
        });
        _idElementoSeleccionado = nuevoId;
      });
    }
  }

  void _mostrarDialogoPieFoto(int id, String textoActual) {
    TextEditingController pieController = TextEditingController(text: textoActual);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Escribir en la Polaroid"),
        content: TextField(
          controller: pieController,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: "Ej: Verano 2024..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = elementos.indexWhere((e) => e['id'] == id);
                if (index != -1) {
                  elementos[index]['pieFoto'] = pieController.text;
                }
              });
              Navigator.pop(context);
            }, 
            child: const Text("Aceptar")
          ),
        ],
      ),
    );
  }

  void _addTexto() {
    if (elementos.length >= 12) return;
    setState(() {
      final nuevoId = DateTime.now().millisecondsSinceEpoch;
      elementos.add({
        'id': nuevoId,
        'tipo': 'texto',
        'texto': 'Escribe aquí...',
        'x': 80.0,
        'y': 200.0,
        'angulo': 0.0,
        'ancho': 180.0,
        'isBold': false,
        'isItalic': false,
        'color': Colors.black.toARGB32(), // Usamos .value para mayor compatibilidad
        'backgroundColor': Colors.transparent.toARGB32(), 
      });
      _idElementoSeleccionado = nuevoId;
    });
  }

  Future<void> _guardarTodo() async {
    setState(() => _estaCargando = true);
    _idElementoSeleccionado = null;

    try {
      for (var item in elementos) {
        if (item['tipo'] == 'foto' && item['archivoLocal'] != null) {
          String url = await _storageService.subirArchivoSolamente(
            XFile(item['archivoLocal'].path),
            diarioId: widget.diarioId,
          );
          item['url'] = url;
          item.remove('archivoLocal');
        }
      }

      final datosMap = {
        'fecha': Timestamp.fromDate(_fechaSeleccionada),
        'elementos': elementos,
        'fecha_edicion': FieldValue.serverTimestamp(),
        'fondo': _fondoSeleccionado,
      };

      final coll = FirebaseFirestore.instance
          .collection('diarios')
          .doc(widget.diarioId)
          .collection('recuerdos');

      if (widget.recuerdoId != null) {
        // Edición de recuerdo existente: devolvemos su id
        await coll.doc(widget.recuerdoId).update(datosMap);
        if (mounted) Navigator.pop(context, widget.recuerdoId);
      } else {
        // Recuerdo nuevo: devolvemos '' para indicar que se creó algo nuevo
        await coll.add(datosMap);
        if (mounted) Navigator.pop(context, '');
      }
    } catch (e) {
      dev.log("Error: $e");
    } finally {
      if (mounted) setState(() => _estaCargando = false);
    }
  }

  void _validarYGuardar() {
    if (elementos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se puede crear un recuerdo vacío."),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _guardarTodo();
  }

  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = bottomInset > 0;
    // Definimos la altura de la cabecera (debe ser igual en diary.dart)
    const double alturaCabecera = 60.0;

    final elementoSeleccionado = _idElementoSeleccionado != null
        ? elementos.cast<Map<String, dynamic>?>().firstWhere(
            (e) => e?['id'] == _idElementoSeleccionado,
            orElse: () => null)
        : null; 

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (elementos.isEmpty) {
          // Sin cambios: salimos devolviendo null (diary no hará nada)
          Navigator.of(context).pop();
          return;
        }

        final salir = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("¿Salir del editor?"),
            content: const Text("Si sales ahora, perderás los cambios no guardados."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Seguir editando", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("Salir"),
              ),
            ],
          ),
        ); 

        // Cancelar sin guardar: devolvemos null para que diary no haga nada
        if (salir == true && context.mounted) Navigator.of(context).pop();
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            _idElementoSeleccionado = null;
            _idEditandoTexto = null;
            _menuAbierto = '';
          });
          FocusScope.of(context).unfocus();
        }, 
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFFD7CCC8), 
          appBar: AppBar(
            title: const Text("Editor de Recuerdos", style: TextStyle(fontSize: 16)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 1,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.format_paint, color: Colors.indigo), onPressed: _cambiarFondoDialog),
              IconButton(icon: const Icon(Icons.calendar_month), onPressed: _seleccionarFecha),
              if (_estaCargando)
                const Center(child: Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2)))
              else
                IconButton(icon: const Icon(Icons.check, color: Colors.indigo, size: 30), onPressed: _validarYGuardar)
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // --- EL FOLIO ---
              Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    image: DecorationImage(
                      image: AssetImage('assets/images/$_fondoSeleccionado.jpg'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(4, 4))],
                  ), 
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double areaUtilAltura = constraints.maxHeight - alturaCabecera; 
                        
                      return Stack(
                        // FIX: Clip.hardEdge para que los elementos no sobresalgan del folio durante la edición
                        clipBehavior: Clip.hardEdge,
                        children: [
                          // 1. CABECERA (Zona de la papelera reactiva)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 300),
                              scale: _estaArrastrando ? 1.0 : 0.0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 70,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: _estaEncimaDePapelera 
                                      ? Colors.red.withValues(alpha: 0.8) 
                                      : Colors.black.withValues(alpha: 0.4),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _estaEncimaDePapelera ? Icons.delete_forever : Icons.delete_outline,
                                      color: Colors.white,
                                      size: _estaEncimaDePapelera ? 35 : 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _estaEncimaDePapelera ? "¡SUELTA PARA ELIMINAR!" : "ARRASTRA AQUÍ PARA BORRAR",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // 2. LIENZO DE ELEMENTOS
                          Positioned(
                            top: alturaCabecera,
                            left: 0, right: 0, bottom: 0,
                            child: ClipRect(
                              child: Stack(
                                // FIX: Clip.hardEdge para recortar elementos dentro del área de edición
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() {
                                          _idElementoSeleccionado = null;
                                          _idEditandoTexto = null;
                                          _menuAbierto = '';
                                        });
                                        FocusScope.of(context).unfocus();
                                      },
                                      child: Container(color: Colors.transparent),
                                    ),
                                  ),

                                  ...elementos.map((item) {
                                    final bool esSeleccionado = _idElementoSeleccionado == item['id'];
                                    return TransformableElement(
                                      key: ValueKey(item['id']),
                                      item: item,
                                      maxWidth: constraints.maxWidth,
                                      maxHeight: areaUtilAltura, 
                                      isSelected: esSeleccionado,
                                      onSelect: () {
                                        setState(() {
                                          _idElementoSeleccionado = item['id'];
                                          _idEditandoTexto = null;
                                          _menuAbierto = '';
                                          final index = elementos.indexOf(item);
                                          if (index != -1) {
                                            elementos.add(elementos.removeAt(index));
                                          }
                                        });
                                      }, 
                                      onChanged: () => setState(() {}),
                                      onDraggingChanged: (dragging) {
                                        setState(() {
                                          _estaArrastrando = dragging;
                                          if (!dragging && _estaEncimaDePapelera) {
                                            elementos.removeWhere((e) => e['id'] == item['id']);
                                            _idElementoSeleccionado = null;
                                          }
                                          if (!dragging) _estaEncimaDePapelera = false;
                                        });
                                      }, 
                                      onPositionChanged: (y) {
                                        if (!esSeleccionado) return;
                                        bool encima = y < 10; 
                                        if (encima != _estaEncimaDePapelera) {
                                          setState(() => _estaEncimaDePapelera = encima);
                                        }
                                      }, 
                                      onDelete: () => setState(() {
                                        elementos.removeWhere((e) => e['id'] == item['id']);
                                        _idElementoSeleccionado = null;
                                        _estaArrastrando = false;
                                        _estaEncimaDePapelera = false;
                                      }), 
                                      child: _buildElemento(item),
                                    );
                                  }), 
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              // --- TOOLBAR DE TEXTO ---
              if ((_idElementoSeleccionado != null || _idEditandoTexto != null) && 
                  elementoSeleccionado?['tipo'] == 'texto' && !_estaArrastrando)
                Positioned(
                  bottom: tecladoAbierto ? bottomInset + 10 : null,
                  top: tecladoAbierto ? null : 15,
                  left: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: Center(child: _buildToolbarTexto(elementoSeleccionado!)),
                  ),
                ), 
            ],
          ),
          floatingActionButton: _estaArrastrando ? null : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: "btn_t",
                onPressed: _estaCargando ? null : _addTexto,
                backgroundColor: Colors.white,
                child: const Icon(Icons.text_fields, color: Colors.indigo),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: "btn_f",
                onPressed: _estaCargando ? null : _addFoto,
                backgroundColor: Colors.indigo,
                child: const Icon(Icons.add_a_photo, color: Colors.white),
              ),
            ],
          ), 
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildElemento(Map<String, dynamic> item) {
    if (item['tipo'] == 'foto') {
      final bool esLocal = item['archivoLocal'] != null;
      final bool esSeleccionado = _idElementoSeleccionado == item['id'];
      final String pieFoto = item['pieFoto'] ?? "";
      final bool tieneTexto = pieFoto.isNotEmpty;
      final double anchoReal = (item['ancho'] as num? ?? 150.0).toDouble();

      return GestureDetector(
        onDoubleTap: () {
          if (esSeleccionado) {
            _mostrarDialogoPieFoto(item['id'], pieFoto);
          }
        },
        child: Container(
          constraints: BoxConstraints(maxWidth: anchoReal + 16),
          padding: EdgeInsets.fromLTRB(8, 8, 8, (esSeleccionado || tieneTexto) ? 20 : 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: esSeleccionado ? Colors.blue : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), 
                blurRadius: 10, 
                offset: const Offset(3, 5)
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              esLocal
                  ? Image.file(item['archivoLocal'], fit: BoxFit.contain, width: anchoReal, cacheWidth: 400)
                  : CachedNetworkImage(
                      imageUrl: item['url'],
                      fit: BoxFit.contain,
                      width: anchoReal,
                      placeholder: (context, url) => const SizedBox(
                        height: 100, 
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2))
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.cloud_off),
                    ),
              
              if (esSeleccionado || tieneTexto)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: SizedBox(
                    width: anchoReal,
                    child: Text(
                      tieneTexto ? pieFoto : (esSeleccionado ? "Doble clic..." : ""),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier', 
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return _buildTextFieldElement(item);
    }
  }

  Widget _buildTextFieldElement(Map<String, dynamic> item) {
    bool editandoEste = _idEditandoTexto == item['id'];
    double ancho = (item['ancho'] as num? ?? 180.0).toDouble();

    // Recuperación robusta de colores
    Color colorTexto = Color(item['color'] as int? ?? Colors.black.toARGB32());
    Color colorFondo = Color(item['backgroundColor'] as int? ?? Colors.transparent.toARGB32());

    TextStyle estilo = TextStyle(
      fontSize: (ancho / 10).clamp(14.0, 50.0),
      color: colorTexto,
      backgroundColor: colorFondo, 
      fontWeight: item['isBold'] == true ? FontWeight.bold : FontWeight.normal,
      fontStyle: item['isItalic'] == true ? FontStyle.italic : FontStyle.normal,
    );

    return Container(
      width: ancho,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        border: (_idElementoSeleccionado == item['id'] && !editandoEste)
            ? Border.all(color: Colors.indigo.withValues(alpha: 0.3))
            : Border.all(color: Colors.transparent),
        borderRadius: BorderRadius.circular(4),
      ),
      child: editandoEste
          ? TextField(
              controller: DiarioTextController(item)
                ..selection = TextSelection.collapsed(offset: (item['texto'] ?? "").length),
              autofocus: true,
              maxLines: null,
              textAlign: TextAlign.center,
              style: estilo,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: (val) => item['texto'] = val,
              onTapOutside: (event) {
                if (event.localPosition.dy < 0) return;
                setState(() => _idEditandoTexto = null);
              },
            )
          : GestureDetector(
              onDoubleTap: () => setState(() {
                _idEditandoTexto = item['id'];
                _idElementoSeleccionado = item['id'];
              }),
              behavior: HitTestBehavior.translucent,
              child: Text(
                (item['texto'] == null || item['texto'].isEmpty) ? "Escribe aquí..." : item['texto'],
                style: estilo,
                textAlign: TextAlign.center,
              ),
            ),
    );
  }

  Widget _buildToolbarTexto(Map<String, dynamic> elemento) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _botonToolbar(
                  icon: Icons.palette,
                  activo: _menuAbierto == 'colorTexto',
                  onPressed: () => setState(() => _menuAbierto = _menuAbierto == 'colorTexto' ? '' : 'colorTexto'),
                ),
                _botonToolbar(
                  icon: Icons.auto_fix_high,
                  activo: _menuAbierto == 'backgroundColor',
                  onPressed: () => setState(() => _menuAbierto = _menuAbierto == 'backgroundColor' ? '' : 'backgroundColor'),
                ),
                const VerticalDivider(width: 1, indent: 10, endIndent: 10, color: Colors.black12),
                _botonToolbar(
                  icon: Icons.format_bold,
                  activo: elemento['isBold'] == true,
                  onPressed: () => setState(() => elemento['isBold'] = !(elemento['isBold'] ?? false)),
                ),
                _botonToolbar(
                  icon: Icons.format_italic,
                  activo: elemento['isItalic'] == true,
                  onPressed: () => setState(() => elemento['isItalic'] = !(elemento['isItalic'] ?? false)),
                ),
                _botonToolbar(
                  icon: Icons.format_list_bulleted,
                  activo: false,
                  onPressed: () {
                    setState(() {
                      String txt = elemento['texto'] ?? "";
                      elemento['texto'] = txt.isEmpty ? "• " : "$txt\n• ";
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        if (_menuAbierto.isNotEmpty) _buildSelectorColores(elemento),
      ],
    );
  }

  Widget _buildSelectorColores(Map<String, dynamic> elemento) {
    return Container(
      height: 55,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: (_menuAbierto == 'colorTexto' ? coloresTexto : coloresSubrayado)
            .entries.map((entry) {
              bool estaSeleccionado = _menuAbierto == 'colorTexto' 
                  ? elemento['color'] == entry.value.toARGB32()
                  : elemento['backgroundColor'] == entry.value.toARGB32();

          return GestureDetector(
            onTap: () {
              setState(() {
                if (_menuAbierto == 'colorTexto') {
                  elemento['color'] = entry.value.toARGB32();
                } else {
                  elemento['backgroundColor'] = entry.value.toARGB32();
                }
              });
            },
            child: Container(
              width: 35, height: 35,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: entry.value,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 1),
              ),
              child: estaSeleccionado
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _botonToolbar({required IconData icon, required bool activo, required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Icon(icon, color: activo ? Colors.indigo : Colors.black87, size: 24),
      ),
    );
  }

  void _cambiarFondoDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 4, width: 40,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const Text(
              "Estilo del Diario",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            _opcionFondoLista('Papel Clásico', 'default', 'assets/images/default.jpg'),
            _opcionFondoLista('Aventura Travel', 'travel', 'assets/images/travel.jpg'),
            _opcionFondoLista('Especial Love', 'love', 'assets/images/love.jpg'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _opcionFondoLista(String titulo, String valor, String pathImagen) {
    bool esSeleccionado = _fondoSeleccionado == valor;

    return InkWell(
      onTap: () {
        setState(() => _fondoSeleccionado = valor);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: esSeleccionado ? Colors.indigo.withValues(alpha: 0.05) : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: esSeleccionado ? Colors.blue : Colors.transparent,
                  width: esSeleccionado ? 2 : 0, 
                ),
                image: DecorationImage(
                  image: AssetImage(pathImagen),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.normal,
                  color: esSeleccionado ? Colors.indigo : Colors.black87,
                ),
              ),
            ),
            if (esSeleccionado) const Icon(Icons.check_circle, color: Colors.indigo),
          ],
        ),
      ),
    );
  }
}

class DiarioTextController extends TextEditingController {
  final Map<String, dynamic> item;
  DiarioTextController(this.item) : super(text: item['texto'] ?? "");

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    return TextSpan(text: text, style: style);
  }
}