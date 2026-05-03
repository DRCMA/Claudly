import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // <--- Necesario para los formatters

class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String? get miId => FirebaseAuth.instance.currentUser?.uid;

  // --- PERSISTENCIA DE DATOS LOCALES (Para evitar parpadeos) ---
  List<DocumentSnapshot> _amigosLocal = [];
  List<DocumentSnapshot> _solicitudesLocal = [];
  bool _cargandoAmigos = true;
  bool _cargandoSolicitudes = true;
  
  // Suscripciones para cerrar al destruir si fuera necesario
  StreamSubscription? _amigosSub;
  StreamSubscription? _solicitudesSub;

  // Estados de búsqueda
  bool _buscando = false;
  Map<String, dynamic>? _usuarioEncontrado;
  String? _mensajeBusqueda;
  bool _solicitudEnviada = false;

  @override
  bool get wantKeepAlive => true; // Mantiene la pestaña de búsqueda donde la dejaste

  @override
  void initState() {
    super.initState();
    // Mantenemos el índice de la pestaña si ya existía (gracias al mixin)
    _tabController = TabController(length: 3, vsync: this);
    
    // Escuchamos los datos una sola vez y mantenemos la lista viva
    _escucharDatosRealTime();
  }

  void _escucharDatosRealTime() {
    if (miId == null) return;

    // Escuchar Amigos
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

    // Escuchar Solicitudes
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
  void dispose() {
    _amigosSub?.cancel();
    _solicitudesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Preserva el estado de scroll y tabs

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(15, 10, 15, 0),
            decoration: const BoxDecoration(
              color: Color(0xFF3E2723),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFFFD54F),
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFFFFD54F),
              indicatorWeight: 3,
              tabs: const [
                Tab(text: "AMIGOS", icon: Icon(Icons.people, size: 18)),
                Tab(text: "SOLICITUDES", icon: Icon(Icons.notifications, size: 18)),
                Tab(text: "BUSCAR", icon: Icon(Icons.person_search, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildListaAmigosFix(),
                  _buildListaSolicitudesFix(),
                  _buildTabBuscar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB AMIGOS (SIN STREAMBUILDER EN EL BUILD) ---
  Widget _buildListaAmigosFix() {
    if (_cargandoAmigos && _amigosLocal.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF3E2723)));
    }
    if (_amigosLocal.isEmpty) return _textPlaceholder("Aún no tienes amigos añadidos");

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _amigosLocal.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        var data = _amigosLocal[i].data() as Map<String, dynamic>;
        return ListTile(
          leading: CircleAvatar(
  backgroundColor: const Color(0xFF3E2723),
  // VALIDACIÓN CRÍTICA: check null y check empty
  backgroundImage: (data['photoURL'] != null && data['photoURL'].toString().isNotEmpty)
      ? NetworkImage(data['photoURL'])
      : null,
  child: (data['photoURL'] == null || data['photoURL'].toString().isEmpty)
      ? const Icon(Icons.person, color: Colors.white70)
      : null,
),
          title: Text(data['mote'] ?? "Amigo", style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
            onPressed: () => _confirmarEliminar(_amigosLocal[i].id),
          ),
        );
      },
    );
  }

  // --- TAB SOLICITUDES (SIN STREAMBUILDER EN EL BUILD) ---
  Widget _buildListaSolicitudesFix() {
    if (_cargandoSolicitudes && _solicitudesLocal.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_solicitudesLocal.isEmpty) return _textPlaceholder("No tienes solicitudes pendientes");

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _solicitudesLocal.length,
      itemBuilder: (context, i) {
        var data = _solicitudesLocal[i].data() as Map<String, dynamic>;
        return Card(
          color: Colors.indigo.withValues(alpha: 0.05),
          elevation: 0,
          child: ListTile(
            title: Text(data['emisorMote'] ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Quiere ser tu amigo"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _aceptarAmigo(_solicitudesLocal[i])),
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _solicitudesLocal[i].reference.delete()),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB BUSCAR (Se mantiene el estado de la búsqueda gracias al Mixin) ---
  Widget _buildTabBuscar() {
    return SingleChildScrollView( // Añadido para evitar errores de overflow
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("MI ID: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                SelectableText(
                  miId != null ? miId!.substring(0, 6).toUpperCase() : "---",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 18, letterSpacing: 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _buscarUsuario(),
            inputFormatters: [
               UpperCaseTextFormatter(),
               LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: "Introduce el ID de un amigo...",
              filled: true,
              fillColor: Colors.grey[50],
              suffixIcon: IconButton(icon: const Icon(Icons.search, color: Colors.indigo), onPressed: _buscarUsuario),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 30),
          if (_buscando) const CircularProgressIndicator(),
          if (_mensajeBusqueda != null && !_buscando) _textPlaceholder(_mensajeBusqueda!),
          if (_usuarioEncontrado != null && !_buscando)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12)
              ),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: _usuarioEncontrado!['photoURL'] != null ? NetworkImage(_usuarioEncontrado!['photoURL']) : null),
                title: Text(_usuarioEncontrado!['mote'] ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: Icon(_solicitudEnviada ? Icons.check_circle : Icons.person_add),
                  color: _solicitudEnviada ? Colors.grey : Colors.indigo,
                  onPressed: _solicitudEnviada ? null : () => _enviarSolicitud(_usuarioEncontrado!['uid']),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- LOS DEMÁS MÉTODOS (buscar, aceptar, eliminar) SE MANTIENEN IGUAL QUE ANTES ---
  // ... (puedes copiar los métodos _buscarUsuario, _enviarSolicitud, _aceptarAmigo y _confirmarEliminar del bloque anterior)
  
  Widget _textPlaceholder(String texto) {
    return Center(child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black38, fontFamily: 'Georgia')));
  }

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
      // Buscamos en la colección de usuarios
      // Nota: Para buscar por los primeros 6 caracteres, lo ideal es tener un campo 'codigo' en Firebase.
      // Aquí intentaremos buscar por el UID completo si el usuario lo pega.
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      
      DocumentSnapshot? userDoc;
      for (var doc in snapshot.docs) {
        // Comparamos los primeros 6 caracteres del ID
        if (doc.id.toUpperCase().startsWith(query)) {
          userDoc = doc;
          break;
        }
      }

      if (userDoc != null) {
        if (userDoc.id == miId) {
          setState(() => _mensajeBusqueda = "No puedes buscarte a ti mismo");
        } else {
          setState(() => _usuarioEncontrado = userDoc!.data() as Map<String, dynamic>?);
          // Guardamos el UID real para el envío
          _usuarioEncontrado!['uid'] = userDoc.id;
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
      // Obtenemos nuestros datos para que el receptor sepa quién somos
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

      setState(() => _solicitudEnviada = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Solicitud enviada correctamente!"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar la solicitud"))
        );
      }
    }
  }

Future<void> _aceptarAmigo(DocumentSnapshot docSolicitud) async {
  if (miId == null) return;
  
  final data = docSolicitud.data() as Map<String, dynamic>;
  final emisorId = data['emisorId'];
  final emisorMote = data['emisorMote'];
  // Nos aseguramos de tener un valor por defecto si la foto no existe
  final emisorFoto = data['emisorFoto'] ?? ""; 

  try {
    // 1. Obtener mis datos actuales (para que el otro usuario tenga mi info)
    final miDoc = await FirebaseFirestore.instance.collection('users').doc(miId).get();
    final miData = miDoc.data();
    final miMote = miData?['mote'] ?? "Amigo";
    final miFoto = miData?['photoURL'] ?? "";

    WriteBatch batch = FirebaseFirestore.instance.batch();

    // 2. Añadir emisor a MI lista de amigos
    DocumentReference miAmigoRef = FirebaseFirestore.instance
        .collection('users').doc(miId).collection('amigos').doc(emisorId);
    batch.set(miAmigoRef, {
      'mote': emisorMote,
      'photoURL': emisorFoto,
      'fecha': FieldValue.serverTimestamp(),
    });

    // 3. Añadirme a la lista de amigos del EMISOR
    DocumentReference suAmigoRef = FirebaseFirestore.instance
        .collection('users').doc(emisorId).collection('amigos').doc(miId);
    batch.set(suAmigoRef, {
      'mote': miMote,
      'photoURL': miFoto,
      'fecha': FieldValue.serverTimestamp(),
    });

    // 4. BORRAR LA SOLICITUD[cite: 3]
    batch.delete(docSolicitud.reference);

    // Ejecutar todo el lote
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Solicitud aceptada!"), backgroundColor: Colors.green)
      );
    }
  } catch (e) {
    debugPrint("Error al aceptar: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de permisos: $e"), backgroundColor: Colors.red)
      );
    }
  }
}

void _confirmarEliminar(String amigoId) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Eliminar amigo", style: TextStyle(fontFamily: 'Georgia')),
      content: const Text("¿Estás seguro? También dejaréis de compartir diarios comunes."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            Navigator.pop(ctx);
            await _ejecutarRupturaAmistad(amigoId);
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

    // 1. Borrar de mi lista
    batch.delete(FirebaseFirestore.instance.collection('users').doc(miId).collection('amigos').doc(amigoId));
    // 2. Borrar de su lista
    batch.delete(FirebaseFirestore.instance.collection('users').doc(amigoId).collection('amigos').doc(miId));

    // 3. Limpiar diarios compartidos (Lógica de seguridad)
    // Buscamos diarios donde yo soy el creador y el amigo es colaborador
    final misDiarios = await FirebaseFirestore.instance
        .collection('diarios')
        .where('userId', isEqualTo: miId)
        .where('colaboradores', arrayContains: amigoId)
        .get();

    for (var diario in misDiarios.docs) {
      batch.update(diario.reference, {
        'colaboradores': FieldValue.arrayRemove([amigoId])
      });
    }

    // Buscamos diarios donde ÉL es el creador y yo soy colaborador (para salirme yo)
    final susDiarios = await FirebaseFirestore.instance
        .collection('diarios')
        .where('userId', isEqualTo: amigoId)
        .where('colaboradores', arrayContains: miId)
        .get();

    for (var diario in susDiarios.docs) {
      batch.update(diario.reference, {
        'colaboradores': FieldValue.arrayRemove([miId])
      });
    }

    await batch.commit();
  } catch (e) {
    debugPrint("Error al eliminar amigo: $e");
  }
}
}
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Retorna el nuevo valor pero forzando mayúsculas
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}