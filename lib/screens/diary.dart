import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:page_flip/page_flip.dart';
import '../services/storage_service.dart';
import '../widgets/edition.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DiaryPage extends StatefulWidget {
  final String diarioId;
  final String nombreDiario;

  const DiaryPage({super.key, required this.diarioId, required this.nombreDiario});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final StorageService _storageService = StorageService();
  
  GlobalKey<PageFlipWidgetState> _pageFlipKey = GlobalKey<PageFlipWidgetState>();

  late Stream<QuerySnapshot> _recuerdosStream;
  List<QueryDocumentSnapshot> _currentDocs = [];
  int _totalDocs = 0;

  bool _estaBuscando = false;
  bool _saltandoAlFinal = true; 
  bool _primeraCarga = true;

  int? _paginaAlVolver;
  String _lastDataHash = '';
  String? _hashEsperado;
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _recuerdosStream = FirebaseFirestore.instance
        .collection('diarios')
        .doc(widget.diarioId)
        .collection('recuerdos')
        .orderBy('fecha', descending: false)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE ACTUALIZACIÓN REFINADA ---

void _ejecutarRefrescoYSalto(int pagina) {
  if (!mounted) return;

  setState(() {
    _saltandoAlFinal = true;
    _pageFlipKey = GlobalKey<PageFlipWidgetState>(); // Fuerza el refresco total
  });

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      final state = _pageFlipKey.currentState;
      
      // Intentamos hacer el salto de página si el estado está listo
      if (state != null) {
        try {
          state.goToPage(pagina);
        } catch (e) {
          debugPrint("Fallo captura PageFlip: $e");
        }
      }
      
      // CORRECCIÓN 2: Este delay y su setState SIEMPRE deben ejecutarse, 
      // sin importar si el state de PageFlip fue nulo o no.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _saltandoAlFinal = false;
            _paginaAlVolver = null;
            _hashEsperado = null;
          });
        }
      });
    });
  });
}

  void _irAlFinal() {
    if (_currentDocs.isEmpty) return;
    final int ultimaPagina = _estaBuscando ? _totalDocs - 1 : _totalDocs;
    _ejecutarRefrescoYSalto(ultimaPagina);
  }

  Future<void> _abrirEditor({String? docId, Map<String, dynamic>? datosIniciales}) async {
    final int paginaActual = _pageFlipKey.currentState?.pageNumber ?? 0;

    final String? resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorRecuerdoPage(
          diarioId: widget.diarioId,
          recuerdoId: docId,
          datosIniciales: datosIniciales,
        ),
      ),
    );

    if (resultado != null) {
      setState(() {
        if (docId == null) {
          _paginaAlVolver = -1;
          _hashEsperado = 'nuevo';
        } else {
          _paginaAlVolver = paginaActual;
          _hashEsperado = 'pendiente_$docId';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFD7CCC8),
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: _recuerdosStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          _currentDocs = snapshot.data!.docs;
          
          final String currentHash = _currentDocs
              .map((d) => d.id + d.data().toString().hashCode.toString())
              .join();
              
          if (_primeraCarga || currentHash != _lastDataHash) {
  _lastDataHash = currentHash;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_primeraCarga) {
      _primeraCarga = false;
      _ejecutarRefrescoYSalto(0);
    } else if (_hashEsperado != null) {
      int destino = 0;
                if (_paginaAlVolver == -1) {
                  // Si es nuevo, vamos al último elemento real (length - 1)
                  destino = _currentDocs.isNotEmpty ? _currentDocs.length - 1 : 0;
                } else {
                  // Si venimos de editar o buscar, volvemos a donde estábamos
                  destino = _paginaAlVolver ?? 0;
                }
      _ejecutarRefrescoYSalto(destino);
    }
  });
}
          if (currentHash != _lastDataHash) {
            _lastDataHash = currentHash;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_primeraCarga) {
                _primeraCarga = false;
                _ejecutarRefrescoYSalto(0);
              } else if (_hashEsperado != null) {
                int destino = _paginaAlVolver == -1 ? _currentDocs.length : (_paginaAlVolver ?? 0);
                _ejecutarRefrescoYSalto(destino);
              }
            });
          }

          final recuerdosFiltrados = _currentDocs.where((doc) {
            if (!_estaBuscando || _searchController.text.isEmpty) return true;
            final data = doc.data() as Map<String, dynamic>;
            final fecha = DateFormat('dd/MM/yyyy').format((data['fecha'] as Timestamp).toDate());
            final marcador = data['marcador']?['texto']?.toString().toLowerCase() ?? '';
            final busqueda = _searchController.text.toLowerCase();
            return fecha.contains(busqueda) || marcador.contains(busqueda);
          }).toList();

          _totalDocs = recuerdosFiltrados.length;

          List<Widget> hojasDelLibro = recuerdosFiltrados.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              key: ValueKey("leaf_${doc.id}_${data.toString().hashCode}"),
              child: _buildHojaRecuerdo(doc.id, data),
            );
          }).toList();

          if (!_estaBuscando) {
            hojasDelLibro.add(Container(
              key: const ValueKey("leaf_new_page"),
              child: _buildHojaEnBlanco(),
            ));
          } else {
            hojasDelLibro.add(Container(
              key: const ValueKey("leaf_search_filler"),
              color: const Color(0xFFFFFDE7),
              child: const Center(
                child: Opacity(
                  opacity: 0.2,
                  child: Icon(Icons.menu_book, size: 50, color: Colors.brown),
                ),
              ),
            ));
          }

          return Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFFFFDE7),
                  child: Opacity(
                    opacity: _saltandoAlFinal ? 0.0 : 1.0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity == null) return;
                        int paginaActual = _pageFlipKey.currentState?.pageNumber ?? 0;
                        if (details.primaryVelocity! < -100) { 
                          if (paginaActual < hojasDelLibro.length - 1) {
                            _pageFlipKey.currentState?.goToPage(paginaActual + 1);
                          }
                        } else if (details.primaryVelocity! > 100) {
                          if (paginaActual > 0) {
                            _pageFlipKey.currentState?.goToPage(paginaActual - 1);
                          }
                        }
                      },
                      child: PageFlipWidget(
                        key: _pageFlipKey,
                        backgroundColor: Colors.transparent,
                        isRightSwipe: false, 
                        duration: const Duration(milliseconds: 700),
                        lastPage: hojasDelLibro.length > 1 
                            ? hojasDelLibro.removeLast() 
                            : hojasDelLibro.first,
                        children: hojasDelLibro,
                      ),
                    ),
                  ),
                ),
              ),
              if (_saltandoAlFinal)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFFFFDE7),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.brown),
                          SizedBox(height: 20),
                          Text("Sincronizando diario...",
                              style: TextStyle(fontFamily: 'Georgia', fontStyle: FontStyle.italic, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- COMPONENTES (FIXED DATA PARENT ERROR) ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      foregroundColor: Colors.black,
      title: _estaBuscando
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(hintText: "Buscar...", border: InputBorder.none),
              onChanged: (val) => setState(() { _pageFlipKey = GlobalKey<PageFlipWidgetState>(); }),
            )
          : Text(widget.nombreDiario, style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: Icon(_estaBuscando ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _estaBuscando = !_estaBuscando;
            if (!_estaBuscando) _searchController.clear();
            _pageFlipKey = GlobalKey<PageFlipWidgetState>();
          }),
        ),
        if (!_estaBuscando) 
          IconButton(icon: const Icon(Icons.last_page, color: Colors.indigo), onPressed: _irAlFinal),
      ],
    );
  }

  Widget _buildHojaRecuerdo(String docId, Map<String, dynamic> data) {
    List elementos = data['elementos'] ?? [];
    String fondo = data['fondo'] ?? 'paper';
    DateTime fechaDt = (data['fecha'] as Timestamp).toDate();
    Map<String, dynamic>? marcador = data['marcador'];

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage('assets/images/$fondo.jpg'), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Stack(
                  children: elementos.map((item) => Positioned(
                    left: (item['x'] as num? ?? 0.0).toDouble(),
                    top: (item['y'] as num? ?? 0.0).toDouble(),
                    child: _buildElementoEstatico(item),
                  )).toList(),
                ),
              ),
            ),
            if (marcador != null) _buildPostIt(marcador),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(padding: const EdgeInsets.only(left: 25.0),
                  child: Text(DateFormat('dd/MM/yyyy').format(fechaDt),
                      style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                  _buildMenu(docId, data, elementos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostIt(Map<String, dynamic> marcador) {
    return Positioned(
      top: 0, right: 50,
      child: Transform.rotate(
        angle: -0.05,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Color(marcador['color'] ?? 0xFFFFF176),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
          ),
          child: Text(marcador['texto']?.toString().toUpperCase() ?? '',
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildElementoEstatico(Map<String, dynamic> item) {
    final double angulo = (item['angulo'] ?? item['rotacion'] ?? 0.0).toDouble();
    if (item['tipo'] == 'foto' || item['tipo'] == 'imagen') {
      return Transform.rotate(
        angle: angulo,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
          child: CachedNetworkImage(
            imageUrl: item['url'] ?? "",
            width: (item['ancho'] ?? 150).toDouble(),
            placeholder: (context, url) => const SizedBox(width: 30, height: 30, child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image),
          ),
        ),
      );
    }
    double anchoTexto = (item['ancho'] ?? 200.0).toDouble();
    return Transform.rotate(
      angle: angulo,
      child: SizedBox(
        width: anchoTexto,
        child: Text(
          item['texto'] ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(item['color'] ?? 0xFF000000),
            fontSize: (anchoTexto / 10).clamp(14.0, 50.0),
            fontWeight: item['isBold'] == true ? FontWeight.bold : FontWeight.normal,
            fontStyle: item['isItalic'] == true ? FontStyle.italic : FontStyle.normal,
            backgroundColor: Color(item['backgroundColor'] ?? 0x00000000),
          ),
        ),
      ),
    );
  }

  Widget _buildHojaEnBlanco() {
    return GestureDetector(
      onTap: () => _abrirEditor(),
      child: Container(
        color: Colors.white,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 80, color: Colors.grey),
              Text("Nuevo recuerdo", style: TextStyle(fontFamily: 'Georgia', color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenu(String docId, Map<String, dynamic> data, List elementos) {
    Map<String, dynamic>? marcador = data['marcador'];
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (val) {
        if (val == 'edit') {
          _abrirEditor(docId: docId, datosIniciales: data);
        } else if (val == 'delete') {
          _confirmarBorrado(docId, elementos);
        } else if (val == 'marcador') {
          _gestionMarcadorDialog(docId, marcador);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'marcador',
          child: Row(children: [
            Icon(marcador == null ? Icons.bookmark_add : Icons.edit_attributes, color: Colors.orange),
            const SizedBox(width: 8),
            Text(marcador == null ? "Añadir Marcador" : "Editar Marcador"),
          ]),
        ),
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Editar Hoja")])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Borrar Hoja")])),
      ],
    );
  }

  // --- DIÁLOGOS CORREGIDOS (SIN SPACER) ---

  void _confirmarBorrado(String docId, List elementos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar este recuerdo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _saltandoAlFinal = true); 
              for (var item in elementos) {
                if ((item['tipo'] == 'foto' || item['tipo'] == 'imagen') && item['url'] != null) {
                  await _storageService.borrarArchivo(item['url']);
                }
              }
              await FirebaseFirestore.instance.collection('diarios').doc(widget.diarioId).collection('recuerdos').doc(docId).delete();
              _paginaAlVolver = 0;
              _hashEsperado = 'borrado'; 
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

void _gestionMarcadorDialog(String docId, Map<String, dynamic>? marcadorActual) async {
  // 1. Consulta de sugerencias mejorada
  final query = await FirebaseFirestore.instance
      .collection('diarios').doc(widget.diarioId).collection('recuerdos')
      .where('marcador', isNull: false).limit(15).get();

  Set<String> sugerencias = query.docs
      .map((d) => (d.data())['marcador']?['texto']?.toString() ?? '')
      .where((t) => t.isNotEmpty).toSet();

  TextEditingController txtCtrl = TextEditingController(text: marcadorActual?['texto'] ?? "");
  final List<int> misColores = [0xFFFFF176, 0xFFFF8A80, 0xFF80D8FF, 0xFFCCFF90];
  int colorSeleccionado = marcadorActual?['color'] ?? misColores[0];

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(marcadorActual == null ? "Añadir Marcador" : "Editar Marcador", 
          style: const TextStyle(fontFamily: 'Georgia')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: txtCtrl,
              decoration: const InputDecoration(hintText: "Nombre...", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.brown))),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: misColores.map((color) => GestureDetector(
                onTap: () => setDialogState(() => colorSeleccionado = color),
                child: Container(
                  width: 35, height: 35,
                  decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle, 
                    border: Border.all(color: colorSeleccionado == color ? Colors.black87 : Colors.transparent, width: 2)),
                ),
              )).toList(),
            ),
            // REINSERCIÓN SEGURO DE SUGERENCIAS
            if (sugerencias.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text("Sugerencias:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: sugerencias.take(5).map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 10)),
                  onPressed: () => setDialogState(() => txtCtrl.text = s),
                )).toList(),
              ),
            ],
          ],
        ),
        // IMPORTANTE: actionsAlignment evita el uso de Spacer y corrige el error de ParentData
        actionsAlignment: MainAxisAlignment.spaceBetween, 
        actions: [
          if (marcadorActual != null)
            TextButton(
              onPressed: () => _confirmarEliminarMarcador(docId),
              child: const Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                onPressed: () {
                  String nuevoTexto = txtCtrl.text.toUpperCase();
                  // Validación anti-bucle: si no hay cambios, solo cerramos
                  if (marcadorActual != null && 
                      marcadorActual['texto'] == nuevoTexto && 
                      marcadorActual['color'] == colorSeleccionado) {
                    Navigator.pop(ctx);
                    return;
                  }
                  Navigator.pop(ctx);
                  _aplicarCambioMarcador(docId, {'texto': nuevoTexto, 'color': colorSeleccionado});
                },
                child: const Text("Guardar", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  void _confirmarEliminarMarcador(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar marcador?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Cierra confirmación
              Navigator.pop(context); // Cierra diálogo marcador
              _aplicarCambioMarcador(docId, null);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _aplicarCambioMarcador(String docId, Map<String, dynamic>? data) async {
    setState(() {
      _saltandoAlFinal = true;
      _hashEsperado = 'pendiente_$docId';
      _paginaAlVolver = _pageFlipKey.currentState?.pageNumber;
    });

    if (data == null) {
      await FirebaseFirestore.instance.collection('diarios').doc(widget.diarioId).collection('recuerdos').doc(docId).update({'marcador': FieldValue.delete()});
    } else {
      await FirebaseFirestore.instance.collection('diarios').doc(widget.diarioId).collection('recuerdos').doc(docId).update({'marcador': data});
    }
  }
}