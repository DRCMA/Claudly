import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as dev;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- 1. SUBIR SOLO EL ARCHIVO ---
  Future<String> subirArchivoSolamente(XFile imagen, {String? diarioId}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Usuario no autenticado");

    // Mejoramos la ruta: recuerdos / ID_USUARIO / ID_DIARIO (opcional) / nombre
    String path = 'recuerdos/${user.uid}/';
    if (diarioId != null) path += '$diarioId/';
    
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    Reference ref = _storage.ref().child('$path$fileName');
    
    // MEJORA: Añadimos Metadatos para que Firebase sepa que es una imagen
    SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

    // Usamos putData con metadatos
    UploadTask uploadTask = ref.putData(await imagen.readAsBytes(), metadata);
    
    TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // --- 2. SUBIR NUEVO RECUERDO ---
  Future<void> subirRecuerdo(XFile imagen, String texto, String diarioId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Pasamos el diarioId para organizar mejor las carpetas
    String downloadUrl = await subirArchivoSolamente(imagen, diarioId: diarioId);

    // IMPORTANTE: Asegúrate de que la colección sea 'diarios/ID/recuerdos' 
    // como en tu DiaryPage, o 'recuerdos' global. 
    // Si en DiaryPage usas subcolecciones, este código debe cambiar:
    await _firestore
        .collection('diarios')
        .doc(diarioId)
        .collection('recuerdos')
        .add({
      'userId': user.uid,
      'url': downloadUrl,
      'texto': texto,
      'fecha': FieldValue.serverTimestamp(), // Mejor usar el tiempo del servidor
    });
  }

  // --- 3. BORRAR ARCHIVO (Centralizado) ---
  Future<void> borrarArchivo(String url) async {
    if (url.isEmpty) return;
    try {
      Reference ref = _storage.refFromURL(url);
      await ref.delete();
      dev.log("Archivo borrado con éxito de Storage");
    } catch (e) {
      // Usamos dev.log en lugar de print para no ensuciar la consola en producción
      dev.log("Aviso: No se pudo borrar el archivo (quizás ya no existía): $e");
    }
  }

  // --- 4. ELIMINAR RECUERDO COMPLETO ---
  Future<void> eliminarRecuerdoCompleto(String diarioId, String recuerdoId, String url) async {
    try {
      // 1. Borrar de Storage
      await borrarArchivo(url);
      // 2. Borrar de Firestore (Ajustado a tu estructura de subcolección)
      await _firestore
          .collection('diarios')
          .doc(diarioId)
          .collection('recuerdos')
          .doc(recuerdoId)
          .delete();
    } catch (e) {
      dev.log("Error al eliminar recuerdo completo: $e");
    }
  }
}