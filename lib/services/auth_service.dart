import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:developer' as dev; // <--- Importamos esto para los logs profesionales

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: "557429013068-qfaj0eavicklithapd3224u3gu2kq6s3.apps.googleusercontent.com",
    scopes: ['email'],
  );

  // Stream para que la app reaccione en tiempo real al login/logout
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Alias por si lo usas con el nombre anterior en algún sitio
  Stream<User?> get usuarioStream => _auth.authStateChanges();

  // Login Silencioso
  Future<User?> loginSilencioso() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) return await _conectarConFirebase(googleUser);
    } catch (e) {
      dev.log("Error en login silencioso: $e"); // Usamos dev.log en lugar de print
      return null;
    }
    return null;
  }

  // Google Sign In (Renombrado para coincidir con home.dart)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      return await _conectarConFirebase(googleUser);
    } catch (e) {
      dev.log("Error en Google Sign In: $e"); // Limpio y profesional
      return null;
    }
  }

  // Lógica privada para Firebase
  Future<User?> _conectarConFirebase(GoogleSignInAccount googleUser) async {
    try {
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      dev.log("Error al conectar con Firebase: $e");
      return null;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      // 1. Desconectamos Google primero de forma profunda
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect(); 
      }
      // 2. Cerramos sesión en Firebase una sola vez
      await _auth.signOut();
    } catch (e) {
      dev.log("Error al cerrar sesión: $e");
    }
  }
}