import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import "../services/config_controller.dart";
import 'package:shared_preferences/shared_preferences.dart';
import 'scrapbook_wrapper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifAmistad = true;
  bool _notifDiario = true;
  bool _notifMuro = true;
  bool _notifRecordatorios = true;

  bool _isDarkMode = false;
  int _fontSizeIndex = 0;
  int _idiomaIndex = 0;

  bool get _allOff => !_notifAmistad && !_notifDiario && !_notifMuro && !_notifRecordatorios;
  final List<String> _fontSizes = ["Normal", "Grande"];
  final List<String> _idiomas = ["Español", "Catalá", "English"];

  String _estadoUsuario = "En línea";
  final List<String> _estados = ["En línea", "Ausente"];

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifAmistad = prefs.getBool('notifAmistad') ?? true;
      _notifDiario = prefs.getBool('notifDiario') ?? true;
      _notifMuro = prefs.getBool('notifMuro') ?? true;
      _notifRecordatorios = prefs.getBool('notifRecordatorios') ?? true;
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _fontSizeIndex = prefs.getInt('fontSize') ?? 0;
      _idiomaIndex = prefs.getInt('idioma') ?? 0;
      _estadoUsuario = prefs.getString('estadoUsuario') ?? "En línea";

      ConfigController.fontSize = _fontSizeIndex == 1 ? 26.0 : 20.0;
      ConfigController.isDarkMode = _isDarkMode;
      ConfigController.darkModeListenable.value = _isDarkMode;
    });
  }

  /// Persiste todo en SharedPreferences y Firestore (en segundo plano).
  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifAmistad', _notifAmistad);
    await prefs.setBool('notifDiario', _notifDiario);
    await prefs.setBool('notifMuro', _notifMuro);
    await prefs.setBool('notifRecordatorios', _notifRecordatorios);
    await prefs.setBool('darkMode', _isDarkMode);
    await prefs.setInt('fontSize', _fontSizeIndex);
    await prefs.setInt('idioma', _idiomaIndex);
    await prefs.setString('estadoUsuario', _estadoUsuario);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'notifAmistad': _notifAmistad,
        'notifDiario': _notifDiario,
        'notifMuro': _notifMuro,
        'notifRecordatorios': _notifRecordatorios,
        'darkMode': _isDarkMode,
        'estadoUsuario': _estadoUsuario,
      }).catchError((e) => debugPrint("Firestore error: $e"));
    }
  }

  /// Aplica un cambio de modo oscuro: actualiza ConfigController ANTES del setState
  /// para que el rebuild vea los valores correctos en el mismo frame.
  void _setDarkMode(bool val) {
    ConfigController.isDarkMode = val;
    ConfigController.darkModeListenable.value = val;
    setState(() => _isDarkMode = val);
    _persistir();
  }

  void _setFontSize(int index) {
    ConfigController.fontSize = index == 1 ? 26.0 : 20.0;
    setState(() => _fontSizeIndex = index);
    _persistir();
  }

  void _toggleMaster(bool val) {
    setState(() {
      _notifAmistad = !val;
      _notifDiario = !val;
      _notifMuro = !val;
      _notifRecordatorios = !val;
    });
    _persistir();
  }

  void _confirmarBorradoCuenta() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 10),
          Text("Borrar Cuenta"),
        ]),
        content: const Text(
          "Esta acción es irreversible. Se eliminarán todos tus diarios, fotos y configuración.\n\n¿Estás seguro?",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.currentUser?.delete();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error: Requiere inicio de sesión reciente.")),
                );
              }
            },
            child: const Text("ELIMINAR DEFINITIVAMENTE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Todos los colores se derivan de _isDarkMode (variable local de estado),
    // NO de ConfigController, para garantizar que el rebuild es completo e instantáneo.
    final bool d = _isDarkMode;
    final Color textColor = d ? Colors.white : Colors.black;
    final Color textColorSub = d ? Colors.white70 : Colors.black87;
    final double adaptedFontSize = _fontSizeIndex == 1 ? 22.0 : 16.0;
    final TextStyle labelStyle = TextStyle(
      fontFamily: 'Georgia',
      fontSize: adaptedFontSize,
      color: textColor,
    );
    final Color bgPage = d ? const Color(0xFF121212) : Colors.transparent;
    final Color cardBg = d ? Colors.grey[900]!.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9);
    final Color cardShadow = d ? Colors.black54 : Colors.black12;
    final Color headerColor = d ? Colors.white54 : Colors.black54;
    final Color iconColor = d ? Colors.white60 : Colors.black54;

    return ScrapbookWrapper(
      isDarkMode: d,
      child: Scaffold(
        backgroundColor: bgPage,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 40),
          child: Column(
            children: [

              // ── NOTIFICACIONES ─────────────────────────────────────────────
              _card(cardBg, cardShadow, headerColor, iconColor, Icons.notifications, "Notificaciones", [
                _item(iconColor, textColor, Icons.do_not_disturb_on, "Desactivar todas",
                  TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: adaptedFontSize, fontFamily: 'Georgia'),
                  Switch.adaptive(value: _allOff, onChanged: _toggleMaster)),
                _item(iconColor, textColor, Icons.person_add_alt_1, "Solicitudes", labelStyle,
                  Switch.adaptive(value: _notifAmistad, activeThumbColor: Colors.indigo,
                    onChanged: (val) { setState(() => _notifAmistad = val); _persistir(); })),
                _item(iconColor, textColor, Icons.menu_book, "Diario compartido", labelStyle,
                  Switch.adaptive(value: _notifDiario, activeThumbColor: Colors.indigo,
                    onChanged: (val) { setState(() => _notifDiario = val); _persistir(); })),
                _item(iconColor, textColor, Icons.public, "Muro", labelStyle,
                  Switch.adaptive(value: _notifMuro, activeThumbColor: Colors.indigo,
                    onChanged: (val) { setState(() => _notifMuro = val); _persistir(); })),
                _item(iconColor, textColor, Icons.alarm, "Recordatorios", labelStyle,
                  Switch.adaptive(value: _notifRecordatorios, activeThumbColor: Colors.indigo,
                    onChanged: (val) { setState(() => _notifRecordatorios = val); _persistir(); })),
              ]),

              // ── MULTIMEDIA ─────────────────────────────────────────────────
              _card(cardBg, cardShadow, headerColor, iconColor, Icons.accessibility, "Multimedia", [
                _item(iconColor, textColor, Icons.dark_mode_outlined, "Modo Oscuro", labelStyle,
                  Switch.adaptive(
                    value: _isDarkMode,
                    activeThumbColor: Colors.indigo,
                    onChanged: _setDarkMode,
                  )),
                _item(iconColor, textColor, Icons.language, "Idioma", labelStyle,
                  _selector(
                    _idiomas[_idiomaIndex], textColorSub, adaptedFontSize,
                    _idiomaIndex > 0 ? () { setState(() => _idiomaIndex--); _persistir(); } : null,
                    _idiomaIndex < _idiomas.length - 1 ? () { setState(() => _idiomaIndex++); _persistir(); } : null,
                  )),
                _item(iconColor, textColor, Icons.text_fields_rounded, "Fuente", labelStyle,
                  _selector(
                    _fontSizes[_fontSizeIndex], textColorSub, adaptedFontSize,
                    _fontSizeIndex > 0 ? () => _setFontSize(_fontSizeIndex - 1) : null,
                    _fontSizeIndex < 1 ? () => _setFontSize(_fontSizeIndex + 1) : null,
                  )),
              ]),

              // ── USUARIO ────────────────────────────────────────────────────
              _card(cardBg, cardShadow, headerColor, iconColor, Icons.account_circle, "Usuario", [
                _item(iconColor, textColor, Icons.badge_outlined, "Estado", labelStyle,
                  _estadoDropdown(labelStyle, textColorSub)),
                Divider(color: d ? Colors.white12 : Colors.black12, height: 20),
                InkWell(
                  onTap: _confirmarBorradoCuenta,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                        const SizedBox(width: 12),
                        Text("Borrar Cuenta",
                            style: labelStyle.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── HELPERS DE UI ────────────────────────────────────────────────────────

  Widget _card(Color bg, Color shadow, Color headerColor, Color iconColor,
      IconData icon, String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: shadow, blurRadius: 4, offset: const Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: headerColor),
            const SizedBox(width: 8),
            Text(title.toUpperCase(),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: headerColor, letterSpacing: 1.2)),
          ]),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _item(Color iconColor, Color textColor, IconData icon, String label,
      TextStyle labelStyle, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: labelStyle.copyWith(color: textColor))),
          trailing,
        ],
      ),
    );
  }

  Widget _selector(String value, Color textColor, double fontSize,
      VoidCallback? onLeft, VoidCallback? onRight) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
            icon: const Icon(Icons.arrow_left, color: Colors.indigo), onPressed: onLeft),
        SizedBox(
          width: 70,
          child: Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: textColor, fontSize: fontSize,
                  fontWeight: FontWeight.bold, fontFamily: 'Georgia')),
        ),
        IconButton(
            icon: const Icon(Icons.arrow_right, color: Colors.indigo), onPressed: onRight),
      ],
    );
  }

  Widget _estadoDropdown(TextStyle baseStyle, Color textColor) {
    return DropdownButton<String>(
      value: _estadoUsuario,
      underline: const SizedBox(),
      dropdownColor: _isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFF3E2723),
      onChanged: (val) {
        setState(() => _estadoUsuario = val!);
        _persistir();
      },
      items: _estados.map((e) {
        Color c = (e == "En línea") ? Colors.green : Colors.orange;
        return DropdownMenuItem(
            value: e,
            child: Text(e, style: baseStyle.copyWith(color: c, fontWeight: FontWeight.bold)));
      }).toList(),
      selectedItemBuilder: (context) => _estados.map((e) {
        Color c = (e == "En línea") ? Colors.green : Colors.orange;
        return Center(
            child: Text(e, style: baseStyle.copyWith(color: c, fontWeight: FontWeight.bold)));
      }).toList(),
    );
  }
}