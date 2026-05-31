import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/config_controller.dart';
import '../services/notification_service.dart';
import '../services/local_alarm_service.dart';

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String? get miId => FirebaseAuth.instance.currentUser?.uid;

  List<DocumentSnapshot> _amigosLocal = [];
  List<DocumentSnapshot> _solicitudesLocal = [];
  bool _cargandoAmigos = true;
  bool _cargandoSolicitudes = true;
  StreamSubscription? _amigosSub;
  StreamSubscription? _solicitudesSub;

  bool _buscando = false;
  Map<String, dynamic>? _usuarioEncontrado;
  String? _mensajeBusqueda;
  bool _solicitudEnviada = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _escucharDatosRealTime();
    
    // Listeners para actualizar estados globales y limpiar búsquedas
    ConfigController.darkModeListenable.addListener(_onDarkModeChanged);
    _tabController.addListener(_onTabChanged);
    _searchController.addListener(_onSearchTextChanged);
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  // Se activa al cambiar de pestaña en el menú social
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _limpiarEstadoBusqueda(borrarTexto: true);
    }
  }

  // Se activa cada vez que el usuario escribe o borra una letra
  void _onSearchTextChanged() {
    if (_usuarioEncontrado != null || _mensajeBusqueda != null) {
      _limpiarEstadoBusqueda(borrarTexto: false);
    }
  }

  void _limpiarEstadoBusqueda({required bool borrarTexto}) {
    if (mounted) {
      setState(() {
        if (borrarTexto) _searchController.clear();
        _usuarioEncontrado = null;
        _mensajeBusqueda = null;
        _solicitudEnviada = false;
      });
    }
  }

  @override
  void dispose() {
    ConfigController.darkModeListenable.removeListener(_onDarkModeChanged);
    _tabController.removeListener(_onTabChanged);
    _searchController.removeListener(_onSearchTextChanged);
    _amigosSub?.cancel();
    _solicitudesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

ImageProvider? _obtenerImagenPerfil(String? ruta) {
    if (ruta == null || ruta.trim().isEmpty) return null;

    // 1. Si es un enlace de internet (ej. Google, Firebase Storage)
    if (ruta.startsWith('http') || ruta.startsWith('https')) {
      return NetworkImage(ruta);
    } 
    
    // 2. Si es una imagen local predeterminada de la app
    // Nota: Si en base de datos solo guardaste "toumáquet.png", 
    // aquí le añadimos la carpeta donde suela estar (por ejemplo 'assets/')
    String rutaFinal = ruta.contains('/') ? ruta : 'assets/$ruta';
    
    return AssetImage(rutaFinal);
  }

  void _escucharDatosRealTime() {
    if (miId == null) return;
    _amigosSub = FirebaseFirestore.instance
        .collection('users')
        .doc(miId)
        .collection('amigos')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _amigosLocal = snapshot.docs;
          _cargandoAmigos = false;
        });
      }
    });

    _solicitudesSub = FirebaseFirestore.instance
        .collection('solicitudes')
        .where('receptorId', isEqualTo: miId)
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snapshot) {

    if (!_cargandoSolicitudes) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            final nombrePeticion = data?['nombre'] ?? 'Alguien';
            
            LocalAlarmService.mostrarNotificacionInstantanea(
              id: change.doc.id.hashCode.abs() % 2147483647,
              titulo: '¡Nueva solicitud de amistad!',
              cuerpo: '$nombrePeticion quiere ser tu amigo!!',
            );
          }
        }
      }
      if (mounted) {
        setState(() {
          _solicitudesLocal = snapshot.docs;
          _cargandoSolicitudes = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDark = ConfigController.isDarkMode;
    final Color cardColor = ConfigController.getBrownDark();
    final Color iconColor = ConfigController.getIconColor();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // --- CABECERA DE PESTAÑAS ---
          Container(
            margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFFD54F),
              unselectedLabelColor: Colors.white60,
              indicatorColor: const Color(0xFFFFD54F),
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              tabs: [
                const Tab(text: "AMIGOS", icon: Icon(Icons.people, size: 18)),
                Tab(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications, size: 18),
                          if (_solicitudesLocal.isNotEmpty)
                            Positioned(
                              right: -8,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 14,
                                  minHeight: 14,
                                ),
                                child: Text(
                                  "${_solicitudesLocal.length}",
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text("SOLICITUDES", style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                const Tab(text: "BUSCAR", icon: Icon(Icons.person_search, size: 18)),
              ],
            ),
          ),

          // --- CUERPO ---
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              decoration: BoxDecoration(
                color: isDark ? cardColor : cardColor.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildListaAmigosFix(iconColor),
                  _buildListaSolicitudesFix(iconColor),
                  _buildTabBuscar(cardColor, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES DE LISTAS ---

  Widget _buildListaAmigosFix(Color iconColor) {
    if (_cargandoAmigos && _amigosLocal.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    if (_amigosLocal.isEmpty) return _textPlaceholder("Aún no tienes amigos añadidos");
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _amigosLocal.length,
      separatorBuilder: (_, _) => Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
      itemBuilder: (context, i) {
        var data = _amigosLocal[i].data() as Map<String, dynamic>;
        String? foto = data['photoURL']?.toString();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: _obtenerImagenPerfil(foto),
            child: _obtenerImagenPerfil(foto) == null ? Icon(Icons.person, color: iconColor) : null,
          ),
          title: Text(
            data['mote'] ?? "Amigo", 
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
          ),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () => _confirmarEliminar(_amigosLocal[i].id),
          ),
        );
      },
    );
  }

 Widget _buildListaSolicitudesFix(Color iconColor) {
    if (_cargandoSolicitudes && _solicitudesLocal.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    if (_solicitudesLocal.isEmpty) return _textPlaceholder("No tienes solicitudes pendientes");
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _solicitudesLocal.length,
      itemBuilder: (context, i) {
        var data = _solicitudesLocal[i].data() as Map<String, dynamic>;
        String? foto = data['emisorFoto']?.toString();

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: _obtenerImagenPerfil(foto),
            child: _obtenerImagenPerfil(foto) == null ? Icon(Icons.person, color: iconColor) : null,
          ),
          title: Text(
            data['emisorMote'] ?? "Usuario",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                onPressed: () => _aceptarAmigo(_solicitudesLocal[i]),
              ),
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                onPressed: () async {
                  await _solicitudesLocal[i].reference.delete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

Widget _buildTabBuscar(Color cardColor, bool isDark) {
    final String miSocialId = (miId != null && miId!.length >= 6) 
        ? miId!.substring(0, 6).toUpperCase() 
        : (miId ?? "");

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // (Tu código de GestureDetector para copiar el ID sigue igual...)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: miSocialId));
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("¡ID Copiado al portapapeles! 📋"))
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy, size: 14, color: Color(0xFFFFD54F)),
                  const SizedBox(width: 8),
                  Text(
                    "Mi ID Social: $miSocialId",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          TextField(
            controller: _searchController,
            onSubmitted: (_) => _buscarUsuario(),
            inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(6)],
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Introduce el ID de un amigo...",
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.1),
              suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: _buscarUsuario),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 30),
          if (_buscando) const CircularProgressIndicator(color: Colors.white70),
          if (_mensajeBusqueda != null && !_buscando) _textPlaceholder(_mensajeBusqueda!),
          if (_usuarioEncontrado != null && !_buscando)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12)
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white10,
                  backgroundImage: _obtenerImagenPerfil(_usuarioEncontrado!['photoURL']?.toString()),
                  child: _obtenerImagenPerfil(_usuarioEncontrado!['photoURL']?.toString()) == null 
                      ? const Icon(Icons.person) 
                      : null,
                ),
                title: Text(_usuarioEncontrado!['mote'] ?? "Usuario", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: Icon(_solicitudEnviada ? Icons.check_circle : Icons.person_add),
                  color: _solicitudEnviada ? Colors.greenAccent : Colors.white,
                  onPressed: _solicitudEnviada ? null : () => _enviarSolicitud(_usuarioEncontrado!['uid']),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _textPlaceholder(String texto) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontFamily: 'Georgia')),
      ),
    );
  }

  // --- LÓGICA DE FIREBASE ---

  Future<void> _buscarUsuario() async {
    String query = _searchController.text.trim().toUpperCase();
    if (query.isEmpty) return;

    setState(() {
      _buscando = true;
      _mensajeBusqueda = null;
      _usuarioEncontrado = null;
      _solicitudEnviada = false;
    });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      DocumentSnapshot? userDoc;
      for (var doc in snapshot.docs) {
        if (doc.id.toUpperCase().startsWith(query)) {
          userDoc = doc;
          break;
        }
      }

      if (userDoc != null) {
        if (userDoc.id == miId) {
          setState(() => _mensajeBusqueda = "No puedes buscarte a ti mismo");
        } else {
          // 1. Validamos primero si ya es tu amigo actualmente
          final amigoDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(miId)
              .collection('amigos')
              .doc(userDoc.id)
              .get();

          if (amigoDoc.exists) {
            setState(() => _mensajeBusqueda = "Este usuario ya es tu amigo");
            return;
          }

          // 2. Validamos si hay una petición activa pendiente de resolver
          final reqCheck = await FirebaseFirestore.instance
              .collection('solicitudes')
              .where('emisorId', isEqualTo: miId)
              .where('receptorId', isEqualTo: userDoc.id)
              .where('estado', isEqualTo: 'pendiente')
              .get();

          setState(() {
            _usuarioEncontrado = userDoc!.data() as Map<String, dynamic>?;
            _usuarioEncontrado!['uid'] = userDoc.id;
            _solicitudEnviada = reqCheck.docs.isNotEmpty; // Si existe, bloquea el botón en true
          });
        }
      } else {
        setState(() => _mensajeBusqueda = "Usuario no encontrado");
      }
    } catch (e) {
      setState(() => _mensajeBusqueda = "Error en la búsqueda");
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _enviarSolicitud(String receptorId) async {
    if (miId == null) return;
    try {
      final miDoc = await FirebaseFirestore.instance.collection('users').doc(miId).get();
      final miData = miDoc.data();
      await FirebaseFirestore.instance.collection('solicitudes').add({
        'emisorId': miId,
        'emisorMote': miData?['mote'] ?? "Usuario",
        'emisorFoto': miData?['photoURL'] ?? "",
        'receptorId': receptorId,
        'estado': 'pendiente',
        'fecha': FieldValue.serverTimestamp(),
      });
      await NotificationService.enviarNotificacionPush(
        receptorUid: receptorId,
        titulo: "Nueva solicitud",
        cuerpo: "${miData?['mote'] ?? 'Alguien'} quiere ser tu amigo.",
      );
      if (!mounted) return;
      setState(() => _solicitudEnviada = true);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Solicitud enviada!"))
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al enviar"))
      );
    }
  }

  Future<void> _aceptarAmigo(DocumentSnapshot docSolicitud) async {
    if (miId == null) return;
    final data = docSolicitud.data() as Map<String, dynamic>;
    final emisorId = data['emisorId'];
    try {
      final miDoc = await FirebaseFirestore.instance.collection('users').doc(miId).get();
      final miData = miDoc.data();

      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('users').doc(miId).collection('amigos').doc(emisorId), {
        'mote': data['emisorMote'],
        'photoURL': data['emisorFoto'] ?? "",
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.set(FirebaseFirestore.instance.collection('users').doc(emisorId).collection('amigos').doc(miId), {
        'mote': miData?['mote'] ?? "Amigo",
        'photoURL': miData?['photoURL'] ?? "",
        'fecha': FieldValue.serverTimestamp(),
      });
      batch.delete(docSolicitud.reference);
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Solicitud aceptada!"), backgroundColor: Colors.green)
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al aceptar"))
      );
    }
  }

  void _confirmarEliminar(String amigoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar amigo"),
        content: const Text("¿Estás seguro? Dejaréis de compartir diarios comunes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              _ejecutarRupturaAmistad(amigoId);
            }, 
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarRupturaAmistad(String amigoId) async {
    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.delete(FirebaseFirestore.instance.collection('users').doc(miId).collection('amigos').doc(amigoId));
      batch.delete(FirebaseFirestore.instance.collection('users').doc(amigoId).collection('amigos').doc(miId));
      await batch.commit();
    } catch (e) {
      debugPrint("Error al eliminar: $e");
    }
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}