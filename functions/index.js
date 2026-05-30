const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();

const db  = admin.firestore();
const msg = admin.messaging();

exports.devamsizlikBildirimi = onDocumentCreated(
  'absence_requests/{reqId}',
  async (event) => {
    try {
      const data      = event.data.data();
      const surucuId  = data.surucuId;
      const ogrenciAd = data.ogrenciAd || 'Ogrenci';
      const aciklama  = data.aciklama  || 'Devamsizlik';
      if (!surucuId) return null;
      const doc = await db.collection('drivers').doc(surucuId).get();
      if (!doc.exists) return null;
      const token = doc.data().fcmToken;
      if (!token) return null;
      await msg.send({
        token,
        notification: { title: ogrenciAd + ' Devamsiz', body: aciklama },
        android: { priority: 'high', notification: { channelId: 'servisim360_bildirim' } },
        apns: { payload: { aps: { badge: 1, sound: 'default' } } },
      });
    } catch (e) { console.error('devamsizlik hata:', e); }
    return null;
  }
);

exports.binisBildirimi = onDocumentCreated(
  'notifications/{notifId}',
  async (event) => {
    try {
      const data    = event.data.data();
      const aliciId = data.aliciId;
      const baslik  = data.baslik || 'Servis Bildirimi';
      const mesaj   = data.mesaj  || '';
      if (!aliciId) return null;
      const doc = await db.collection('kullanicilar').doc(aliciId).get();
      if (!doc.exists) return null;
      const token = doc.data().fcmToken;
      if (!token) return null;
      await msg.send({
        token,
        notification: { title: baslik, body: mesaj },
        android: { priority: 'high', notification: { channelId: 'servisim360_bildirim' } },
        apns: { payload: { aps: { badge: 1, sound: 'default' } } },
      });
    } catch (e) { console.error('binis hata:', e); }
    return null;
  }
);

exports.yaklasmaUyarisi = onDocumentUpdated(
  'drivers/{driverId}',
  async (event) => {
    try {
      const sonraki   = event.data.after.data();
      if (!sonraki.servisAktif) return null;
      const yeniKonum = sonraki.konum;
      if (!yeniKonum) return null;
      const driverId  = event.params.driverId;
      const ogrSnap   = await db.collection('students')
        .where('surucuId', '==', driverId)
        .where('bindi', '==', false).get();
      const promises  = [];
      ogrSnap.docs.forEach((ogrDoc) => {
        const ogr      = ogrDoc.data();
        if (!ogr.veliId || !ogr.konum) return;
        const mesafe   = haversine(
          yeniKonum.latitude, yeniKonum.longitude,
          ogr.konum.latitude, ogr.konum.longitude
        );
        if (mesafe <= 500) {
          const p = db.collection('kullanicilar').doc(ogr.veliId).get()
            .then((d) => {
              if (!d.exists || !d.data().fcmToken) return null;
              return msg.send({
                token: d.data().fcmToken,
                notification: {
                  title: 'Servis Yaklasıyor!',
                  body: (sonraki.ad || 'Sofor') + ' 500m yakininda!',
                },
                android: { priority: 'high', notification: { channelId: 'servisim360_bildirim' } },
                apns: { payload: { aps: { badge: 1, sound: 'default' } } },
              });
            });
          promises.push(p);
        }
      });
      await Promise.all(promises);
    } catch (e) { console.error('yaklasma hata:', e); }
    return null;
  }
);

exports.aiProxy = onRequest(
  { cors: true, secrets: ['ANTHROPIC_KEY'] },
  async (req, res) => {
    try {
      if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
      }
      const apiKey = process.env.ANTHROPIC_KEY;
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
  const R   = 6371000;
  const dL  = (lat2 - lat1) * Math.PI / 180;
  const dLn = (lon2 - lon1) * Math.PI / 180;
  const a   = Math.sin(dL/2) * Math.sin(dL/2) +
    Math.cos(lat1 * Math.PI / 180) *
    Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLn/2) * Math.sin(dLn/2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}