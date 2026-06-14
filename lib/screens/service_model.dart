// Servisim360 — Service Model (Bölüm 27)
class ServiceModel{
  final String id;
  final String firmaId;
  final String projeId;
  final String ad;
  final String plaka;
  final String aracMarka;
  final int kapasite;
  final String soforId;
  final String soforAd;
  final int ogrenciSayisi;
  final int renkIndex;
  final bool aktif;
  final bool servisAktif;

  const ServiceModel({
    required this.id,required this.firmaId,required this.projeId,
    required this.ad,this.plaka='',this.aracMarka='',
    this.kapasite=17,this.soforId='',this.soforAd='',
    this.ogrenciSayisi=0,this.renkIndex=0,
    this.aktif=true,this.servisAktif=false,
  });

  factory ServiceModel.fromMap(String id,Map<String,dynamic> d)=>ServiceModel(
    id:id,firmaId:d['firmaId']??'',projeId:d['projeId']??'',
    ad:d['ad']??'',plaka:d['plaka']??d['aracPlaka']??'',
    aracMarka:d['aracMarka']??'',kapasite:(d['kapasite'] as int?)??17,
    soforId:d['soforId']??'',soforAd:d['soforAd']??'',
    ogrenciSayisi:(d['ogrenciSayisi'] as int?)??0,
    renkIndex:(d['renkIndex'] as int?)??0,
    aktif:d['aktif']??true,servisAktif:d['servisAktif']??false,
  );

  Map<String,dynamic> toMap()=>({
    'firmaId':firmaId,'projeId':projeId,'ad':ad,
    'plaka':plaka,'aracMarka':aracMarka,'kapasite':kapasite,
    'soforId':soforId,'soforAd':soforAd,'ogrenciSayisi':ogrenciSayisi,
    'renkIndex':renkIndex,'aktif':aktif,'servisAktif':servisAktif,
  });

  double get dolulukOrani=>kapasite>0?ogrenciSayisi/kapasite:0;
  int get bosKoltuk=>kapasite-ogrenciSayisi;
}
