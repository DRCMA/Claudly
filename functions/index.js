const functions = require("firebase-functions/v1"); // 1. Importamos TODO de la v1
const { auth } = functions; // 2. Extraemos auth para que tu código antiguo de limpieza siga funcionando
const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

exports.limpiezaDatosUsuario = auth.user().onDelete(async (user) => {
    const db = admin.firestore();
    const uid = user.uid;

    console.log(`[D&C] Purga total para el UID: ${uid}`);

    try {
        const batch = db.batch();

        // --- 1. BORRAR PERFIL Y SUBCOLECCIONES (users) ---
        // Borramos los documentos de la subcolección 'amigos' para que no queden fantasmas
        const amigosSnapshot = await db.collection("users").doc(uid).collection("amigos").get();
        amigosSnapshot.forEach(doc => batch.delete(doc.ref));
        
        // Borramos el documento principal del usuario
        const userRef = db.collection("users").doc(uid);
        batch.delete(userRef);

        // --- 2. GESTIÓN DE DIARIOS (userId) ---
        const diariosSnapshot = await db.collection("diarios").where("userId", "==", uid).get();

        for (const diarioDoc of diariosSnapshot.docs) {
            const data = diarioDoc.data();
            const colaboradores = data.colaboradores || [];
            const otros = colaboradores.filter(id => id !== uid);

            if (otros.length === 0) {
                // Si estaba solo, borramos diario y recuerdos
                const recuerdos = await diarioDoc.ref.collection("recuerdos").get();
                recuerdos.forEach(rec => batch.delete(rec.ref));
                batch.delete(diarioDoc.ref);
            } else {
                // Si es compartido, lo desvinculamos
                batch.update(diarioDoc.ref, {
                    userId: null,
                    propietarioEstado: "eliminado",
                    colaboradores: otros
                });
            }
        }

        // --- 3. QUITAR DE DIARIOS AJENOS (colaboradores) ---
        const participaciones = await db.collection("diarios").where("colaboradores", "array-contains", uid).get();
        participaciones.forEach(doc => {
            if (doc.data().userId !== uid) {
                batch.update(doc.ref, {
                    colaboradores: admin.firestore.FieldValue.arrayRemove(uid)
                });
            }
        });

        await batch.commit();
        console.log(`[D&C] Limpieza completa: Perfil, Amigos y Diarios eliminados.`);
        return null;
    } catch (error) {
        console.error("[D&C ERROR]", error);
        return null;
    }
});

exports.notificarNuevaSolicitud = functions.firestore
  .document("solicitudes/{solicitudId}") // <--- Aquí es donde vigila la colección global
  .onCreate(async (snap, context) => {
    
    const datosSolicitud = snap.data();
    const userId = datosSolicitud.receptorId; // El ID del que recibe la petición
    const nombrePeticion = datosSolicitud.emisorMote || "Alguien"; // El mote del que la envía

    if (!userId) {
        console.log("No se encontró receptorId en el documento de la solicitud.");
        return null;
    }

    // 1. Buscamos el token del usuario que recibe la notificación
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) {
        console.log("No se encontró token FCM para el usuario receptor:", userId);
        return null;
    }

    // 2. Preparamos el mensaje push universal
    const payload = {
      notification: {
        title: "¡Nueva solicitud de amistad!",
        body: `${nombrePeticion} quiere ser tu amigo en Claud.`
      },
      token: fcmToken
    };

    // 3. Enviamos la notificación al dispositivo de forma nativa
    try {
        await admin.messaging().send(payload);
        console.log("Notificación push enviada con éxito al usuario:", userId);
        return null;
    } catch (error) {
        console.error("Error al enviar la notificación push:", error);
        return null;
    }
  });