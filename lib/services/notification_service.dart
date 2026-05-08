import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint


class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Pedir permiso y RECIBIR el objeto de configuración (no crearlo nosotros)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _fcm.getToken();
      await _guardarTokenEnFirestore(token);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      await _localNotifications.initialize(
        const InitializationSettings(android: initializationSettingsAndroid),
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _mostrarNotificacionLocal(message);
      });
    }
  }

  static Future<void> _guardarTokenEnFirestore(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'ultimaActualizacionToken': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static void _mostrarNotificacionLocal(RemoteMessage message) {
    // CONFIGURACIÓN CORRECTA DE ANDROID
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_diarios', 
      'Notificaciones de Diarios',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    // USAMOS NotificationDetails de la librería local_notifications
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails, // <--- AQUÍ estaba el error: ahora pasamos platformDetails[cite: 4]
    );
  }
  static Future<void> enviarNotificacionPush({
  required String receptorUid,
  required String titulo,
  required String cuerpo,
}) async {
  // 1. Buscamos el token del receptor en Firestore
  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(receptorUid)
      .get();

  if (!userDoc.exists) return;
  String? tokenReceptor = (userDoc.data() as Map<String, dynamic>)['fcmToken'];

  if (tokenReceptor == null) return;

  // 2. Enviamos la petición a FCM
  // NOTA: Para esto necesitas la "Server Key" de Firebase Console (Cloud Messaging)
  // aunque hoy en día se recomienda usar el protocolo v1 con Service Accounts.
  debugPrint("Enviando notificación a: $tokenReceptor");
  
  // Aquí es donde dispararías la lógica de envío (Cloud Function o API)
}
}