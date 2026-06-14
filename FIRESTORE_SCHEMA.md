# Servisim360 — Gerçek Firestore Şeması (Bölüm 26)

> **ÖNEMLİ:** Bu belge mevcut çalışan sisteme göre hazırlanmıştır.
> Bölüm 26 referans belgesindeki bazı alan adları farklıdır — mevcut veriler korunmuştur.

## Alan Adı Eşleşme Tablosu

|Bölüm 26 Referans|Gerçek Kod Alanı|Koleksiyon       |
|-----------------|----------------|-----------------|
|`firmId`         |`firmaId`       |Tüm koleksiyonlar|
|`projectId`      |`projeId`       |Tüm koleksiyonlar|
|`serviceId`      |`servisId`      |students         |
|`driverId`       |`soforId`       |services         |
|`koltukSayisi`   |`kapasite`      |services         |
|`adSoyad`        |`ad`            |students, drivers|
|`projeAdi`       |`projeAd`       |projects         |

## Koleksiyonlar ve Gerçek Alan Adları

### firms

```
firmaId (doc id)
firmaAdi | ad
yetkiliAdi
telefon
email
adres
logo
lisansTipi: beklemede | onaylı | reddedildi | askıya alındı
lisansBaslangic
lisansBitis
durum
kayitTarihi
```

### projects

```
firmaId
projeAd
projeTipi: Okul | Kolej | Personel | VIP | Tur
okulAdi
baslangicTarihi
bitisTarihi
durum: Taslak | Aktif | Pasif | Arsiv
sabahSaati
aksamSaati
aktif: bool
```

### services

```
firmaId
projeId
ad
plaka | aracPlaka
aracMarka
kapasite (≈ koltukSayisi)
soforId
soforAd
ogrenciSayisi
aktif: bool
servisAktif: bool (GPS takip aktif)
renkIndex: int
```

### drivers

```
firmaId
ad (≈ adSoyad)
telefon
email
ehliyetNo
ehliyetBitisTarihi
srcBelge
srcBitisTarihi
psikoteknikBelge
psikoteknikBitisTarihi
lat, lng, hiz
sonKonumZamani
servisAktif: bool
aktif: bool
```

### students

```
firmaId
projeId
servisId (≈ serviceId)
ad (≈ adSoyad)
okul
sinif
adres
lat, lng
fiyat | ucret (≈ ucret)
sozlesmeDurum
aktif: bool
arsiv: bool
sira: int (rota sırası)
```

### parents

```
firmaId
ad
telefon
email
ogrenciId
aktif: bool
```

### tahsilat (≈ payments)

```
firmaId
projeId
ogrenciId
ogrenciAd
tutar
ay
durum: odendi | gecikti | bekliyor | arsiv
tarih
aciklama
```

### sozlesmeler (≈ contracts)

```
firmaId
ogrenciId
veliId
projeId
ucret
pdfUrl
durum: taslak | bekliyor | imzalandi | suresi_doldu | arsiv
onayTarihi
tarih
```

### bildirimler (≈ notifications)

```
firmaId
tip: servis_basladi | yaklasisyor | acil | toplu_mesaj | duyuru
baslik
mesaj
hedef: hepsi | veliler | soforler
okundu: bool
tarih
gonderen
```

### servis_raporlari (≈ reports)

```
firmaId
projeId
soforId
tarih
toplamOgrenci
bindiler
gelmediler
tamamlandi: bool
```

### plate_logs (plaka giriş)

```
firmaId
plaka
soforAd
projeAd
eslesti: bool
tarih
tip: plaka | qr
```

### absence_requests (devamsızlık)

```
firmaId
projeId
ogrenciId
ogrenciAd
soforId
servisId
tip: hepsi | sabah | aksam
tarih
aciklama
```

### firma_ayarlari

```
doc id = firmaId
yaklasmaMesafe: 500 | 700 | 1000
sessizSaatAktif: bool
sessizBaslangic: int (saat)
sessizBitis: int (saat)
kardesIndirimAktif: bool
kardesIndirim2: double (%)
kardesIndirim3: double (%)
kardesIndirim4: double (%)
```

### islem_loglari (≈ logs)

```
firmaId
kullaniciId | yapanId
kullaniciAd
islem | aksiyon
modul
detay | aciklama
tarih
```

## Firestore Security Rules (Özet)

```javascript
// Tüm koleksiyonlarda firmaId kontrolü
match /students/{docId} {
  allow read, write: if request.auth != null 
    && resource.data.firmaId == getUserFirmaId(request.auth.uid);
}
```

## Storage Yapısı

```
firms/{firmaId}/
  contracts/     → PDF sözleşmeler
  students/      → Öğrenci fotoğrafları
  drivers/       → Şoför belgeleri
  vehicles/      → Araç fotoğrafları
  posters/       → Afiş dosyaları
  reports/       → Rapor dosyaları
  backups/       → Yedek dosyaları
```