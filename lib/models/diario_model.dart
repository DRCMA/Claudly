import 'package:cloud_firestore/cloud_firestore.dart';

class Diario {
  final String id;
  final String nombre;
  final String userId;
  final DateTime fechaCreacion;

  Diario({
    required this.id, 
    required this.nombre, 
    required this.userId, 
    required this.fechaCreacion
  });

  // Este método convierte lo que viene de Firebase en un objeto de Dart
  factory Diario.fromFirestore(DocumentSnapshot doc) {
    // Usamos Map<String, dynamic> para que Dart sepa qué hay dentro
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Diario(
      id: doc.id,
      nombre: data['nombre'] ?? 'Sin nombre',
      userId: data['userId'] ?? '',
      // Convertimos el Timestamp de Firebase a un DateTime de Dart
      fechaCreacion: (data['fechaCreacion'] as Timestamp).toDate(),
    );
  }
}