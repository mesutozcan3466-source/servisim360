"use strict";

const functions = require("firebase-functions");
const admin     = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// ── Haversine (metre) ────────────────────────────────────────
function haversine(lat1, lon1, lat2, lon2) {
  const R  = 6371000;
  const dL = (lat2 - lat1) * Math.PI / 180;
  const dN = (lon2 - lon1) * Math.PI / 180;
  const a  = Math.sin(dL / 2) * Math.sin(dL / 2) +
             Math.cos(lat1 * Math.PI / 180) *
             Math.cos(lat2 * Math.PI / 180) *
             Math.sin(dN / 2) * Math.sin(dN / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── 1. Surucu konum guncellendi → Veli FCM ──────────────────
exports.surucuKonumBildirimi = functions.firestore
  .document("surucu_konumlar/{surucuId}")
  .onWrite(async (change, context) => {
    const sonra = change.after.data();
    if (!sonra || !sonra.konum) return null;

    const surucuId = context.params.surucuId;
    const firmaId  = sonra.firmaId;
    if (!firmaId) return null;

    const sLat = sonra.konum.latitude;
    const sLon = sonra.konum.longitude;

    const ogrSnap = await db.collection("students")
      .where("firmaId",  "==", firmaId)
      .where("surucuId", "==", surucuId)
      .where("durum",    "==", "aktif")
      .where("bindi",    "==", false)
      .get();

    const promises = [];

    for (const ogrDoc of ogrSnap.docs) {
      const ogr = ogrDoc.data();
      if (!ogr.konum) continue;

      const mesafe = haversine(
        sLat, sLon,
        ogr.konum.latitude,
        ogr.konum.longitude
      );

      if (!ogr.uid) continue;
      const kulDoc = await db.collection("kullanicilar")
        .doc(ogr.uid).get();
      const fcmToken = kulDoc.data() && kulDoc.data().fcmToken;
      if (!fcmToken) continue;

      const onceki = change.before.data();
      const oncekiMesafe = onceki && onceki.konum
        ? haversine(
            onceki.konum.latitude, onceki.konum.longitude,
            ogr.konum.latitude,    ogr.konum.longitude
          )
        : 9999;

      if (mesafe <= 500 && oncekiMesafe > 500) {
        promises.push(admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Servis Yaklasıyor",
            body: ogr.ad + " icin servis " + Math.round(mesafe) + "m uzakta",
          },
          data: { tip: "yaklasıyor", mesafe: String(Math.round(mesafe)) },
        }));
      }

      if (mesafe <= 100 && oncekiMesafe > 100) {
        promises.push(admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Servis Duraga Geliyor!",
            body: ogr.ad + " icin servis duraginiza cok yakin",
          },
          data: { tip: "duraga_geldi", mesafe: String(Math.round(mesafe)) },
        }));
      }
    }

    return Promise.all(promises);
  });

// ── 2. Yeni veli basvurusu → Admin FCM ──────────────────────
exports.yeniBasvuruBildirimi = functions.firestore
  .document("veli_basvurular/{basvuruId}")
  .onCreate(async (snap, context) => {
    const data    = snap.data();
    const firmaId = data.firmaId;
    if (!firmaId) return null;

    const adminSnap = await db.collection("kullanicilar")
      .where("firmaId", "==", firmaId)
      .where("rol", "in", ["admin", "firmaAdmin"])
      .get();

    const promises = [];
    for (const adminDoc of adminSnap.docs) {
      const fcmToken = adminDoc.data().fcmToken;
      if (!fcmToken) continue;
      promises.push(admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Yeni Veli Basvurusu",
          body: data.ogrenciAdi + " - " + data.veliAdi + " kayit olmak istiyor",
        },
        data: {
          tip: "yeni_basvuru",
          basvuruId: context.params.basvuruId,
        },
      }));
    }
    return Promise.all(promises);
  });

// ── 3. Yoklama → Sofor FCM ───────────────────────────────────
exports.yoklamaBildirimi = functions.firestore
  .document("absence_requests/{reqId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data.surucuId) return null;

    const kulDoc = await db.collection("kullanicilar")
      .doc(data.surucuId).get();
    const fcmToken = kulDoc.data() && kulDoc.data().fcmToken;
    if (!fcmToken) return null;

    return admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "Ogrenci Bugün Gelmiyor",
        body: data.ogrenciAdi + " bugun servise binmeyecek",
      },
      data: { tip: "yoklama", ogrenciId: data.ogrenciId || "" },
    });
  });

// ── 4. Acil durum → Admin FCM (yuksek oncelik) ───────────────
exports.acilDurumBildirimi = functions.firestore
  .document("acil_durumlar/{acilId}")
  .onCreate(async (snap, context) => {
    const data      = snap.data();
    const surucuId  = data.surucuId;
    if (!surucuId) return null;

    const kulDoc  = await db.collection("kullanicilar").doc(surucuId).get();
    const firmaId = kulDoc.data() && kulDoc.data().firmaId;
    if (!firmaId) return null;

    const adminSnap = await db.collection("kullanicilar")
      .where("firmaId", "==", firmaId)
      .where("rol", "in", ["admin", "firmaAdmin", "superAdmin"])
      .get();

    const promises = [];
    for (const adminDoc of adminSnap.docs) {
      const fcmToken = adminDoc.data().fcmToken;
      if (!fcmToken) continue;
      promises.push(admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "ACIL DURUM!",
          body: "Surucu: " + (data.turBaslik || "Acil") + " bildirimi gonderdi",
        },
        android: { priority: "high" },
        apns:    { headers: { "apns-priority": "10" } },
        data: {
          tip: "acil_durum",
          acilId: context.params.acilId,
        },
      }));
    }
    return Promise.all(promises);
  });

// ── 5. Guzergah temizle — her gece 02:00 ────────────────────
exports.guzergahTemizle = functions.pubsub
  .schedule("0 2 * * *")
  .timeZone("Europe/Istanbul")
  .onRun(async () => {
    const dortGunOnce = new Date();
    dortGunOnce.setDate(dortGunOnce.getDate() - 4);

    const snap = await db.collection("guzergah_kayitlar")
      .where("tarih", "<", dortGunOnce)
      .get();

    const batch = db.batch();
    snap.docs.forEach(function(doc) { batch.delete(doc.ref); });
    await batch.commit();

    console.log("Temizlendi: " + snap.size + " guzergah kaydi silindi");
    return null;
  });

// ── 6. FCM token kaydet — Flutter callable ───────────────────
exports.fcmTokenKaydet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated", "Giris gerekli"
    );
  }
  const token = data.token;
  if (!token) {
    throw new functions.https.HttpsError(
      "invalid-argument", "Token gerekli"
    );
  }
  await db.collection("kullanicilar").doc(context.auth.uid).update({
    fcmToken: token,
    fcmGuncellemeTarihi: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { basarili: true };
});