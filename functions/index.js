const functions = require("firebase-functions/v1"); 
const { auth } = functions;
const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

// =========================================================================
// 1. Limpieza de cuenta al borrar usuario
// =========================================================================
exports.limpiezaDatosUsuario = auth.user().onDelete(async (user) => {
    const db = admin.firestore();
    const uid = user.uid;
    console.log(`[D&C] Purga total para el UID: ${uid}`);

    try {
        const batch = db.batch();

        const amigosSnapshot = await db.collection("users").doc(uid).collection("amigos").get();
        amigosSnapshot.forEach(doc => batch.delete(doc.ref));
        
        const userRef = db.collection("users").doc(uid);
        batch.delete(userRef);

        const diariosSnapshot = await db.collection("diarios").where("userId", "==", uid).get();
        for (const diarioDoc of diariosSnapshot.docs) {
            const data = diarioDoc.data();
            const colaboradores = data.colaboradores || [];
            const otros = colaboradores.filter(id => id !== uid);

            if (otros.length === 0) {
                const recuerdos = await diarioDoc.ref.collection("recuerdos").get();
                recuerdos.forEach(rec => batch.delete(rec.ref));
                batch.delete(diarioDoc.ref);
            } else {
                batch.update(diarioDoc.ref, {
                    userId: null,
                    propietarioEstado: "eliminado",
                    colaboradores: otros
                });
            }
        }

        const participaciones = await db.collection("diarios").where("colaboradores", "array-contains", uid).get();
        participaciones.forEach(doc => {
            if (doc.data().userId !== uid) {
                batch.update(doc.ref, { colaboradores: admin.firestore.FieldValue.arrayRemove(uid) });
            }
        });

        await batch.commit();
        return null;
    } catch (error) {
        console.error("[D&C ERROR]", error);
        return null;
    }
});

// =========================================================================
// 2. Solicitudes de Amistad (Sincronizado con Settings)
// =========================================================================
exports.notificarNuevaSolicitud = functions.firestore
  .document("solicitudes/{solicitudId}")
  .onCreate(async (snap, context) => {
    const datosSolicitud = snap.data();
    const userId = datosSolicitud.receptorId; 
    const nombrePeticion = datosSolicitud.emisorMote || "Alguien"; 

    if (!userId) return null;

    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;
    
    // VERIFICACIÓN DE AJUSTES:
    const quiereAmistad = userData?.preferenciasNotificaciones?.amistad !== false;

    if (!fcmToken || !quiereAmistad) {
        console.log("Token no encontrado o notificaciones apagadas para:", userId);
        return null;
    }

    const payload = {
      notification: { title: "¡Nueva solicitud de amistad!", body: `${nombrePeticion} quiere ser tu amigo en Claudly.` },
      token: fcmToken
    };

    try { await admin.messaging().send(payload); } catch (e) { console.error("Error push:", e); }
    return null;
  });

// =========================================================================
// 3. Invitación a Diarios (Sincronizado con Settings)
// =========================================================================
exports.notificarInvitacionDiario = functions.firestore
  .document("diarios/{diarioId}")
  .onUpdate(async (change, context) => {
    const datosAntes = change.before.data();
    const datosDespues = change.after.data();
    const invitadosAntes = datosAntes.invitados || [];
    const invitadosDespues = datosDespues.invitados || [];
    
    const nuevosInvitados = invitadosDespues.filter(id => !invitadosAntes.includes(id));
    if (nuevosInvitados.length === 0) return null;

    const nombreDiario = datosDespues.nombre || "un diario";

    const promesas = nuevosInvitados.map(async (userId) => {
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        const userData = userDoc.data();
        const fcmToken = userData?.fcmToken;
        
        // VERIFICACIÓN DE AJUSTES:
        const quiereDiario = userData?.preferenciasNotificaciones?.diario !== false;

        if (!fcmToken || !quiereDiario) return null;

        const payload = {
          notification: { title: "¡Nueva invitación a un diario!", body: `Te han invitado a colaborar en el diario '${nombreDiario}'.` },
          token: fcmToken
        };

        try { await admin.messaging().send(payload); } catch (e) {}
    });

    await Promise.all(promesas);
    return null;
  });

// =========================================================================
// 4. Muro Global (Sincronizado con Settings)
// =========================================================================
exports.notificarNuevoMensajeMuro = functions.firestore
  .document("muro/{mensajeId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const autorId = data.autorId;
    const esAdmin = data.tipo === "administrador";

    const usersSnap = await admin.firestore().collection("users").get();
    const tokens = [];

    // 1. Recopilamos todos los tokens válidos
    usersSnap.forEach(doc => {
        const userData = doc.data();
        const quiereMuro = userData.preferenciasNotificaciones?.muro !== false;

        if (doc.id !== autorId && userData.fcmToken && quiereMuro) {
            tokens.push(userData.fcmToken);
        }
    });

    if (tokens.length === 0) {
        console.log("No hay usuarios a los que notificar en el muro.");
        return null;
    }

    const tituloPush = esAdmin ? "📢 Anuncio de Claudly" : `Muro: Nuevo post de ${data.autor || "Alguien"}`;
    const cuerpoPush = (data.mensaje || "").length > 60 ? data.mensaje.substring(0, 60) + "..." : data.mensaje;

    // 2. SOLUCIÓN: Usamos el mismo método exacto que usas en las invitaciones de diario
    const promesas = tokens.map(async (fcmToken) => {
        const payload = {
            notification: { 
                title: tituloPush, 
                body: cuerpoPush 
            },
            token: fcmToken // Se lo mandamos individualmente
        };

        try { 
            await admin.messaging().send(payload); 
            console.log("Notificación enviada con éxito.");
        } catch (e) { 
            console.error("Error al enviar push de muro:", e); 
        }
    });

    // Esperamos a que salgan todas las notificaciones
    await Promise.all(promesas);
    return null;
  });