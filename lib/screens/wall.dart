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
    return ScrapbookWrapper(
      floatingActionButton: FloatingActionButton(
        heroTag: "btn_wall_post",
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: () => _mostrarDialogoPost(context),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('muro')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error al cargar muro"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text("El muro está vacío..."));

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
                  // Si tiene más de 48h y es mío, lo borro de la DB
                  if (esMio) {
                    FirebaseFirestore.instance.collection('muro').doc(docId).delete();
                  }
                  // No lo mostramos visualmente
                  return const SizedBox.shrink();
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(18),
                // --- 4. Estética de administrador vs usuario ---
                decoration: isAdmin 
                    ? BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6), // Semitransparente
                        borderRadius: BorderRadius.circular(25), // Muy redondeado
                        border: Border.all(color: Colors.white30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5)
                          )
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(4), // Cuadrado como estaba
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
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
                          // Añadimos el "(yo)" si es nuestro mensaje[cite: 4]
                          esMio 
                            ? "${data['autor']} (yo)".toUpperCase() 
                            : (data['autor']?.toString().toUpperCase() ?? "ANÓNIMO"),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ConfigController.getAdaptedSize(11),
                            letterSpacing: 1,
                            // Aplicamos el color aleatorio o índigo si somos nosotros
                            color: _getColor(data['autorId'] ?? "", esMio),
                          ),
                        ),
                        const Spacer(),
                        // Estrellita de Like si no es nuestro mensaje
                        if (!esMio)
                          InkWell(
                            onTap: () => _toggleLike(docId, likes),
                            child: Icon(
                              leDiLike ? Icons.star : Icons.star_border, 
                              size: 20, 
                              color: leDiLike ? Colors.amber : Colors.black26
                            ),
                          ),
                        if (!esMio) const SizedBox(width: 8),
                        if (esMio)
                          InkWell(
                            onTap: () => _confirmarEliminarMensaje(docId),
                            child: const Icon(Icons.close, size: 16, color: Colors.black26),
                          ),
                      ],
                    ),
                    const Divider(height: 20, thickness: 0.5),
                    Text(
                      data['mensaje'] ?? "",
                      style: TextStyle(
                        fontSize: ConfigController.fontSize - 2,
                        fontFamily: isAdmin ? 'Roboto' : 'Georgia', // Diferenciamos la fuente si quieres
                        fontStyle: isAdmin ? FontStyle.italic : FontStyle.normal,
                        height: 1.4,
                        color: isAdmin ? Colors.black87 : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Contador de likes pequeño (Opcional)
                        likes.isNotEmpty 
                          ? Text("${likes.length} ⭐", style: const TextStyle(fontSize: 10, color: Colors.amber))
                          : const SizedBox.shrink(),
                        Text(
                          _formatearFecha(ts),
                          style: TextStyle(
                            fontSize: ConfigController.getAdaptedSize(9), 
                            color: Colors.black38, 
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