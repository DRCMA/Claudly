import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalAlarmService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Inicializa la base de datos de zonas horarias (imprescindible para alarmas)
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Para iOS (Darwin)
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
  }

  static Future<void> programarAlarma({
    required String diarioId,
    required String nombreDiario,
    required Map<String, dynamic> config,
  }) async {
    // Usamos el hashCode del string del diarioId para tener un ID numérico único por diario
    final int notifId = diarioId.hashCode;

    // Primero cancelamos cualquier alarma previa de este diario
    await _plugin.cancel(notifId);

    final String tipo = config['tipo'] ?? 'desactivada';
    if (tipo == 'desactivada') return; // Si es desactivada, ya hemos cancelado arriba.

    final int hora = config['hora'] ?? 10;
    final int minuto = config['minuto'] ?? 0;

    // Detalles visuales de la notificación
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_recordatorios', 
      'Recordatorios de Diarios',
      channelDescription: 'Avisos para escribir en tus diarios',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Calculamos la próxima hora a la que debe pitar
    tz.TZDateTime fechaProgramada = _proximaHora(hora, minuto);

    if (tipo == 'diaria') {
      await _plugin.zonedSchedule(
        notifId,
        '¡Hora de escribir!',
        'Añade un nuevo recuerdo en tu diario "$nombreDiario".',
        fechaProgramada,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repetir cada día a esta hora
      );
    } 
    else if (tipo == 'semanal') {
      List<int> dias = List<int>.from(config['dias'] ?? []);
      // flutter_local_notifications maneja los días del 1(Lunes) al 7(Domingo)
      for (int dia in dias) {
        // Se programa una alarma semanal independiente para cada día seleccionado
        // Sumamos el día al notifId para no sobrescribirlas entre sí
        await _plugin.zonedSchedule(
          notifId + dia, 
          '¡Hora de escribir!',
          'Toca actualizar tu diario "$nombreDiario".',
          _proximoDiaDeLaSemana(hora, minuto, dia),
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Repetir cada semana ese día
        );
      }
    } 
    else if (tipo == 'personalizada') {
      int intervalo = config['intervalo'] ?? 1;
      // Para intervalos personalizados (ej. cada 3 días), se programa una única alarma futura.
      // Cuando el usuario entra a la app, tendrías que re-programarla para +3 días después.
      tz.TZDateTime fechaIntervalo = fechaProgramada.add(Duration(days: intervalo));
      
      await _plugin.zonedSchedule(
        notifId,
        'Recordatorio pendiente',
        'Hace $intervalo días que no escribes en "$nombreDiario".',
        fechaIntervalo,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // --- Helpers de Tiempo ---
  static tz.TZDateTime _proximaHora(int hora, int minuto) {
    final tz.TZDateTime ahora = tz.TZDateTime.now(tz.local);
    tz.TZDateTime programada = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, hora, minuto);
    if (programada.isBefore(ahora)) {
      programada = programada.add(const Duration(days: 1));
    }
    return programada;
  }

  static tz.TZDateTime _proximoDiaDeLaSemana(int hora, int minuto, int diaSemana) {
    tz.TZDateTime programada = _proximaHora(hora, minuto);
    while (programada.weekday != diaSemana) {
      programada = programada.add(const Duration(days: 1));
    }
    return programada;
  }
}