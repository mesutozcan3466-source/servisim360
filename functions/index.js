const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();

const db  = admin.firestore();
const msg = admin.messaging();

// ── Devamsizlik bildirimi → Sofore push ─────────────────────
exports.devamsizlikBildirimi = onDocumentCreated(
  'absence_requests/{reqId}',
  async (event) => {
    try {
      const data      = event.data.data();
      const surucuId  = data.surucuId;
      const ogrenciAd = data.ogrenciAd || 'Ogrenci';
      const aciklama  = data.aciklama  || 'Devamsizlik bildirimi';
      if (!surucuId) return null;

      const surucuDoc = await db.collection('drivers').doc(surucuId).get();
      if (!surucuDoc.exists) return null;
      const token = surucuDoc.data().fcmToken;
      if (!token) return null;

      await msg.send({
        token: token,
        notification: {
          title: ogrenciAd + ' Devamsiz',
          body:  aciklama,
        },
        android: {
          priority: 'high',
          notification: { channelId: 'servisim360_bildirim' },
        },
        apns: {
          payload: { aps: { badge: 1, sound: 'default' } },
        },
      });
      console.log('Devamsizlik push gonderildi: ' + surucuId);
    } catch (e) {
      console.error('devamsizlikBildirimi hata:', e);
    }
    return null;
  }
);

// ── Bildirim → Veliye push ──────────────────────────────────
exports.binisBildirimi = onDocumentCreated(
  'notifications/{notifId}',
  async (event) => {
    try {
      const data    = event.data.data();
      const aliciId = data.aliciId;
      const baslik  = data.baslik || 'Servis Bildirimi';
      const mesaj   = data.mesaj  || '';
      if (!aliciId) return null;

      const kulDoc = await db.collection('kullanicilar').doc(aliciId).get();
      if (!kulDoc.exists) return null;
      const token = kulDoc.data().fcmToken;
      if (!token) return null;

      await msg.send({
        token: token,
        notification: { title: baslik, body: mesaj },
        android: {
          priority: 'high',
          notification: { channelId: 'servisim360_bildirim' },
        },
        apns: {
          payload: { aps: { badge: 1, sound: 'default' } },
        },
      });
      console.log('Push gonderildi alici: ' + aliciId);
    } catch (e) {
      console.error('binisBildirimi hata:', e);
    }
    return null;
  }
);

// ── 500m yaklasma → Veliye push ─────────────────────────────
exports.yaklasmaUyarisi = onDocumentUpdated(
  'drivers/{driverId}',
  async (event) => {
    try {
      const sonraki   = event.data.after.data();
      if (!sonraki.servisAktif) return null;
      const yeniKonum = sonraki.konum;
      if (!yeniKonum) return null;
      const driverId  = event.params.driverId;

      const ogrSnap = await db.collection('students')
        .where('surucuId', '==', driverId)
        .where('bindi',    '==', false)
        .get();

      const promises = [];
      ogrSnap.docs.forEach(function(ogrDoc) {
        const ogr      = ogrDoc.data();
        const veliId   = ogr.veliId;
        if (!veliId) return;
        const ogrKonum = ogr.konum;
        if (!ogrKonum) return;

        const mesafe = haversine(
          yeniKonum.latitude,  yeniKonum.longitude,
          ogrKonum.latitude,   ogrKonum.longitude
        );

        if (mesafe <= 500) {
          const p = db.collection('kullanicilar').doc(veliId).get()
            .then(function(kulDoc) {
              if (!kulDoc.exists) return null;
              const token = kulDoc.data().fcmToken;
              if (!token) return null;
              const surucuAd = sonraki.ad || 'Sofor';
              return msg.send({
                token: token,
                notification: {
                  title: 'Servis Yaklasıyor!',
                  body:  surucuAd + ' 500 metre yakininda!',
                },
                android: {
                  priority: 'high',
                  notification: { channelId: 'servisim360_bildirim' },
                },
                apns: {
                  payload: { aps: { badge: 1, sound: 'default' } },
                },
              });
            });
          promises.push(p);
        }
      });

      await Promise.all(promises);
    } catch (e) {
      console.error('yaklasmaUyarisi hata:', e);
    }
    return null;
  }
);

// ── Anthropic AI Proxy ───────────────────────────────────────
exports.aiProxy = onRequest(
  { cors: true },
  async (req, res) => {
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }

      // API key environment variable olarak set edilmeli
      // firebase functions:config:set anthropic.key="YOUR_KEY"
      const apiKey = process.env.ANTHROPIC_KEY ||
          (functions.config().anthropic || {}).key || '';

      if (!apiKey) {
        res.status(500).json({ error: 'API key not configured' });
        return;
      }

      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify(req.body),
      });

      const data = await response.json();
      res.status(response.status).json(data);
    } catch (e) {
      console.error('aiProxy hata:', e);
      res.status(500).json({ error: e.message });
    }
  }
);

function haversine(lat1, lon1, lat2, lon2) {
  var R   = 6371000;
  var dL  = (lat2 - lat1) * Math.PI / 180;
  var dLn = (lon2 - lon1) * Math.PI / 180;
  var a   = Math.sin(dL/2) * Math.sin(dL/2) +
      Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLn/2) * Math.sin(dLn/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}