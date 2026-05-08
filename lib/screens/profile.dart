import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/config_controller.dart';
import '../services/auth_service.dart';
import 'scrapbook_wrapper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  User? get user => FirebaseAuth.instance.currentUser;
  
  final TextEditingController _moteController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  String _generoSeleccionado = "Hombre";
  DateTime _fechaNacimiento = DateTime(2000, 1, 1);
  String _fechaUnion = ""; 
  final List<String> _generos = ["Hombre", "Mujer", "No binario", "Otro"];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _formatearFechaUnion();
    _inicializarPerfil();
    // Listener manual: fuerza setState aunque la tab esté en keepAlive
    ConfigController.darkModeListenable.addListener(_onDarkModeChanged);
  }

  void _onDarkModeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ConfigController.darkModeListenable.removeListener(_onDarkModeChanged);
    _moteController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _formatearFechaUnion() {
    final creationTime = user?.metadata.creationTime;
    _fechaUnion = creationTime != null 
        ? DateFormat('MMMM yyyy', 'es').format(creationTime)
        : DateFormat('MMMM yyyy', 'es').format(DateTime.now());
  }

  Future<void> _inicializarPerfil() async {
    if (user == null) return;
    await _cargarDatos();
    await _sincronizarYBitacora();
  }

  Future<void> _sincronizarYBitacora() async {
    final currentUser = user;
    if (currentUser == null) return;
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final snapshot = await userDoc.get();
      if (!snapshot.exists) {
        String moteInicial = currentUser.displayName ?? 
            "Invitado ${currentUser.uid.substring(currentUser.uid.length - 4).toUpperCase()}";
        String idPub = currentUser.uid.length >= 6 
            ? currentUser.uid.substring(0, 6).toUpperCase() 
            : "USER${currentUser.uid.length}";
        await userDoc.set({
          'mote': moteInicial,
          'email': currentUser.email,
          'photoURL': currentUser.photoURL ?? "",
          'idPublico': idPub,
          'bio': '',
          'genero': 'Hombre',
          'fechaNac': Timestamp.fromDate(_fechaNacimiento),
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
        _moteController.text = moteInicial;
      }
    } catch (e) {
      debugPrint("Error en sincronización: $e");
    }
  }

  Future<void> _cargarDatos() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _moteController.text = data['mote'] ?? "";
          _bioController.text = data['bio'] ?? "";
          String generoDb = data['genero'] ?? "Hombre";
          _generoSeleccionado = _generos.contains(generoDb) ? generoDb : "Hombre";
          if (data['fechaNac'] != null) {
            _fechaNacimiento = (data['fechaNac'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
    }
  }

  Future<void> _guardarPerfil() async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'mote': _moteController.text.trim(),
        'bio': _bioController.text.trim(),
        'genero': _generoSeleccionado,
        'fechaNac': Timestamp.fromDate(_fechaNacimiento),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Perfil actualizado con éxito"),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 90, left: 20, right: 20),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      debugPrint("Error al guardar: $e");
    }
  }

  void _confirmarCierreSesion() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ConfigController.getBrownDark(),
        title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.white)),
        content: Text("¿Quieres salir de tu diario?", 
            style: TextStyle(color: Colors.white70, fontSize: ConfigController.getAdaptedSize(16))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(dialogContext);
              _authService.logout(); 
            },
            child: const Text("SALIR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFFFD54F),
              onPrimary: Colors.black,
              surface: ConfigController.getBrownDark(),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _fechaNacimiento = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (user == null) return const Center(child: CircularProgressIndicator());

    // isDarkMode se lee en cada build — el listener manual de initState
    // garantiza que build se llame cuando cambia, incluso con keepAlive.
    final bool isDark = ConfigController.isDarkMode;

    final mainTextStyle = TextStyle(
      color: Colors.white, 
      fontSize: ConfigController.fontSize, 
      fontFamily: 'Georgia'
    );

    return ScrapbookWrapper(
      isDarkMode: isDark,
      child: Scaffold(
        backgroundColor: ConfigController.getPageBgColor(),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TARJETA DE PERFIL ---
                  _buildBrownCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.white10,
                          backgroundImage: (user!.photoURL != null) ? NetworkImage(user!.photoURL!) : null,
                          child: (user!.photoURL == null) ? const Icon(Icons.person, size: 35, color: Colors.white54) : null,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEtiqueta("mote:"),
                              TextField(
                                controller: _moteController,
                                style: mainTextStyle.copyWith(fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(
                                  isDense: true, 
                                  border: InputBorder.none, 
                                  hintText: "Tu mote...", 
                                  hintStyle: TextStyle(color: Colors.white24)
                                ),
                              ),
                              _buildEtiqueta("correo:"),
                              Text(user?.email ?? "", style: mainTextStyle.copyWith(fontSize: 14, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- TARJETA SOBRE MÍ ---
                  _buildBrownCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEtiqueta("sobre mí:"),
                        TextField(
                          controller: _bioController,
                          maxLines: 2,
                          style: mainTextStyle,
                          decoration: const InputDecoration(
                            border: InputBorder.none, 
                            hintText: "Escribe algo aquí...", 
                            hintStyle: TextStyle(color: Colors.white24)
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- TARJETA DATOS ---
                  _buildBrownCard(
                    child: Column(
                      children: [
                        _buildDataRow(
                          label: "nacimiento:", 
                          value: "${_fechaNacimiento.year}", 
                          icon: Icons.calendar_today, 
                          onTap: _seleccionarFecha
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDropdownGenero(),
                        const Divider(color: Colors.white10, height: 20),
                        _buildDataRow(
                          label: "miembro desde:", 
                          value: _fechaUnion, 
                          icon: Icons.auto_awesome_outlined
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- BOTÓN CERRAR SESIÓN ---
                  _buildBrownCard(
                    onTap: _confirmarCierreSesion,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_settings_new, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Text("CERRAR SESIÓN", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),

            // --- BOTÓN GUARDAR ---
            Positioned(
              bottom: 25,
              right: 20,
              child: ElevatedButton(
                onPressed: _guardarPerfil,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                ),
                child: const Text("GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrownCard({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ConfigController.getBrownDark(),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!ConfigController.isDarkMode)
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: child,
      ),
    );
  }

  Widget _buildEtiqueta(String texto) {
    return Text(texto.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1.2));
  }

  Widget _buildDataRow({required String label, required String value, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildEtiqueta(label), 
            Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'Georgia'))
          ])),
          Icon(icon, color: Colors.white24, size: 18)
        ],
      ),
    );
  }

  Widget _buildDropdownGenero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildEtiqueta("género:"),
        DropdownButton<String>(
          value: _generoSeleccionado,
          isExpanded: true,
          dropdownColor: ConfigController.getBrownDark(), 
          style: const TextStyle(color: Colors.white, fontFamily: 'Georgia'),
          underline: Container(),
          items: _generos.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) { if (val != null) setState(() => _generoSeleccionado = val); },
        )
      ],
    );
  }
}