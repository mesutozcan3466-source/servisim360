const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated,
 onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore,
 FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
initializeApp();
const db = getFirestore();
const fcm = getMessaging();
// ═══════════════════════════════════════════════════════════════════════════
// YARDIMCI FONKSİYONLAR
// ═══════════════════════════════════════════════════════════════════════════
/**
 * Bir kullanicinin FCM token'ina bildirim gonder
 */
async function fcmGonder(token, baslik, govde, data = {}) {
 if (!token) return;
 try {
 await fcm.send({
 token,
 notification: { title: baslik, body: govde },
 data,
 android: { priority: "high" },
 apns: { payload: { aps: { sound: "default" } } },
 });
 } catch (err) {
 console.error("FCM gonderim hatasi:", err.message);
 }
}
/**
 * Firestore'a bildirim belgesi yaz
 */
async function firestoreBildirimYaz(aliciId, firmaId, baslik, mesaj, tip = "sistem") {
 await db.collection("notifications").add({
 aliciId,
 firmaId: firmaId ?? "",
 baslik,
 mesaj,
 tip,
 okundu: false,
 tarih: FieldValue.serverTimestamp(),
 });
}
/**
 * Kullanicinin FCM token'ini getir
 */
async function fcmTokenAl(uid) {
 const doc = await db.collection("kullanicilar").doc(uid).get();
 return doc.exists ? (doc.data().fcmToken ?? null) : null;
}
// ═══════════════════════════════════════════════════════════════════════════
// 1. GÜNLÜK LİSANS BİTİŞ KONTROLÜ
// Her gün saat 08:00 Türkiye saatine çalışır (UTC+3 → 05:00 UTC)
// ═══════════════════════════════════════════════════════════════════════════
exports.lisansBitisKontrol = onSchedule(
 { schedule: "0 5 * * *", timeZone: "Europe/Istanbul" },
 async () => {
 const bugun = new Date();
 const yedi_gun = new Date(bugun.getTime() + 7 * 24 * 60 * 60 * 1000);
 const uc_gun = new Date(bugun.getTime() + 3 * 24 * 60 * 60 * 1000);
 // Bitmek uzere olan lisanslari bul (7 gun icerisinde biten)
 const snap = await db.collection("licenses")
 .where("durum", "==", "aktif")
 .where("bitisTarihi", "<=", yedi_gun)
 .get();
 for (const doc of snap.docs) {
 const lisans = doc.data();
 const bitis = lisans.bitisTarihi.toDate();
 const firmaId = lisans.firmaId;
 const kalan = Math.ceil((bitis - bugun) / (1000 * 60 * 60 * 24));
 // Suresi dolmussa lisansi pasife al ve firmaya yansit
 if (bitis < bugun) {
 await doc.ref.update({ durum: "suresi_doldu" });
 await db.collection("firms").doc(firmaId).update({ durum: "pasif" });
 // Firma adminini bul ve bildir
 const adminSnap = await db.collection("kullanicilar")
 .where("firmaId", "==", firmaId)
 .where("rol", "in", ["admin", "firmaAdmin"])
 .limit(1).get();
 if (!adminSnap.empty) {
 const adminId = adminSnap.docs[0].id;
 const token = await fcmTokenAl(adminId);
 const mesaj = "Lisansiniz sona erdi. Lutfen yenileyin.";
 await fcmGonder(token, "Lisans Suresi Doldu", mesaj);
 await firestoreBildirimYaz(adminId, firmaId,
 "Lisans Suresi Doldu", mesaj, "lisans");
 }
 continue;
 }
 // 3 veya 7 gun kalmissa uyari gonder
 if (kalan <= 7) {
 const adminSnap = await db.collection("kullanicilar")
 .where("firmaId", "==", firmaId)
 .where("rol", "in", ["admin", "firmaAdmin"])
 .limit(1).get();
 if (!adminSnap.empty) {
 const adminId = adminSnap.docs[0].id;
 const token = await fcmTokenAl(adminId);
 const mesaj = `Lisansinizin bitmesine ${kalan} gun kaldi. Yenilemeyi unutmayin.`;
 await fcmGonder(token, "Lisans Uyarisi", mesaj);
 await firestoreBildirimYaz(adminId, firmaId,
 "Lisans Uyarisi", mesaj, "lisans");
 }
 }
 }
 console.log(`Lisans kontrolu tamamlandi. ${snap.size} lisans incelendi.`);
 }
);
// ═══════════════════════════════════════════════════════════════════════════
// 2. YENİ FIRMA KAYDINDA SUPER ADMIN BİLDİRİMİ
// ═══════════════════════════════════════════════════════════════════════════
exports.yeniFirmaKaydi = onDocumentCreated("firms/{firmaId}", async (event) => {
 const firma = event.data.data();
 const firmaId = event.params.firmaId;
 // Super admin'leri bul
 const superAdminSnap = await db.collection("kullanicilar")
 .where("rol", "==", "superAdmin")
 .get();
 const baslik = "Yeni Firma Basvurusu";
 const mesaj = `${firma.firmaAdi ?? "Yeni firma"} onay bekliyor.`;
 for (const adminDoc of superAdminSnap.docs) {
 const adminId = adminDoc.id;
 const token = await fcmTokenAl(adminId);
 await fcmGonder(token, baslik, mesaj, { firmaId, tip: "yeni_firma" });
 await firestoreBildirimYaz(adminId, firmaId, baslik, mesaj, "firma");
 }
 console.log(`Yeni firma bildirimi gonderildi: ${firmaId}`);
});
// ═══════════════════════════════════════════════════════════════════════════
// 3. FİRMA DURUMU DEĞİŞTİĞİNDE BİLDİRİM
// ═══════════════════════════════════════════════════════════════════════════
exports.firmaDurumuDegisti = onDocumentUpdated("firms/{firmaId}", async (event) => {
 const once = event.data.before.data();
 const sonra = event.data.after.data();
 const firmaId = event.params.firmaId;
 // Durum degismediyse cik
 if (once.durum === sonra.durum) return;
 const adminSnap = await db.collection("kullanicilar")
 .where("firmaId", "==", firmaId)
 .where("rol", "in", ["admin", "firmaAdmin"])
 .limit(1).get();
 if (adminSnap.empty) return;
 const adminId = adminSnap.docs[0].id;
 const token = await fcmTokenAl(adminId);
 let baslik, mesaj;
 switch (sonra.durum) {
 case "aktif":
 baslik = "Hesabiniz Onaylandi!";
 mesaj = "Servisim360 hesabiniz aktif edildi. Iyi servisler!";
 break;
 case "pasif":
 baslik = "Hesabiniz Pasife Alindi";
 mesaj = "Hesabiniz pasife alindi. Detay icin destek ile iletisime gecin.";
 break;
 case "askida":
 baslik = "Hesabiniz Askiya Alindi";
 mesaj = "Hesabiniz gecici olarak askiya alindi.";
 break;
 default:
 return;
 }
 await fcmGonder(token, baslik, mesaj, { firmaId, tip: "firma_durum" });
 await firestoreBildirimYaz(adminId, firmaId, baslik, mesaj, "firma");
 console.log(`Firma durum bildirimi: ${firmaId} → ${sonra.durum}`);
});
// ═══════════════════════════════════════════════════════════════════════════
// 4. YENİ DEVAMSIZLIK BİLDİRİMİ → ŞOFÖRE
// Veli devamsizlik bildirince sofor anında haberdar olsun
// ═══════════════════════════════════════════════════════════════════════════
exports.devamsizlikBildirimi = onDocumentCreated(
 "absence_requests/{reqId}",
 async (event) => {
 const req = event.data.data();
 const ogrenciId = req.ogrenciId;
 const firmaId = req.firmaId;
 if (!ogrenciId) return;
 // Ogrencinin surucusunu bul
 const ogrSnap = await db.collection("students").doc(ogrenciId).get();
 if (!ogrSnap.exists) return;
 const surucuId = ogrSnap.data().surucuId;
 if (!surucuId) return;
 // Sofor belgesini bul
 const soforSnap = await db.collection("drivers")
 .where("uid", "==", surucuId).limit(1).get();
 let soforUid = surucuId;
 if (!soforSnap.empty) {
 soforUid = soforSnap.docs[0].data().uid ?? surucuId;
 }
 const ogrAdi = ogrSnap.data().ad ?? "Ogrenci";
 const tarih = req.tarih ?? "Bugun";
 const token = await fcmTokenAl(soforUid);
 const baslik = "Devamsizlik Bildirimi";
 const mesaj = `${ogrAdi} bugun servise binmeyecek.`;
 await fcmGonder(token, baslik, mesaj, {
 ogrenciId,
 reqId: event.params.reqId,
 tip: "devamsizlik",
 });
 await firestoreBildirimYaz(soforUid, firmaId, baslik, mesaj, "devamsizlik");
 console.log(`Devamsizlik bildirimi: ${ogrAdi} → sofor ${soforUid}`);
 }
);
// ═══════════════════════════════════════════════════════════════════════════
// 5. SERVİS BAŞLADI → VELİLERE BİLDİRİM
// Sofor servisAktif = true yapinca tum veliler haberdar olsun
// ═══════════════════════════════════════════════════════════════════════════
exports.servisBasladiBildirimi = onDocumentUpdated(
 "drivers/{driverId}",
 async (event) => {
 const once = event.data.before.data();
 const sonra = event.data.after.data();
 // servisAktif false → true gecisinde tetikle
 if (once.servisAktif || !sonra.servisAktif) return;
 const surucuId = event.params.driverId;
 const firmaId = sonra.firmaId;
 // Bu soforun ogrencilerinin velilerini bul
 const ogrSnap = await db.collection("students")
 .where("surucuId", "==", surucuId)
 .where("aktif", "==", true)
 .get();
 if (ogrSnap.empty) return;
 const soforAdi = sonra.ad ?? "Sofor";
 const baslik = "Servis Yola Cikti!";
 const batch = db.batch();
 for (const ogrDoc of ogrSnap.docs) {
 const ogr = ogrDoc.data();
 const veliId = ogr.veliId;
 if (!veliId) continue;
 const ogrAdi = ogr.ad ?? "Ogrenciiniz";
 const mesaj = `${soforAdi} servise basladi. ${ogrAdi} icin takip edebilirsiniz.`;
 const token = await fcmTokenAl(veliId);
 await fcmGonder(token, baslik, mesaj, {
 surucuId,
 tip: "servis_basladi",
 });
 const notifRef = db.collection("notifications").doc();
 batch.set(notifRef, {
 aliciId: veliId,
 firmaId: firmaId ?? "",
 baslik,
 mesaj,
 tip: "servis",
 okundu: false,
 tarih: FieldValue.serverTimestamp(),
 });
 }
 await batch.commit();
 console.log(`Servis basladi bildirimi: sofor ${surucuId}, ${ogrSnap.size} veli`);
 }
);
// ═══════════════════════════════════════════════════════════════════════════
// 6. QR CHECK-IN CALLABLE FUNCTION
// Flutter'dan cagrilir, ogrenci binis/inis kaydeder
// ═══════════════════════════════════════════════════════════════════════════
exports.qrCheckIn = onCall({ region: "europe-west1" }, async (request) => {
 const { ogrenciId, tip, surucuId, firmaId } = request.data;
 // tip: "binis" veya "inis"
 if (!ogrenciId || !tip || !surucuId) {
 throw new HttpsError("invalid-argument", "Eksik parametre");
 }
 // Ogrenci belgesi kontrol
 const ogrRef = db.collection("students").doc(ogrenciId);
 const ogrDoc = await ogrRef.get();
 if (!ogrDoc.exists) {
 throw new HttpsError("not-found", "Ogrenci bulunamadi");
 }
 const ogr = ogrDoc.data();
 const ogrAdi = ogr.ad ?? "Ogrenci";
 const veliId = ogr.veliId;
 // Ogrenci belgesini guncelle
 const guncelleme = {
 [tip === "binis" ? "bindi" : "indi"]: true,
 [`${tip === "binis" ? "bindi" : "indi"}Zaman`]: FieldValue.serverTimestamp(),
 sonHareket: tip,
 sonHareketZaman: FieldValue.serverTimestamp(),
 };
 await ogrRef.update(guncelleme);
 // QR log kaydi
 await db.collection("qr_logs").add({
 ogrenciId,
 ogrenciAdi: ogrAdi,
 surucuId,
 firmaId: firmaId ?? "",
 tip,
 tarih: FieldValue.serverTimestamp(),
 });
 // Veliye bildirim
 if (veliId) {
 const mesaj = tip === "binis"
 ? `${ogrAdi} servise bindi.`
 : `${ogrAdi} servisten indi.`;
 const baslik = tip === "binis" ? "Servise Bindi" : "Servisten Indi";
 const token = await fcmTokenAl(veliId);
 await fcmGonder(token, baslik, mesaj, { ogrenciId, tip });
 await firestoreBildirimYaz(veliId, firmaId ?? "", baslik, mesaj, "qr");
 }
 return { basarili: true, ogrenciAdi: ogrAdi, tip };
});
// ═══════════════════════════════════════════════════════════════════════════
// 7. FCM TOKEN KAYDET
// Flutter app her acilista bu fonksiyonu cagirarak token gunceller
// ═══════════════════════════════════════════════════════════════════════════
exports.fcmTokenKaydet = onCall({ region: "europe-west1" }, async (request) => {
 const uid = request.auth?.uid;
 const token = request.data.token;
 if (!uid) throw new HttpsError("unauthenticated", "Giris yapilmamis");
 if (!token) throw new HttpsError("invalid-argument", "Token eksik");
 await db.collection("kullanicilar").doc(uid).update({
 fcmToken: token,
 fcmTokenGuncelleme: FieldValue.serverTimestamp(),
 });
 return { basarili: true };
});
// ═══════════════════════════════════════════════════════════════════════════
// 8. TOPLU BİLDİRİM GÖNDER (Super Admin callable)
// ═══════════════════════════════════════════════════════════════════════════
exports.topluBildirimGonder = onCall({ region: "europe-west1" }, async (request) => {
 // Sadece superAdmin cagirabilir
 const uid = request.auth?.uid;
 if (!uid) throw new HttpsError("unauthenticated", "Giris yapilmamis");
 const callerDoc = await db.collection("kullanicilar").doc(uid).get();
 if (!callerDoc.exists || callerDoc.data().rol !== "superAdmin") {
 throw new HttpsError("permission-denied", "Yetkisiz islem");
 }
 const { baslik, mesaj, hedef, hedefFirmaId } = request.data;
 if (!baslik || !mesaj) {
 throw new HttpsError("invalid-argument", "Baslik ve mesaj zorunlu");
 }
 // Hedef kullanicilari belirle
 let sorgu = db.collection("kullanicilar");
 if (hedef === "firma" && hedefFirmaId) {
 sorgu = sorgu.where("firmaId", "==", hedefFirmaId);
 } else if (hedef === "adminler") {
 sorgu = sorgu.where("rol", "==", "admin");
 } else if (hedef === "soforler") {
 sorgu = sorgu.where("rol", "==", "sofor");
 } else if (hedef === "veliler") {
 sorgu = sorgu.where("rol", "==", "veli");
 }
 const kullanicilar = await sorgu.get();
 let gonderilen = 0;
 const batchBoyutu = 500;
 let batch = db.batch();
 let batchSayac = 0;
 for (const doc of kullanicilar.docs) {
 const d = doc.data();
 const token = d.fcmToken;
 const aliciId = doc.id;
 if (token) {
 await fcmGonder(token, baslik, mesaj, { tip: "toplu" });
 gonderilen++;
 }
 const notifRef = db.collection("notifications").doc();
 batch.set(notifRef, {
 aliciId,
 firmaId: d.firmaId ?? "",
 baslik,
 mesaj,
 tip: "sistem",
 okundu: false,
 tarih: FieldValue.serverTimestamp(),
 });
 batchSayac++;
 if (batchSayac >= batchBoyutu) {
 await batch.commit();
 batch = db.batch();
 batchSayac = 0;
 }
 }
 if (batchSayac > 0) await batch.commit();
 console.log(`Toplu bildirim: ${gonderilen} FCM, ${kullanicilar.size} Firestore`);
 return { basarili: true, toplamKullanici: kullanicilar.size, fcmGonderilen: gonderilen };
});
// ═══════════════════════════════════════════════════════════════════════════
// 9. HAFTALIK İSTATİSTİK RAPORU
// Her Pazartesi 09:00'da super admin'e haftalik ozet
// ═══════════════════════════════════════════════════════════════════════════
exports.haftalikRapor = onSchedule(
 { schedule: "0 6 * * 1", timeZone: "Europe/Istanbul" },
 async () => {
 const [firmaSnap, soforSnap, ogrenciSnap, veliSnap] = await Promise.all([
 db.collection("firms").count().get(),
 db.collection("drivers").count().get(),
 db.collection("students").count().get(),
 db.collection("parents").count().get(),
 ]);
 const superAdminSnap = await db.collection("kullanicilar")
 .where("rol", "==", "superAdmin").get();
 const baslik = "Haftalik Sistem Raporu";
 const mesaj = [
 `Firma: ${firmaSnap.count}`,
 `Sofor: ${soforSnap.count}`,
 `Ogrenci: ${ogrenciSnap.count}`,
 `Veli: ${veliSnap.count}`,
 ].join(" | ");
 for (const adminDoc of superAdminSnap.docs) {
 const token = await fcmTokenAl(adminDoc.id);
 await fcmGonder(token, baslik, mesaj);
 await firestoreBildirimYaz(adminDoc.id, "", baslik, mesaj, "rapor");
 }
 console.log("Haftalik rapor gonderildi.");
 }
);