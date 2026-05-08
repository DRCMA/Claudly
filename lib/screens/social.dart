import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/config_controller.dart';
import '../services/notification_service.dart';

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
    // Listener manual: fuerza setState aunque la tab esté en keepAlive
    ConfigController.darkModeListenable.addListener(_onDarkModeChanged);
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ConfigController.darkModeListenable.removeListener(_onDarkModeChanged);
    _amigosSub?.cancel();
    _solicitudesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
      // Stack para poner el puntito rojo sobre el icono
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
      const SizedBox(height: 2), // Espacio pequeño entre icono y texto
      const Text(
        "SOLICITUDES",
        style: TextStyle(fontSize: 10), // Ajusta según tu diseño
      ),
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty)
                ? NetworkImage(data['photoURL'])
                : null,
            child: (data['photoURL'] == null || data['photoURL'].toString().isEmpty)
                ? Icon(Icons.person, color: iconColor)
                : null,
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white10,
            backgroundImage: (data['emisorFoto'] != null && data['emisorFoto'].toString().isNotEmpty)
                ? NetworkImage(data['emisorFoto'])
                : null,
            child: (data['emisorFoto'] == null || data['emisorFoto'].toString().isEmpty)
                ? Icon(Icons.person, color: iconColor)
                : null,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
                  backgroundImage: _usuarioEncontrado!['photoURL'] != null 
                    ? NetworkImage(_usuarioEncontrado!['photoURL']) 
                    : null,
                  child: _usuarioEncontrado!['photoURL'] == null ? const Icon(Icons.person) : null,
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
          setState(() {
            _usuarioEncontrado = userDoc!.data() as Map<String, dynamic>?;
            _usuarioEncontrado!['uid'] = userDoc.id;
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