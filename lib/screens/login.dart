import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.loginSilencioso(); // Intento automático al abrir
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 80, color: Colors.indigo),
            const Text("Claud", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            OutlinedButton.icon(
              onPressed: () => _authService..signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: const Text("Continuar con Google"),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 50)),
            ),
          ],
        ),
      ),
    );
  }
}