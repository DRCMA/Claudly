import 'package:cloud_firestore/cloud_firestore.dart';

class Recuerdo {
  final String id;
  final String url;
  final String texto;
  final DateTime? fecha;
  final String userId;

  Recuerdo({
    required this.id,
    required this.url,
    required this.texto,
    this.fecha,
    required this.userId,
  });

  factory Recuerdo.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Recuerdo(
      id: doc.id,
      url: data['url'] ?? '',
      texto: data['texto'] ?? '',
      userId: data['userId'] ?? '',
      fecha: data['fecha'] != null ? (data['fecha'] as Timestamp).toDate() : null,
    );
  }
}