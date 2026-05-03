import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../services/auth_service.dart';
import '../services/config_controller.dart';
import 'settings.dart'; 
import 'diary.dart';
import 'wall.dart';
import 'package:flutter/services.dart'; 
import 'scrapbook_wrapper.dart';
import 'profile.dart'; 
import 'social.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final AuthService _authService = AuthService();
  final TextEditingController _nombreDiarioController = TextEditingController();

@override
void initState() {
  super.initState();
  _pageController = PageController(initialPage: _selectedIndex);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (FirebaseAuth.instance.currentUser == null) {
      _buildLoginScreen();
    }
  });
}

  @override
  void dispose() {
    _pageController.dispose();
    _nombreDiarioController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }
  // --- MÉTODOS DE GESTIÓN DE DIARIOS ---

  void _crearDiarioFlow(User? user) {
  if (user == null) {
    _buildLoginScreen();
    return;
  }
  _nombreDiarioController.clear();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Nuevo Diario", style: TextStyle(fontFamily: 'Georgia')),
      content: TextField(
  controller: _nombreDiarioController, // Tu controlador actual
  // 1. Muestra u oculta el contador (Flutter lo maneja automáticamente)
  maxLength: 20, 
  // 2. Fuerza a nivel de entrada que el usuario no pueda seguir tecleando
  inputFormatters: [
    LengthLimitingTextInputFormatter(20),
  ],
  style: TextStyle(fontSize: ConfigController.getAdaptedSize(16)), // Ajusta a tu estilo
  decoration: InputDecoration(
    hintText: "Nombre del diario...",
    // Opcional: Si pones counterText vacío, el contador "0/20" desaparecerá visualmente,
    // pero el límite de 20 caracteres seguirá funcionando perfectamente.
    // counterText: "", 
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          onPressed: () async {
            String nombreLimpio = _nombreDiarioController.text.trim();
if (nombreLimpio.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El nombre del diario no puede estar vacío"),
          backgroundColor: Colors.orange,
        ),
      );
      return; // El 'return' detiene la ejecución aquí
    }
if (nombreLimpio.length > 20) {
  // (Por seguridad extra, aunque el TextField ya lo limita)
  nombreLimpio = nombreLimpio.substring(0, 20);
}

            String nombre = _nombreDiarioController.text.trim();
            if (nombre.isEmpty) return;

            try {
              // 1. CONSULTA DE LÍMITE
              final snapshot = await FirebaseFirestore.instance
                  .collection('diarios')
                  .where('userId', isEqualTo: user.uid)
                  .get();

              // --- CORRECCIÓN AQUÍ ---
              // Primero verificamos si el diálogo (dialogContext) sigue vivo
              if (!dialogContext.mounted) return;

              if (snapshot.docs.length >= 10) {
                Navigator.pop(dialogContext); 
                
                // Luego verificamos si la página principal (context de la State) sigue viva para el SnackBar
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Límite alcanzado: máximo 10 diarios por usuario."),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
                return;
              }

              // 2. CREACIÓN
              await FirebaseFirestore.instance.collection('diarios').add({
                'nombre': nombre,
                'userId': user.uid,
                'colaboradores': [FirebaseAuth.instance.currentUser!.uid],
                'fechaCreacion': FieldValue.serverTimestamp(),
                'ultimaActividad': FieldValue.serverTimestamp(),
              });

              // --- CORRECCIÓN AQUÍ ---
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            } catch (e) {
              // Verificamos antes de mostrar el error
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error al crear diario: $e")),
                );
              }
            }
          },
          child: const Text("Crear", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _renombrarDiario(String id, String nombreActual) {
    _nombreDiarioController.text = nombreActual;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Renombrar Diario"),
        content: TextField(controller: _nombreDiarioController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              if (_nombreDiarioController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('diarios').doc(id).update({'nombre': _nombreDiarioController.text});
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _eliminarDiario(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar diario?"),
        content: const Text("Se borrarán todos los datos permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NO")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('diarios').doc(id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("SÍ", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarBuscadorAmigos(String diarioId) {
    String filtro = "";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Añadir participante"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: "Buscar amigo...", prefixIcon: Icon(Icons.search)),
                  onChanged: (val) => setDialogState(() => filtro = val.toLowerCase()),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .collection('amigos')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      var amigos = snapshot.data!.docs.where((doc) {
                        String mote = (doc.data() as Map)['mote']?.toString().toLowerCase() ?? "";
                        return mote.contains(filtro);
                      }).toList();

                      if (amigos.isEmpty) return const Padding(padding: EdgeInsets.all(8.0), child: Text("No se encontraron amigos"));

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: amigos.length,
                        itemBuilder: (itemCtx, i) {
                          var data = amigos[i].data() as Map;
                          return ListTile(
                            leading: CircleAvatar(backgroundImage: data['photoUrl'] != null ? NetworkImage(data['photoUrl']) : null),
                            title: Text(data['mote'] ?? "Amigo"),
onTap: () async {
  final String amigoUID = amigos[i].id;
  final String miNombre = FirebaseAuth.instance.currentUser?.displayName ?? "Un amigo";

  // 1. Guardamos el Messenger ANTES del await
  final messenger = ScaffoldMessenger.of(context); 
  // 2. Guardamos el Navigator ANTES si queremos ser extra precavidos, 
  // pero usaremos el chequeo de mounted que es más estándar.

  try {
    await FirebaseFirestore.instance.collection('diarios').doc(diarioId).update({
      'invitados': FieldValue.arrayUnion([amigoUID]),
      'invitadoPorNombre': miNombre,
    });

    // 3. Chequeamos si el contexto sigue "vivo" antes de navegar
    // Usamos 'ctx' porque es el contexto del diálogo (StatefulBuilder)
    if (ctx.mounted) {
      Navigator.pop(ctx);
    }

    // 4. Usamos la referencia guardada para el SnackBar[cite: 4]
    // Esto funciona incluso si el diálogo se cerró
    messenger.showSnackBar(
      const SnackBar(
        content: Text("¡Invitación enviada!"), 
        backgroundColor: Colors.green
      )
    );
  } catch (e) {
    debugPrint("Error: $e");
  }
},
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
Widget _buildLoginScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFBC9A73),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text("CLAUD", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Text("Tu diario privado y compartido. Inicia sesión para continuar.", 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, 
                foregroundColor: Colors.brown,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
              onPressed: () => _authService.signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: const Text("ENTRAR CON GOOGLE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;

        // SI NO HAY USUARIO: Mostramos la pantalla de bienvenida directamente
        if (user == null) {
          return _buildLoginScreen();
        }

        // SI HAY USUARIO: Mostramos la app normal
        return Container(
          color: Colors.black,
          child: SafeArea(
            bottom: false,
            child: ScrapbookWrapper(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: const Color(0xFF3E2723),
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: const Text("Claud", style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
                  actions: [
                    if (user.photoURL != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: CircleAvatar(radius: 16, backgroundImage: NetworkImage(user.photoURL!)),
                      ),
                  ],
                ),
                floatingActionButton: _selectedIndex == 0 
    ? GestureDetector(
        onTap: () => _crearDiarioFlow(user),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), // Transparente
            borderRadius: BorderRadius.circular(4),      // Cuadrado (con un toque de borde suave)
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 30),
        ),
      )
    : null,
                body: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _selectedIndex = index),
                  children: [
                    DiariosTabPersistente(
                      key: const PageStorageKey('diarios_tab'),
                      user: user,
                      onRenombrar: _renombrarDiario,
                      onEliminar: _eliminarDiario,
                      onAddAmigo: _mostrarBuscadorAmigos,
                      onCrearFlow: () => _crearDiarioFlow(user),
                    ),
                    const SocialPage(key: PageStorageKey('social')),
                    const WallPage(key: PageStorageKey('wall')),
                    const SettingsPage(key: PageStorageKey('settings')),
                    const ProfilePage(key: PageStorageKey('profile')),
                  ],
                ),
                bottomNavigationBar: Container(
  height: 70,
  decoration: const BoxDecoration(
    color: Color(0xFF3E2723),
    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: [
      _buildNavItem(0, Icons.book_outlined, Icons.book),
      _buildNavItem(1, Icons.people_outline, Icons.people),
      _buildNavItem(2, Icons.public, Icons.public),
      _buildNavItem(3, Icons.settings_outlined, Icons.settings),
      _buildNavItem(4, Icons.person_outline, Icons.person),
    ],
  ),
),
              ),
            ),
          ),
        );
      },
    );
  }

Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
  bool isSelected = _selectedIndex == index;
  
  return GestureDetector(
    onTap: () => _onItemTapped(index),
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isSelected ? 1.2 : 1.0, // El icono crece suavemente
            duration: const Duration(milliseconds: 300),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              // Esto evita el "parpadeo" al cambiar de Outline a Fill
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey<int>(isSelected ? 1 : 0),
                color: isSelected ? const Color(0xFFFFD54F) : Colors.white54,
                size: 28,
              ),
            ),
          ),
          // Indicador inferior orgánico (opcional)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(top: 4),
            height: 3,
            width: isSelected ? 15 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}
}
// --- WIDGET DE PESTAÑA DE DIARIOS (Optimizado para ancho de banda) ---
class DiariosTabPersistente extends StatefulWidget {
  final User? user;
  final Function(String, String) onRenombrar;
  final Function(String) onEliminar;
  final Function(String) onAddAmigo;
  final VoidCallback onCrearFlow;

  const DiariosTabPersistente({
    super.key, 
    required this.user, 
    required this.onRenombrar, 
    required this.onEliminar, 
    required this.onAddAmigo, 
    required this.onCrearFlow
  });

  @override
  State<DiariosTabPersistente> createState() => _DiariosTabPersistenteState();
}

class _DiariosTabPersistenteState extends State<DiariosTabPersistente> with AutomaticKeepAliveClientMixin {
  
  Stream<QuerySnapshot>? _diariosStream;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      // Aquí es donde aplicamos el orden por actividad que querías
      _diariosStream = FirebaseFirestore.instance
    .collection('diarios')
    .where(Filter.or(
      Filter('colaboradores', arrayContains: FirebaseAuth.instance.currentUser!.uid),
      Filter('invitados', arrayContains: FirebaseAuth.instance.currentUser!.uid),
    ))
    .orderBy('ultimaActividad', descending: true)
    .snapshots();
    }
  }

  @override
  bool get wantKeepAlive => true; 

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (widget.user == null) return const Center(child: Text("Inicia sesión para ver tus diarios", style: TextStyle(color: Colors.white70)));

    return StreamBuilder<QuerySnapshot>(
  stream: _diariosStream,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    final docs = snapshot.data?.docs ?? [];
    
    if (docs.isEmpty) {
      return const Center(child: Text("No hay diarios aún", style: TextStyle(color: Colors.white70)));
    }

    return ListView.builder(
      key: const PageStorageKey('list_interna_diarios'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), // Padding extra para el botón flotante
      itemCount: docs.length, 
      itemBuilder: (context, index) {
        var doc = docs[index];
        var data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('invitados')) {
          data['invitados'] = [];
        }
        String nombre = data['nombre'] ?? 'Sin nombre';
        String id = doc.id;

        // Pasamos el mapa 'data' completo para que _cardDiario procese las invitaciones
        return _cardDiario(nombre, id, data); 
      },
    );
  },
);
  }

Widget _cardDiario(String nombre, String id, Map<String, dynamic> data) {
  final String miId = FirebaseAuth.instance.currentUser!.uid;
  final List colaboradores = data['colaboradores'] ?? [];
  final List invitados = data['invitados'] ?? [];
  
  // 1. Identificamos el estado del diario
  bool esInvitacion = invitados.contains(miId);
  bool esCompartido = colaboradores.length > 1;

  // 2. Definimos el color según tu lógica: Marrón (privado), Azul (compartido), Verde (invitación)
  Color iconoColor = esInvitacion 
      ? Colors.green 
      : (esCompartido ? Colors.blue[800]! : Colors.brown[700]!);

  return Container(
    margin: const EdgeInsets.only(bottom: 15),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))]
    ),
    child: ListTile(
      onTap: () async {
        if (esInvitacion) {
          // Si es invitación, abrimos el panel de decisión
          _mostrarDialogoInvitacion(id, nombre, data);
        } else {
          // Si ya es socio, actualizamos actividad y entramos
          FirebaseFirestore.instance.collection('diarios').doc(id).update({
            'ultimaActividad': FieldValue.serverTimestamp()
          });
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DiaryPage(diarioId: id, nombreDiario: nombre))
          );
        }
      },
      leading: Icon(Icons.book, color: iconoColor),
      title: Text(
        nombre, 
        style: TextStyle(
          fontSize: ConfigController.getAdaptedSize(16), 
          fontWeight: FontWeight.bold, 
          fontFamily: 'Georgia'
        )
      ),
      subtitle: Text(
        esInvitacion ? "¡Invitación pendiente!" : (esCompartido ? "Diario compartido" : "Diario privado"),
        style: TextStyle(fontSize: 12, color: esInvitacion ? Colors.green[700] : Colors.grey[600]),
      ),
      // El menú de opciones (tres puntos) solo sale si ya has aceptado el diario[cite: 3]
      trailing: esInvitacion 
        ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green) 
        : PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) {
              if (value == 'edit') widget.onRenombrar(id, nombre);
              if (value == 'delete') widget.onEliminar(id);
              if (value == 'add_friend') widget.onAddAmigo(id);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text("Cambiar nombre")])),
              const PopupMenuItem(value: 'add_friend', child: Row(children: [Icon(Icons.person_add, size: 20), SizedBox(width: 8), Text("Añadir amigo")])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Eliminar", style: TextStyle(color: Colors.red))])),
            ],
          ),
    ),
  );
}
void _mostrarDialogoInvitacion(String diarioId, String nombre, Map<String, dynamic> data) {
  final List colaboradoresIds = data['colaboradores'] ?? [];
  final String remitente = data['invitadoPorNombre'] ?? "Alguien"; // Recuperamos el nombre[cite: 3, 5]

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text("Invitación a '$nombre'", style: const TextStyle(fontFamily: 'Georgia')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: "Tu amigo ",
              children: [
                TextSpan(text: remitente, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                const TextSpan(text: " te ha invitado a este diario compartido."),
              ],
            ),
          ),
          const SizedBox(height: 15),
          const Divider(),
          const SizedBox(height: 10),
          Text("${colaboradoresIds.length} personas ya están colaborando.", 
               style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly, // Alinea los botones seguidos con espacio entre ellos
      actions: [
  TextButton(
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context); // Guardar referencia[cite: 4]
      
      await FirebaseFirestore.instance.collection('diarios').doc(diarioId).update({
        'invitados': FieldValue.arrayRemove([FirebaseAuth.instance.currentUser!.uid])
      });

      if (ctx.mounted) Navigator.pop(ctx); // Check de seguridad[cite: 4]
      messenger.showSnackBar(const SnackBar(content: Text("Invitación rechazada")));
    },
    child: const Text("RECHAZAR", style: TextStyle(color: Colors.red)),
  ),
  ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
    onPressed: () async {
      final messenger = ScaffoldMessenger.of(context); // Guardar referencia[cite: 4]
      String miId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('diarios').doc(diarioId).update({
        'invitados': FieldValue.arrayRemove([miId]),
        'colaboradores': FieldValue.arrayUnion([miId]),
        'ultimaActividad': FieldValue.serverTimestamp(),
      });

      if (ctx.mounted) Navigator.pop(ctx); // Check de seguridad[cite: 4]
      messenger.showSnackBar(const SnackBar(content: Text("¡Ahora eres colaborador!")));
    },
    child: const Text("ACEPTAR", style: TextStyle(color: Colors.white)),
  ),
],
    ),
  );
}
}
