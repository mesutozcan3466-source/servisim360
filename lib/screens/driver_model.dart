// Servisim360 — Driver Model (Bölüm 27)
class DriverModel{
  final String id;
  final String firmaId;
  final String ad;
  final String telefon;
  final String ehliyetNo;
  final String ehliyetBitisTarihi;
  final String srcBelge;
  final String srcBitisTarihi;
  final bool aktif;
  final bool servisAktif;
  final double lat;
  final double lng;
  final double hiz;

  const DriverModel({
    required this.id,required this.firmaId,required this.ad,
    this.telefon='',this.ehliyetNo='',this.ehliyetBitisTarihi='',
    this.srcBelge='',this.srcBitisTarihi='',
    this.aktif=true,this.servisAktif=false,
    this.lat=0,this.lng=0,this.hiz=0,
  });

  factory DriverModel.fromMap(String id,Map<String,dynamic> d)=>DriverModel(
    id:id,firmaId:d['firmaId']??'',ad:d['ad']??'',
    telefon:d['telefon']??'',ehliyetNo:d['ehliyetNo']??'',
    ehliyetBitisTarihi:d['ehliyetBitisTarihi']??'',
    srcBelge:d['srcBelge']??'',srcBitisTarihi:d['srcBitisTarihi']??'',
    aktif:d['aktif']??true,servisAktif:d['servisAktif']??false,
    lat:(d['lat'] as num?)?.toDouble()??0,lng:(d['lng'] as num?)?.toDouble()??0,
    hiz:(d['hiz'] as num?)?.toDouble()??0,
  );

  Map<String,dynamic> toMap()=>({
    'firmaId':firmaId,'ad':ad,'telefon':telefon,
    'ehliyetNo':ehliyetNo,'ehliyetBitisTarihi':ehliyetBitisTarihi,
    'srcBelge':srcBelge,'srcBitisTarihi':srcBitisTarihi,
    'aktif':aktif,'servisAktif':servisAktif,
    'lat':lat,'lng':lng,'hiz':hiz,
  });
}
