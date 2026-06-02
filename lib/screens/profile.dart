import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  String _paisSeleccionado = "España";
  String _photoUrlLocal = "";
  bool _subiendoImagen = false;

  final List<Map<String, String>> _avataresPredeterminados = [
    {"nombre": "Tomatito", "url": "assets/profilePicture/toumáquet.png", "tipo": "asset",},
    {"nombre": "CaraRoja", "url": "assets/profilePicture/caraVermella.png", "tipo": "asset"},
    {"nombre": "Bread", "url": "assets/profilePicture/bread.png", "tipo": "asset"},
    {"nombre": "Nina", "url": "assets/profilePicture/NinaProfile.png", "tipo": "asset"}
  ];

  final List<String> _paises = [
  "Afganistán", "Albania", "Alemania", "Andorra", "Angola", "Argentina", "Australia", 
  "Austria", "Bélgica", "Bolivia", "Brasil", "Canadá", "Chile", "China", "Colombia", 
  "Costa Rica", "Cuba", "Dinamarca", "Ecuador", "Egipto", "El Salvador", "España", 
  "Estados Unidos", "Francia", "Guatemala", "Honduras", "Italia", "México", "Nicaragua", 
  "Panamá", "Paraguay", "Perú", "Portugal", "Reino Unido", "República Dominicana", 
  "Uruguay", "Venezuela"
]..sort();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _photoUrlLocal = user?.photoURL ?? "";
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
          'genero': 'Otro',
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
          _paisSeleccionado = data['pais'] ?? "España";
          _photoUrlLocal = data['photoURL'] ?? user?.photoURL ?? "";
          if (data['fechaNac'] != null) {
            _fechaNacimiento = (data['fechaNac'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando perfil: $e");
    }
  }
  
Future<void> _cambiarFotoGaleria() async {
  final picker = ImagePicker();
  
  // 1. Seleccionamos la imagen original de la galería directamente
  final XFile? pickedFile = await picker.pickImage(
    source: ImageSource.gallery, 
    imageQuality: 70, // Bajamos un poco la calidad para que la subida sea más rápida
  );
  
  if (pickedFile == null || user == null) return;

  // 2. Procedemos a subir la imagen seleccionada directamente
  setState(() => _subiendoImagen = true);
  
  try {
    final File file = File(pickedFile.path); 
    final String ext = pickedFile.path.split('.').last;
    final String fileName = "avatar_${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.$ext";
    
    final ref = FirebaseStorage.instance.ref().child('avatars').child(fileName);
    
    // Subida a Firebase Storage
    await ref.putFile(file);
    final String downloadUrl = await ref.getDownloadURL();

    // Sincronizamos con FirebaseAuth, Firestore y la UI
    await _actualizarFotoUrl(downloadUrl);
    
  } catch (e) {
    debugPrint("Error subiendo imagen: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al subir la imagen")),
      );
    }
  } finally {
    if (mounted) setState(() => _subiendoImagen = false);
  }
}

  // 2. Actualiza la URL en FirebaseAuth, Firestore y la UI local
Future<void> _actualizarFotoUrl(String nuevaUrl) async {
  if (user == null) return;
  try {
    // 1. Lo actualizamos en el perfil interno de Firebase Auth
    await user!.updatePhotoURL(nuevaUrl);
    
    // 2. LO MÁS IMPORTANTE: Lo subimos a la base de datos para que otros lo vean
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'photoURL': nuevaUrl,
    });

    setState(() {
      _photoUrlLocal = nuevaUrl;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foto actualizada")),
      );
    }
  } catch (e) {
    debugPrint("Error sincronizando foto: $e");
  }
}

void _mostrarOpcionesCambiarFoto() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ConfigController.getBrownDark(),
      title: const Text("Cambiar foto de perfil", 
          style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.white70),
            title: const Text("Subir desde Galería", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _cambiarFotoGaleria();
            },
          ),
          const Divider(color: Colors.white10),
          const Align(
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 15),
          
          // --- CUADRÍCULA DE 4 COLUMNAS ---
          SizedBox(
            width: double.maxFinite, 
            height: 200, // Ajusta la altura según necesites
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 imágenes por fila
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _avataresPredeterminados.length,
              itemBuilder: (context, index) {
                final item = _avataresPredeterminados[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _actualizarFotoUrl(item["url"]!);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.asset(item["url"]!, fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("CANCELAR", style: TextStyle(color: Colors.white54)),
        )
      ],
    ),
  );
}

  Future<void> _guardarPerfil() async {
    String nuevoMote = _moteController.text.trim();

    if (nuevoMote.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("El mote no puede estar vacío"))
    );
    return;
  }

    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'mote': nuevoMote,
        'bio': _bioController.text.trim(),
        'genero': _generoSeleccionado,
        'fechaNac': Timestamp.fromDate(_fechaNacimiento),
        'pais': _paisSeleccionado,
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
                        GestureDetector(
  onTap: _subiendoImagen ? null : _mostrarOpcionesCambiarFoto,
  child: Stack(
    alignment: Alignment.center,
    children: [
      // Avatar con imagen cacheada
      CircleAvatar(
  radius: 35,
  backgroundColor: Colors.white10,
  backgroundImage: _photoUrlLocal.isEmpty 
      ? null 
      : (_photoUrlLocal.startsWith('http') 
          // Si es de internet, usamos CACHÉ
          ? CachedNetworkImageProvider(_photoUrlLocal) as ImageProvider
          // Si es local (assets), usamos AssetImage
          : AssetImage(_photoUrlLocal)),
  child: _photoUrlLocal.isEmpty 
      ? const Icon(Icons.person, size: 35, color: Colors.white54) 
      : null,
),
      // Rueda de carga al subir desde la galería
      if (_subiendoImagen)
        const CircularProgressIndicator(color: Colors.amber),
      // Icono pequeño de cámara para indicar que es editable
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
        ),
      ),
    ],
  ),
),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEtiqueta("mote:"),
                              TextField(
                                controller: _moteController,
                                maxLength: 20,
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
                        _buildDropdownPais(),
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
                        Icon(Icons.logout, color: Colors.redAccent, size: 20),
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
Widget _buildDropdownPais() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildEtiqueta("PAÍS:"),
      DropdownButton<String>(
        value: _paisSeleccionado,
        isExpanded: true,
        menuMaxHeight: 300,
        dropdownColor: ConfigController.getBrownDark(),
        style: const TextStyle(color: Colors.white, fontFamily: 'Georgia'),
        underline: Container(),
        items: _paises.map((String pais) {
          return DropdownMenuItem<String>(
            value: pais,
            child: Text(pais),
          );
        }).toList(),
        onChanged: (String? nuevo) {
          if (nuevo != null) setState(() => _paisSeleccionado = nuevo);
        },
      ),
    ],
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