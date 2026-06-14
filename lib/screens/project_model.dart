// Servisim360 — Project Model (Bölüm 27)
class ProjectModel{
  final String id;
  final String firmaId;
  final String projeAd;
  final String projeTipi;
  final String okulAdi;
  final String baslangicTarihi;
  final String bitisTarihi;
  final String durum;
  final String sabahSaati;
  final String aksamSaati;
  final bool aktif;

  const ProjectModel({
    required this.id,required this.firmaId,required this.projeAd,
    this.projeTipi='Okul',this.okulAdi='',
    this.baslangicTarihi='',this.bitisTarihi='',
    this.durum='Aktif',this.sabahSaati='07:30',this.aksamSaati='16:30',
    this.aktif=true,
  });

  factory ProjectModel.fromMap(String id,Map<String,dynamic> d)=>ProjectModel(
    id:id,firmaId:d['firmaId']??'',
    projeAd:d['projeAd']??d['ad']??'',
    projeTipi:d['projeTipi']??d['tip']??'Okul',
    okulAdi:d['okulAdi']??'',
    baslangicTarihi:d['baslangicTarihi']??'',
    bitisTarihi:d['bitisTarihi']??'',
    durum:d['durum']??'Aktif',
    sabahSaati:d['sabahSaati']??'07:30',
    aksamSaati:d['aksamSaati']??'16:30',
    aktif:d['aktif']??true,
  );

  Map<String,dynamic> toMap()=>({
    'firmaId':firmaId,'projeAd':projeAd,'projeTipi':projeTipi,
    'okulAdi':okulAdi,'baslangicTarihi':baslangicTarihi,
    'bitisTarihi':bitisTarihi,'durum':durum,
    'sabahSaati':sabahSaati,'aksamSaati':aksamSaati,'aktif':aktif,
  });
}
