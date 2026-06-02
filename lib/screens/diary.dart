import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:page_flip/page_flip.dart';
import '../services/storage_service.dart';
import '../services/config_controller.dart';
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

    ConfigController.darkModeListenable.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});

  }

  @override
  void dispose() {
    ConfigController.darkModeListenable.removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();

  }

  void _ejecutarRefrescoYSalto(int pagina) {
    if (!mounted) return;

    setState(() {
      _saltandoAlFinal = true;
      _pageFlipKey = GlobalKey<PageFlipWidgetState>();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final state = _pageFlipKey.currentState;
        if (state != null) {
          try {
            state.goToPage(pagina);
          } catch (e) {
            debugPrint("Fallo captura PageFlip: $e");
           }
        }
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
    final int ultimaPagina = _estaBuscando ?

 _totalDocs - 1 : _totalDocs;
    _ejecutarRefrescoYSalto(ultimaPagina);
  }

  Future<void> _abrirEditor({String? docId, Map<String, dynamic>? datosIniciales}) async {
    final int paginaActual = _pageFlipKey.currentState?.pageNumber ??

 0;
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
    final bool isDark = ConfigController.isDarkMode;

    final Color headerColor = ConfigController.getHeaderColor();
    const Color folioColor = Color(0xFFFFFDE7);
    const Color bgColor = Color(0xFFD7CCC8);

    return Container(
      color: Colors.black, // Franja negra para la barra de estado del sistema
      child: SafeArea(
        bottom: false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: headerColor,
             elevation: 1,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            title: _estaBuscando
                ? TextField(
                    controller: _searchController,
                     autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Buscar...",
                      hintStyle: TextStyle(color: Colors.white54),
                       border: InputBorder.none,
                    ),
                    onChanged: (val) => setState(() {
                      _pageFlipKey = GlobalKey<PageFlipWidgetState>();

}),
                  )
                : Text(
                    widget.nombreDiario,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
            actions: [
                IconButton(
                icon: Icon(_estaBuscando ? Icons.close : Icons.search, color: Colors.white),
                onPressed: () => setState(() {
                  _estaBuscando = !_estaBuscando;
                  if (!_estaBuscando) _searchController.clear();
                   _pageFlipKey = GlobalKey<PageFlipWidgetState>();
                }),
              ),
              if (!_estaBuscando)
                IconButton(
                  icon: const Icon(Icons.last_page, color: Colors.white),
                   onPressed: _irAlFinal,
                ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _recuerdosStream,
            builder: (context, snapshot) {
                if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());

}

              _currentDocs = snapshot.data!.docs;

              final String currentHash = _currentDocs
                  .map((d) => d.id + d.data().toString().hashCode.toString())
                  .join();

              // --- NUEVA LÓGICA DE PRECARGA INTELIGENTE ---
              if (_primeraCarga) {
                if (_currentDocs.isNotEmpty) {
                  final primerDoc = _currentDocs.first.data() as Map<String, dynamic>;
                  final fondo = primerDoc['fondo'] ?? 'paper';
                  final assetPath = 'assets/background/$fondo.jpg';

                  List<Future<void>> precargaTareas = [
                    // 1. Precargar el fondo del primer recuerdo
                    precacheImage(AssetImage(assetPath), context)
                  ];

                  // 2. Precargar las fotos de red que pueda tener el primer recuerdo
                  List elementos = primerDoc['elementos'] ?? [];
                  for (var item in elementos) {
                    if ((item['tipo'] == 'foto' || item['tipo'] == 'imagen') && item['url'] != null) {
                      precargaTareas.add(precacheImage(CachedNetworkImageProvider(item['url']), context));
                    }
                  }

                  // 3. Ejecutar la precarga en memoria y esperar
                  Future.wait(precargaTareas).then((_) {
                    if (mounted && _primeraCarga) {
                      setState(() {
                        _primeraCarga = false;
                        _lastDataHash = currentHash;
                      });
                      _ejecutarRefrescoYSalto(0);
                    }
                  }).catchError((_) {
                    if (mounted && _primeraCarga) {
                      setState(() {
                        _primeraCarga = false;
                        _lastDataHash = currentHash;
                      });
                      _ejecutarRefrescoYSalto(0);
                    }
                  });

                  // MIENTRAS PRECARGA: Mostramos el loader para tapar el efecto fantasma
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: folioColor,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.brown),
                                SizedBox(height: 20),
                                Text("Preparando diario...",
                                    style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 16,
                                        color: Colors.brown)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Si no hay recuerdos, simplemente liberamos la carga
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _primeraCarga) {
                      setState(() {
                        _primeraCarga = false;
                        _lastDataHash = currentHash;
                      });
                      _ejecutarRefrescoYSalto(0);
                    }
                  });
                }
              } else {
                // --- LÓGICA ORIGINAL DE EDICIÓN Y HASHES ---
                if (currentHash != _lastDataHash) {
                  _lastDataHash = currentHash;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_hashEsperado != null) {
                      int destino;
                      if (_paginaAlVolver == -1) {
                        destino = _currentDocs.isNotEmpty ? _currentDocs.length - 1 : 0;
                      } else {
                        destino = _paginaAlVolver ?? 0;
                      }
                      _ejecutarRefrescoYSalto(destino);
                    }
                  });
                }
              }

              // --- FILTRADO ORIGINAL ---
              final recuerdosFiltrados = _currentDocs.where((doc) {
                if (!_estaBuscando || _searchController.text.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final fecha = DateFormat('dd/MM/yyyy').format((data['fecha'] as Timestamp).toDate());
                final marcador 
 = data['marcador']?['texto']?.toString().toLowerCase() ?? '';
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
                // Modo normal: siempre añade la hoja de "Nuevo recuerdo" al final
                hojasDelLibro.add(Container(
                  key: const ValueKey("leaf_new_page"),
                  child: _buildHojaEnBlanco(),
                ));

              } else if (hojasDelLibro.isEmpty) {
                // Modo búsqueda: Solo añadimos relleno si NO se ha encontrado NADA
                hojasDelLibro.add(Container(
                  key: const ValueKey("leaf_search_filler"),
                  color: folioColor,
                  child: Center(
                    child: Opacity(
                        opacity: 0.2,
                      child: Icon(Icons.menu_book, size: 50,
                          color: isDark ? Colors.white : Colors.brown),
                    ),
                   ),
                ));

              }
              // NOTA: Si estamos buscando y SÍ hay resultados, el código no añade ninguna
              // hoja extra al final. El libro termina en el último recuerdo exactamente.
              return Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: folioColor,
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
                        color: folioColor,
                        child: const Center(
                          child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.brown),
                              SizedBox(height: 20),
                               Text("Abriendo diario...",
                                  style: TextStyle(
                                      fontFamily: 'Georgia',
                                      fontStyle: FontStyle.italic,
                                      fontSize: 16,
                                       color: Colors.brown)),
                            ],
                          ),
                        ),
                   ),
                    ),
                ],
              );

},
          ),
        ),
      ),
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
          color: const Color(0xFFFFFDE7), // <-- ESTE ES EL ESCUDO OPACO. Evita el "fantasma" 100% de la segunda página.
          image: DecorationImage(
              image: AssetImage('assets/background/$fondo.jpg'), fit: BoxFit.cover),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: 

 Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Stack(
                  children: elementos
                      .map((item) => Positioned(
                             left: (item['x'] as num? ?? 0.0).toDouble(),
                            top: (item['y'] as num? ?? 0.0).toDouble(),
                            child: _buildElementoEstatico(item),
                          
))
                      .toList(),
                ),
              ),
            ),
            if (marcador != null) _buildPostIt(marcador),
            Padding(
               padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 25.0),
                     child: Text(
                      DateFormat('dd/MM/yyyy').format(fechaDt),
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[700],
                        fontSize: ConfigController.getAdaptedSize(13),
                      ),
                     ),
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
    final int color = marcador['color'] ?? 0xFFFFF176;
    final String texto = marcador['texto']?.toString().toUpperCase() ?? '';

    // Mapa de color → asset PNG del post-it
    const Map<int, String> postItAssets = {
      0xFFCCFF90: 'assets/post-its/post-itGreen.png',
      0xFF80D8FF: 'assets/post-its/post-itBlue.png',
      0xFFFF8A80: 'assets/post-its/post-itRed.png',
      0xFFFFF176: 'assets/post-its/post-itYellow.png'
    };
    final String? asset = postItAssets[color];

    return Positioned(
      top: -10, // Ajustado para que cuelgue de forma natural desde el borde
      right: 50,
      child: GestureDetector(
        onTap: () {
          // --- VENTANITA EMERGENTE AL PULSAR ---
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Color(color), // El fondo toma el color del marcador
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.all(25),
              content: Text(
                texto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          );
        },
        child: Transform.rotate(
          angle: -96.0, // <-- Totalmente recto, sin inclinación
          child: asset != null
              // ── MARCADOR CON IMAGEN PNG (Vacío) ──────────────────────────
              ? SizedBox(
                  width: 50,  // Reducido un poco para que quede estético al no tener texto
                  height: 60,
                  child: Image.asset(
                    asset,
                    fit: BoxFit.fill,
                  ),
                )
              // ── MARCADOR CON RECTÁNGULO DE COLOR (Vacío) ─────────────────
              : Container(
                  width: 35,  // Ancho fijo del marcador
                  height: 55, // Largo fijo del marcador
                  decoration: BoxDecoration(
                    color: Color(color),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)), // Bordes inferiores suaves
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

Widget _buildElementoEstatico(Map<String, dynamic> item) {
    final double angulo = (item['angulo'] ?? item['rotacion'] ?? 0.0).toDouble();
    final double anchoReal = (item['ancho'] as num? ?? (item['tipo'] == 'sticker' ? 100.0 : 150.0)).toDouble();
    // TransformableElement envuelve el child con padding: EdgeInsets.all(10).
    // En diary no existe ese wrapper, así que lo replicamos con un Padding
    // para que el tamaño visual sea idéntico al del editor.
    const double paddingTransformable = 10.0;

    // 1. SI ES FOTO O IMAGEN
    if (item['tipo'] == 'foto' || item['tipo'] == 'imagen') {
      final String pieFoto = item['pieFoto'] ?? "";
      final bool tieneTexto = pieFoto.isNotEmpty;
      final double anchoImagen = anchoReal - 16 - 4; // padding interno (8+8) + borde (2+2)

      return Transform.rotate(
        angle: angulo,
        child: Padding(
          padding: const EdgeInsets.all(paddingTransformable),
          child: Container(
            width: anchoReal,
            padding: EdgeInsets.fromLTRB(8, 8, 8, tieneTexto ? 20 : 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: Colors.transparent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CachedNetworkImage(
                  imageUrl: item['url'] ?? "",
                  width: anchoImagen,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                ),
                if (tieneTexto)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      pieFoto,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    // 2. SI ES STICKER
    else if (item['tipo'] == 'sticker') {
      return Transform.rotate(
        angle: angulo,
        child: Padding(
          padding: const EdgeInsets.all(paddingTransformable),
          child: Container(
            width: anchoReal,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.transparent, width: 2),
            ),
            child: Image.asset(
              item['rutaAsset'] ?? 'assets/stickers/Fiso.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    // 3. SI ES TEXTO
    final double anchoTexto = (item['ancho'] ?? 200.0).toDouble();

    return Transform.rotate(
      angle: angulo,
      child: Padding(
        padding: const EdgeInsets.all(paddingTransformable),
        child: Container(
          width: anchoTexto,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
      ),
    );
  }


  Widget _buildHojaEnBlanco() {
    final bool isDark = ConfigController.isDarkMode;

    return GestureDetector(
      onTap: () => _abrirEditor(),
      child: Container(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 80,
                   color: isDark ? Colors.white24 : Colors.grey),
              Text("Nuevo recuerdo",
                  style: TextStyle(
                      fontFamily: 'Georgia',
                      color: isDark ? Colors.white38 : Colors.grey)),
            ],
          ),
        ),
      ),
    );
}

  Widget _buildMenu(String docId, Map<String, dynamic> data, List elementos) {
    Map<String, dynamic>? marcador = data['marcador'];

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
      onSelected: (val) {
        if (val == 'edit') _abrirEditor(docId: docId, datosIniciales: data);
        if (val == 'delete') _confirmarBorrado(docId, elementos);
        if (val == 'marcador') _gestionMarcadorDialog(docId, marcador);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'marcador',
           child: Row(children: [
            Icon(marcador == null ? Icons.bookmark_add : Icons.edit_attributes,
                color: Colors.orange),
            const SizedBox(width: 8),
            Text(marcador == null ? "Añadir Marcador" : "Editar Marcador"),
          ]),
        ),
         const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text("Editar Hoja")
            ])),
        const PopupMenuItem(
             value: 'delete',
            child: Row(children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text("Borrar Hoja")
            ])),
      ],
    );

}

void _confirmarBorrado(String docId, List elementos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar este recuerdo?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          TextButton(
             onPressed: () async {
              Navigator.pop(ctx);
              
              // 1. PREPARAMOS EL ESTADO ANTES DE CUALQUIER AWAIT
              // Así, cuando el StreamBuilder se dispare, ya sabrá qué estamos esperando.
               setState(() {
                _saltandoAlFinal = true;
                _paginaAlVolver = 0; // Volvemos a la portada tras borrar
                _hashEsperado = 'borrado';
              });

              try {
                 // 2. Borramos de Storage primero
                for (var item in elementos) {
                  if ((item['tipo'] == 'foto' || item['tipo'] == 'imagen') &&
                      item['url'] != null) {
                     await _storageService.borrarArchivo(item['url']);
                  }
                }
                
                // 3. Borramos de Firestore
                await FirebaseFirestore.instance
                    .collection('diarios')
                   .doc(widget.diarioId)
                    .collection('recuerdos')
                    .doc(docId)
                    .delete();

} catch (e) {
                // Si algo falla catastróficamente, quitamos la pantalla de carga
                debugPrint("Error al eliminar: $e");

if (mounted) {
                  setState(() => _saltandoAlFinal = false);

}
              }
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

}

  void _gestionMarcadorDialog(String docId, Map<String, dynamic>? marcadorActual) async {
    final query = await FirebaseFirestore.instance
        .collection('diarios')
        .doc(widget.diarioId)
        .collection('recuerdos')
        .where('marcador', isNull: false)
        .limit(15)
        .get();

    Set<String> sugerencias = query.docs
        .map((d) => (d.data())['marcador']?['texto']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet();

    TextEditingController txtCtrl =
        TextEditingController(text: marcadorActual?['texto'] ?? "");

    final List<int> misColores = [
      0xFFFFF176, 0xFFFF8A80, 0xFF80D8FF, 0xFFCCFF90
    ];

    int colorSeleccionado = marcadorActual?['color'] ?? misColores[0];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
              marcadorActual == null ? "Añadir Marcador" : "Editar Marcador",
              style: const TextStyle(fontFamily: 'Georgia')),
          content: Column(
             mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: txtCtrl,
                maxLength: 14,
                decoration: const InputDecoration(
                  hintText: "Nombre...",
                  counterStyle: TextStyle(fontSize: 11, color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.brown),
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const 
 SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: misColores
                    .map((color) => GestureDetector(
                          onTap: () =>
                               setDialogState(() => colorSeleccionado = color),
                          child: Container(
                            width: 35,
                   height: 35,
                            decoration: BoxDecoration(
                              color: Color(color),
                               shape: BoxShape.circle,
                              border: Border.all(
                                  color: colorSeleccionado == color
                                       ?

 Colors.black87
                                      : Colors.transparent,
                                  width: 2),
                             ),
                          ),
                        ))
                    .toList(),
              ),
              
 if (sugerencias.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text("Sugerencias:",
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                   spacing: 8,
                  runSpacing: 4,
                  children: sugerencias
                      .take(5)
                      .map((s) => ActionChip(
                            label: Text(s,
                                style: const TextStyle(fontSize: 10)),
                            onPressed: () =>
                                 setDialogState(() => txtCtrl.text = s),
                          ))
                      .toList(),
                ),
               ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            if (marcadorActual != null)
              TextButton(
                onPressed: () => _confirmarEliminarMarcador(docId),
                 child: const Text("Eliminar",
                    style: TextStyle(color: Colors.redAccent)),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                 TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.brown),
                  onPressed: () {
                    String nuevoTexto = txtCtrl.text.toUpperCase();

if (marcadorActual != null &&
                        marcadorActual['texto'] == nuevoTexto &&
                        marcadorActual['color'] == colorSeleccionado) {
                      Navigator.pop(ctx);

return;
                    }
                    Navigator.pop(ctx);

_aplicarCambioMarcador(
                        docId, {'texto': nuevoTexto, 'color': colorSeleccionado});

},
                  child: const Text("Guardar",
                      style: TextStyle(color: Colors.white)),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          TextButton(
             onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              _aplicarCambioMarcador(docId, null);
            },
            child: const Text("Eliminar",
                style: TextStyle(color: Colors.red)),
           ),
        ],
      ),
    );

}

  void _aplicarCambioMarcador(
      String docId, Map<String, dynamic>? data) async {
    setState(() {
      _saltandoAlFinal = true;
      _hashEsperado = 'pendiente_$docId';
      _paginaAlVolver = _pageFlipKey.currentState?.pageNumber;
    });

if (data == null) {
      await FirebaseFirestore.instance
          .collection('diarios')
          .doc(widget.diarioId)
          .collection('recuerdos')
          .doc(docId)
          .update({'marcador': FieldValue.delete()});

} else {
      await FirebaseFirestore.instance
          .collection('diarios')
          .doc(widget.diarioId)
          .collection('recuerdos')
          .doc(docId)
          .update({'marcador': data});

}
  }
}