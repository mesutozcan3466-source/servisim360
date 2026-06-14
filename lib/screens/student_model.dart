// Servisim360 — Student Model (Bölüm 27)
class StudentModel{
  final String id;
  final String firmaId;
  final String projeId;
  final String servisId;
  final String ad;
  final String adres;
  final double lat;
  final double lng;
  final double fiyat;
  final String sozlesmeDurum;
  final bool aktif;
  final int sira;

  const StudentModel({
    required this.id,required this.firmaId,required this.projeId,
    this.servisId='',required this.ad,this.adres='',
    this.lat=0,this.lng=0,this.fiyat=0,
    this.sozlesmeDurum='bekliyor',this.aktif=true,this.sira=0,
  });

  factory StudentModel.fromMap(String id,Map<String,dynamic> d)=>StudentModel(
    id:id,firmaId:d['firmaId']??'',projeId:d['projeId']??'',
    servisId:d['servisId']??'',ad:d['ad']??'',adres:d['adres']??'',
    lat:(d['lat'] as num?)?.toDouble()??0,lng:(d['lng'] as num?)?.toDouble()??0,
    fiyat:(d['fiyat']??d['ucret'] as num?)?.toDouble()??0,
    sozlesmeDurum:d['sozlesmeDurum']??'bekliyor',
    aktif:d['aktif']??true,sira:(d['sira'] as int?)??0,
  );

  Map<String,dynamic> toMap()=>({
    'firmaId':firmaId,'projeId':projeId,'servisId':servisId,
    'ad':ad,'adres':adres,'lat':lat,'lng':lng,
    'fiyat':fiyat,'ucret':fiyat,'sozlesmeDurum':sozlesmeDurum,
    'aktif':aktif,'sira':sira,
  });
}
