import 'package:flutter/material.dart';
import '../services/config_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scrapbook_wrapper.dart'; 

class WallPage extends StatefulWidget {
  const WallPage({super.key});

  @override
  State<WallPage> createState() => _WallPageState();
}

class _WallPageState extends State<WallPage> {
  String get miId => FirebaseAuth.instance.currentUser?.uid ?? "";

  // 1. Lista de colores extendida
  final List<Color> _userColors = [
    const Color(0xFFFFF176), const Color(0xFFFF8A80), 
    const Color(0xFF80D8FF), const Color(0xFFCCFF90),
    const Color(0xFFEA80FC), const Color(0xFFFFD180), 
    const Color(0xFFA7FFEB), const Color(0xFFFF80AB)
  ];

  // 2. Asignar color siempre igual según el ID
  Color _getColor(String id, bool esMio) {
    if (esMio) return Colors.indigo; // Tu color
    int hash = id.hashCode.abs();
    return _userColors[hash % _userColors.length];
  }

  // Función para dar/quitar like a la estrella
  Future<void> _toggleLike(String docId, List<dynamic> likes) async {
    final ref = FirebaseFirestore.instance.collection('muro').doc(docId);
    if (likes.contains(miId)) {
      await ref.update({'likes': FieldValue.arrayRemove([miId])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([miId])});
    }
  }

  @override
Widget build(BuildContext context) {
  // 1. Detectamos el modo oscuro actual desde el controlador estático
  final bool isDarkMode = ConfigController.isDarkMode;

  return ScrapbookWrapper(
    // Pasamos el estado al wrapper para que el fondo de papel cambie
    isDarkMode: isDarkMode, 
    floatingActionButton: FloatingActionButton(
      heroTag: "btn_wall_post",
      backgroundColor: Colors.indigo,
      child: const Icon(Icons.add_comment, color: Colors.white),
      onPressed: () => _mostrarDialogoPost(context),
    ),
    child: Scaffold(
      backgroundColor: ConfigController.getPageBgColor(),
    body: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('muro')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error al cargar muro",
              style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
          );
        }
        
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        // --- 2. LÓGICA DE MURO VACÍO ---
        if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons. auto_awesome, // Un icono que pegue con el estilo
              size: 80,
              color: ConfigController.getTextColor().withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "No hay nada de momento...",
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: ConfigController.getAdaptedSize(18),
                color: ConfigController.getTextColor().withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            var data = docs[index].data() as Map<String, dynamic>;
            
            bool isAdmin = data['tipo'] == 'administrador';
            bool esMio = data['autorId'] == miId;
            List<dynamic> likes = data['likes'] ?? [];
            bool leDiLike = likes.contains(miId);

            // --- 3. Lógica de borrado a las 48 horas ---
            Timestamp? ts = data['timestamp'] as Timestamp?;
            if (ts != null) {
              final diferencia = DateTime.now().difference(ts.toDate());
              if (diferencia.inHours >= 48) {
                if (esMio) {
                  FirebaseFirestore.instance.collection('muro').doc(docId).delete();
                }
                return const SizedBox.shrink();
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(18),
              // --- 4. Estética adaptable al Modo Oscuro ---
              decoration: isAdmin 
                  ? BoxDecoration(
                      // En modo oscuro, usamos un gris muy oscuro semitransparente
                      color: isDarkMode 
                          ? Colors.white.withValues(alpha: 0.1) 
                          : Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isDarkMode ? Colors.white10 : Colors.white30
                      ),
                    )
                  : BoxDecoration(
                      // El post estándar cambia de blanco a gris oscuro
                      color: isDarkMode 
                          ? Colors.grey[900]!.withValues(alpha: 0.95) 
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
                          blurRadius: 4,
                          offset: const Offset(2, 3)
                        )
                      ],
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        esMio 
                          ? "${data['autor']} (yo)".toUpperCase() 
                          : (data['autor']?.toString().toUpperCase() ?? "ANÓNIMO"),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ConfigController.getAdaptedSize(11),
                          letterSpacing: 1,
                          // Si es modo oscuro, aclaramos los colores de los nombres
                          color: _getColor(data['autorId'] ?? "", esMio).withValues(
                            alpha: isDarkMode ? 0.9 : 1.0
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!esMio)
                        InkWell(
                          onTap: () => _toggleLike(docId, likes),
                          child: Icon(
                            leDiLike ? Icons.star : Icons.star_border, 
                            size: 20, 
                            color: leDiLike 
                                ? Colors.amber 
                                : (isDarkMode ? Colors.white24 : Colors.black26)
                          ),
                        ),
                      if (!esMio) const SizedBox(width: 8),
                      if (esMio)
                        InkWell(
                          onTap: () => _confirmarEliminarMensaje(docId),
                          child: Icon(
                            Icons.close, 
                            size: 16, 
                            color: isDarkMode ? Colors.white38 : Colors.black26
                          ),
                        ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 0.5),
                  Text(
                    data['mensaje'] ?? "",
                    style: TextStyle(
                      fontSize: ConfigController.fontSize - 2,
                      fontFamily: isAdmin ? 'Roboto' : 'Georgia',
                      fontStyle: isAdmin ? FontStyle.italic : FontStyle.normal,
                      height: 1.4,
                      // Texto blanco en modo oscuro, negro en modo claro
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      likes.isNotEmpty 
                        ? Text("${likes.length} ⭐", style: const TextStyle(fontSize: 10, color: Colors.amber))
                        : const SizedBox.shrink(),
                      Text(
                        _formatearFecha(ts),
                        style: TextStyle(
                          fontSize: ConfigController.getAdaptedSize(9), 
                          color: isDarkMode ? Colors.white38 : Colors.black38, 
                          fontStyle: FontStyle.italic
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  ),
  );
}

  String _formatearFecha(Timestamp? ts) {
    if (ts == null) return "Ahora";
    var date = ts.toDate();
    return "${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

void _mostrarDialogoPost(BuildContext context) {
  final controller = TextEditingController();
  
  // 1. Pon aquí tu UID real sacado de Firebase Authentication
  final String miDeveloperUid = "h40YCi0enSTvy9TIUugGHnSufih2"; 
  
  // Variable para controlar si el switch está activado
  bool publicarComoAdmin = false;

  showDialog(
    context: context,
    builder: (context) {
      final user = FirebaseAuth.instance.currentUser;
      bool soyDesarrollador = user?.uid == miDeveloperUid;

      // Usamos StatefulBuilder para que el Checkbox se pueda actualizar dentro del Dialog
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              soyDesarrollador && publicarComoAdmin ? "Anuncio Oficial" : "Nuevo mensaje", 
              style: TextStyle(fontSize: ConfigController.getAdaptedSize(18), fontFamily: 'Georgia', color: publicarComoAdmin ? Colors.red[800] : Colors.black)
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  maxLength: 150,
                  style: TextStyle(fontSize: ConfigController.getAdaptedSize(16)),
                  decoration: const InputDecoration(hintText: "¿Qué quieres decir?"),
                ),
                
                // 2. EL INTERRUPTOR SECRETO: Solo aparece si eres tú
                if (soyDesarrollador) ...[
                  const Divider(),
                  CheckboxListTile(
                    title: const Text("Publicar como SISTEMA (Admin)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    value: publicarComoAdmin,
                    activeColor: Colors.red,
                    onChanged: (val) {
                      setStateDialog(() => publicarComoAdmin = val ?? false);
                    },
                  )
                ]
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: publicarComoAdmin ? Colors.red : Colors.indigo),
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  
                  await FirebaseFirestore.instance.collection('muro').add({
                    // Si es admin, ponemos el nombre CLAUD (o el nombre de tu app), si no, el del usuario
                    'autor': publicarComoAdmin ? "SISTEMA CLAUD" : (user?.displayName ?? "Usuario"),
                    'autorId': user?.uid,
                    'mensaje': controller.text.trim(),
                    // 3. AQUÍ SE DEFINE EL TIPO MÁGICAMENTE
                    'tipo': publicarComoAdmin ? 'administrador' : 'usuario',
                    'likes': [], 
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text("Publicar", style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      );
    },
  );
}

  void _confirmarEliminarMensaje(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "¿Eliminar mensaje?", 
          style: TextStyle(fontSize: ConfigController.getAdaptedSize(18))
        ),
        content: Text(
          "Esta acción no se puede deshacer.",
          style: TextStyle(fontSize: ConfigController.getAdaptedSize(14))
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('muro').doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}