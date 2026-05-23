import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // <--- LIBRERÍA NUEVA

class LocalAlarmService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Inicializa la base de datos de horas
    tz.initializeTimeZones();

    // 2. Lee la zona horaria real de tu móvil (Ej: "Europe/Madrid") y la sincroniza
    final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = tzInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 3. Configuración visual
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('icono_notif');
    
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

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  static Future<void> programarAlarma({
    required String diarioId,
    required String nombreDiario,
    required Map<String, dynamic> config,
  }) async {
    // Transformamos el ID en un número positivo seguro para el límite de 32 bits de Android
    final int notifId = diarioId.hashCode.abs() % 2147483647;
    
    // Primero cancelamos cualquier alarma anterior para no duplicar
    await _plugin.cancel(notifId);

    final String tipo = config['tipo'] ?? 'desactivada';
    final int hora = config['hora'] ?? 10;
    final int minuto = config['minuto'] ?? 0;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_recordatorios', 
      'Recordatorios de Diarios',
      channelDescription: 'Avisos para escribir en tus diarios',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'icono_notif',
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // Calculamos la fecha en la zona horaria CORRECTA del móvil
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
        matchDateTimeComponents: DateTimeComponents.time, // Se repetirá todos los días
      );
    } 
    else if (tipo == 'semanal') {
      List<int> dias = List<int>.from(config['dias'] ?? []);
      for (int dia in dias) {
        // Un ID diferente por cada día para que no se sobreescriban
        int subId = (notifId + dia).abs() % 2147483647;
        tz.TZDateTime diaProg = _proximoDiaDeLaSemana(hora, minuto, dia);
        
        await _plugin.zonedSchedule(
          subId, 
          '¡Hora de escribir!',
          'Toca actualizar tu diario semanal "$nombreDiario".',
          diaProg,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    } 
    else if (tipo == 'personalizada') {
      int intervalo = config['intervalo'] ?? 1;
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
    // Ahora "tz.local" sí sabe la hora de tu país
    final tz.TZDateTime ahora = tz.TZDateTime.now(tz.local);
    tz.TZDateTime programada = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, hora, minuto);
    
    // Si la hora ya ha pasado hoy, la pasa al día siguiente
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

  // --- NUEVO: Método para notificaciones instantáneas (Social) ---
  static Future<void> mostrarNotificacionInstantanea({
    required int id,
    required String titulo,
    required String cuerpo,
  }) async {
    // Creamos un canal diferente en Android para cosas sociales
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'canal_social', 
      'Social y Amigos',
      channelDescription: 'Avisos de nuevas solicitudes y mensajes',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'icono_notif', // Usamos tu silueta blanca para que no salga el cuadrado negro
    );
    
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    // .show() lanza la notificación en el acto
    await _plugin.show(
      id,
      titulo,
      cuerpo,
      platformDetails,
    );
  }
}