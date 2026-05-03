import 'package:flutter/material.dart';
import "../services/config_controller.dart";
import 'package:shared_preferences/shared_preferences.dart';
import 'scrapbook_wrapper.dart'; // Asegúrate de que el nombre coincida con tu archivo

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificacionesActivas = true;
  int _fontSizeIndex = 0; // 0: Normal, 1: Grande
  int _idiomaIndex = 0;

  final List<String> _fontSizes = ["Normal", "Grande"];
  final List<String> _idiomas = ["Español", "Catalá", "English"];

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificacionesActivas = prefs.getBool('notificaciones') ?? true;
      _fontSizeIndex = prefs.getInt('fontSize') ?? 0;
      _idiomaIndex = prefs.getInt('idioma') ?? 0;
      
      // Sincronizar el controlador al cargar la página
      ConfigController.fontSize = _fontSizeIndex == 1 ? 26.0 : 20.0;
    });
  }

  Future<void> _guardarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificaciones', _notificacionesActivas);
    await prefs.setInt('fontSize', _fontSizeIndex);
    await prefs.setInt('idioma', _idiomaIndex);

    setState(() {
      // ACTUALIZACIÓN GLOBAL: Solo ocurre aquí
      // Normal = 20.0, Grande = 26.0
      ConfigController.fontSize = _fontSizeIndex == 1 ? 26.0 : 20.0;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
    content: const Text("Configuración guardada"),
    behavior: SnackBarBehavior.floating, // <--- ESTO lo hace flotar
    margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20), // <--- Lo eleva sobre la Bar
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    backgroundColor: Colors.indigo,
    duration: const Duration(seconds: 2),
  ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definimos el estilo dinámico basado en lo que hay GUARDADO en el ConfigController
    final dynamicLabelStyle = TextStyle(
      fontFamily: 'Georgia', 
      fontSize: ConfigController.getAdaptedSize(14), // Base 14 que escala a 20 si es Grande
    );

    return ScrapbookWrapper(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // NOTIFICACIONES
                _buildScrapbookCard(
                  icon: Icons.notifications_active_outlined,
                  label: "Notificaciones",
                  labelStyle: dynamicLabelStyle,
                  trailing: Checkbox(
                    value: _notificacionesActivas,
                    activeColor: Colors.indigo,
                    onChanged: (val) => setState(() => _notificacionesActivas = val ?? false),
                  ),
                ),
                const SizedBox(height: 15),

                // IDIOMA
                _buildScrapbookCard(
                  icon: Icons.language,
                  label: "Idioma",
                  labelStyle: dynamicLabelStyle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, color: Colors.indigo),
                        onPressed: _idiomaIndex > 0 ? () => setState(() => _idiomaIndex--) : null,
                      ),
                      SizedBox(
                        width: 75,
                        child: Center(
                          child:Text(
                          _idiomas[_idiomaIndex], 
                          softWrap: false,
                          style: dynamicLabelStyle.copyWith(fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right, color: Colors.indigo),
                        onPressed: _idiomaIndex < _idiomas.length - 1 ? () => setState(() => _idiomaIndex++) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // FUENTE (Selector de tamaño)
                _buildScrapbookCard(
                  icon: Icons.text_fields_rounded,
                  label: "Fuente",
                  labelStyle: dynamicLabelStyle,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, color: Colors.indigo),
                        onPressed: _fontSizeIndex > 0 ? () => setState(() => _fontSizeIndex--) : null,
                      ),
                      SizedBox(
                        width: 75,
                        child: Center(
                          child: Text(
                            _fontSizes[_fontSizeIndex], 
                            softWrap: false,
                            style: dynamicLabelStyle.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right, color: Colors.indigo),
                        // Límite puesto en 1 porque solo tenemos Normal (0) y Grande (1)
                        onPressed: _fontSizeIndex < 1 ? () => setState(() => _fontSizeIndex++) : null,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 15),

                // ELIMINAR CUENTA
                _buildScrapbookCard(
                  icon: Icons.delete_outline,
                  label: "Eliminar cuenta",
                  labelStyle: dynamicLabelStyle,
                  trailing: TextButton(
                    onPressed: _borrarCuentaDialog,
                    child: Text(
                      "BORRAR", 
                      style: TextStyle(
                        color: Colors.red, 
                        fontSize: ConfigController.getAdaptedSize(12), 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 100), 
              ],
            ),
          ),

          // BOTÓN GUARDAR (Posicionado abajo a la derecha)
          Positioned(
            bottom: 20,
            right: 20,
            child: InkWell(
              onTap: _guardarPreferencias,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E), 
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2), 
                      blurRadius: 4, 
                      offset: const Offset(2, 2)
                    )
                  ],
                ),
                child: const Text(
                  "GUARDAR",
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 12, 
                    letterSpacing: 1.1
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET AUXILIAR PARA LAS TARJETAS
  Widget _buildScrapbookCard({
    required IconData icon, 
    required String label, 
    required Widget trailing, 
    TextStyle? labelStyle
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), 
            blurRadius: 3, 
            offset: const Offset(1, 1)
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 20),
          const SizedBox(width: 12),
          Text(
            label, 
            style: labelStyle ?? const TextStyle(fontFamily: 'Georgia', fontSize: 14),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  void _borrarCuentaDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        title: const Text(
          "¿Eliminar cuenta?", 
          style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)
        ),
        content: const Text(
          "Esta acción es irreversible.", 
          style: TextStyle(fontFamily: 'Georgia')
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CANCELAR", style: TextStyle(color: Colors.black54))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("BORRAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}