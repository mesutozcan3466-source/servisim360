const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

const db  = admin.firestore();
const msg = admin.messaging();

// ── Devamsizlik bildirimi → Sofore push gonder ──────────────
exports.devamsizlikBildirimi = functions.firestore
  .document('absence_requests/{reqId}')
  .onCreate(async (snap, context) => {
    try {
      const data      = snap.data();
      const surucuId  = data.surucuId;
      const ogrenciAd = data.ogrenciAd  || 'Ogrenci';
      const aciklama  = data.aciklama   || 'Devamsizlik bildirimi';

      if (!surucuId) return null;

      // Soforu bul — fcmToken al
      const surucuDoc = await db.collection('drivers')
          .doc(surucuId).get();
      if (!surucuDoc.exists) return null;

      const token = surucuDoc.data().fcmToken;
      if (!token) return null;

      await msg.send({
        token,
        notification: {
          title: `${ogrenciAd} Devamsiz`,
          body:  aciklama,
        },
        data: {
          tip:    'devamsizlik',
          reqId:  context.params.reqId,
        },
        android: {
          priority: 'high',
          notification: { channelId: 'servisim360_bildirim' },
        },
        apns: {
          payload: { aps: { badge: 1, sound: 'default' } },
        },
      });

      console.log(`Devamsizlik push gonderildi: ${surucuId}`);
    } catch (e) {
      console.error('devamsizlikBildirimi hata:', e);
    }
    return null;
  });

// ── Binis bildirimi → Veliye push gonder ───────────────────
exports.binisBildirimi = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    try {
      const data    = snap.data();
      const aliciId = data.aliciId;
      const baslik  = data.baslik || 'Servis Bildirimi';
      const mesaj   = data.mesaj  || '';

      if (!aliciId) return null;

      // Kullanicinin FCM tokenini bul
      const kulDoc = await db.collection('kullanicilar')
          .doc(aliciId).get();
      if (!kulDoc.exists) return null;

      const token = kulDoc.data().fcmToken;
      if (!token) return null;

      await msg.send({
        token,
        notification: { title: baslik, body: mesaj },
        data: {
          tip:     data.tip     || 'bildirim',
          notifId: context.params.notifId,
        },
        android: {
          priority: 'high',
          notification: { channelId: 'servisim360_bildirim' },
        },
        apns: {
          payload: { aps: { badge: 1, sound: 'default' } },
        },
      });

      console.log(`Push gonderildi alici: ${aliciId}`);
    } catch (e) {
      console.error('binisBildirimi hata:', e);
    }
    return null;
  });

// ── 500m yaklasma → Veliye push gonder ─────────────────────
exports.yaklasmaUyarisi = functions.firestore
  .document('drivers/{driverId}')
  .onUpdate(async (change, context) => {
    try {
      const onceki = change.before.data();
      const sonraki = change.after.data();

      // Sadece konum guncellendiyse devam et
      if (!sonraki.servisAktif) return null;
      const yeniKonum = sonraki.konum;
      if (!yeniKonum) return null;

      // Bu sofore atanmis ogrencileri bul
      const ogrSnap = await db.collection('students')
          .where('surucuId', isEqualTo: context.params.driverId)
          .where('bindi', isEqualTo: false)
          .get();

      for (const ogrDoc of ogrSnap.docs) {
        const ogr    = ogrDoc.data();
        const veliId = ogr.veliId;
        if (!veliId) continue;

        const ogrKonum = ogr.konum;
        if (!ogrKonum) continue;

        // Mesafe hesapla (Haversine)
        const mesafe = _haversine(
          yeniKonum.latitude,  yeniKonum.longitude,
          ogrKonum.latitude,   ogrKonum.longitude,
        );

        // 500m icindeyse bildirim gonder
        if (mesafe <= 500) {
          const kulDoc = await db.collection('kullanicilar')
              .doc(veliId).get();
          if (!kulDoc.exists) continue;
          const token = kulDoc.data().fcmToken;
          if (!token) continue;

          const surucuAd = sonraki.ad || 'Sofor';
          await msg.send({
            token,
            notification: {
              title: 'Servis Yaklasıyor!',
              body:  `${surucuAd} 500 metre yakininda!`,
            },
            data: { tip: 'yaklasma' },
            android: {
              priority: 'high',
              notification: { channelId: 'servisim360_bildirim' },
            },
            apns: {
              payload: { aps: { badge: 1, sound: 'default' } },
            },
          });
        }
      }
    } catch (e) {
      console.error('yaklasmaUyarisi hata:', e);
    }
    return null;
  });

function _haversine(lat1, lon1, lat2, lon2) {
  const R   = 6371000;
  const dL  = (lat2 - lat1) * Math.PI / 180;
  const dLn = (lon2 - lon1) * Math.PI / 180;
  const a   = Math.sin(dL/2) * Math.sin(dL/2) +
      Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLn/2) * Math.sin(dLn/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}