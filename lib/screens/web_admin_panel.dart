// lib/screens/web_admin_panel.dart - Servisim360 Web Admin v5 - 21 Menu
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'web_soforler.dart';
import 'web_raporlar.dart';
import 'web_harita.dart';
import 'web_ogrenciler.dart';
import 'web_ayarlar.dart';
import 'web_test_merkezi.dart';
// web_arac_merkezi.dart - henuz kopyalanmadi, once kopyalayin
import 'web_arsiv_merkezi.dart';
// web_yedekleme.dart - henuz kopyalanmadi, once kopyalayin

class WebAdminPanel extends StatefulWidget {
  const WebAdminPanel({super.key});
  @override State<WebAdminPanel> createState() => _WebAdminPanelState();
}

class _WebAdminPanelState extends State<WebAdminPanel> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  int    _aktifSekme    = 0;
  String _firmaAdi='', _kullaniciAd='', _firmaId='', _projeId='', _projeAd='';
  bool   _yukleniyor=true, _projeMenuAcik=false;
  int _toplamSurucu=0,_toplamOgrenci=0,_toplamVeli=0,_toplamServis=0;
  int _aktifServis=0,_bekleyenDevamsizlik=0,_bekleyenBasvuru=0;
  int _atanmamisOgrenci=0,_konumsuzOgrenci=0;
  List<Map<String,dynamic>> _projeler=[];

  static const List<_MenuItem> _menuler=[
    _MenuItem('Ana Ekran',      Icons.home_outlined,             0),
    _MenuItem('Projeler',       Icons.folder_outlined,           1),
    _MenuItem('Servisler',      Icons.directions_bus_outlined,   2),
    _MenuItem('Araclar',        Icons.directions_car_outlined,   3),
    _MenuItem('Soforler',       Icons.person_outlined,           4),
    _MenuItem('Ogrenciler',     Icons.school_outlined,           5),
    _MenuItem('Veliler',        Icons.family_restroom_outlined,  6),
    _MenuItem('Kayit Sistemi',  Icons.app_registration_outlined, 7),
    _MenuItem('Sozlesmeler',    Icons.description_outlined,      8),
    _MenuItem('Fiyatlandirma',  Icons.payments_outlined,         9),
    _MenuItem('Harita & Rota',  Icons.map_outlined,              10),
    _MenuItem('Devamsizlik',    Icons.event_busy_outlined,       11),
    _MenuItem('Plaka Tanima',   Icons.camera_alt_outlined,       12),
    _MenuItem('Karekod / QR',   Icons.qr_code_outlined,          13),
    _MenuItem('Bildirimler',    Icons.notifications_outlined,    14),
    _MenuItem('Raporlar',       Icons.bar_chart_outlined,        15),
    _MenuItem('Arsiv',          Icons.archive_outlined,          16),
    _MenuItem('Ayarlar',        Icons.settings_outlined,         17),
    _MenuItem('Test Merkezi',   Icons.checklist_outlined,        18),
    _MenuItem('Arac Yonetimi',  Icons.build_circle_outlined,     19),
    _MenuItem('Arsiv Merkezi',  Icons.folder_special_outlined,   20),
    _MenuItem('Yedekleme',      Icons.backup_outlined,            21),
  ];

  @override void initState(){super.initState();_yukle();}

  Future<void> _yukle() async {
    setState(()=>_yukleniyor=true);
    final user=FirebaseAuth.instance.currentUser;
    if(user==null)return;
    try{
      final fId=await SessionService.instance.firmaIdAl();
      _firmaId=fId??'';
      final kulDoc=await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
      _kullaniciAd=kulDoc.data()?['ad']??user.email??'';
      if(_firmaId.isNotEmpty){
        final firmaDoc=await FirebaseFirestore.instance.collection('firms').doc(_firmaId).get();
        _firmaAdi=firmaDoc.data()?['firmaAdi']??firmaDoc.data()?['ad']??'';
        final projSnap=await FirebaseFirestore.instance.collection('projects')
            .where('firmaId',isEqualTo:_firmaId).where('aktif',isEqualTo:true)
            .orderBy('olusturmaTarihi',descending:true).get();
        _projeler=projSnap.docs.map((d)=>{'id':d.id,...d.data()}).toList();
        _projeId=SessionService.instance.aktifProjeld??'';
        _projeAd=SessionService.instance.aktifProjeAdi??'';
        await _istatistikYukle();
      }
    }catch(e){debugPrint('panel hata:$e');}
    if(mounted)setState(()=>_yukleniyor=false);
  }

  Future<void> _istatistikYukle() async {
    try{
      var sofQ=FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:_firmaId);
      var ogrQ=FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:_firmaId);
      var veliQ=FirebaseFirestore.instance.collection('parents').where('firmaId',isEqualTo:_firmaId);
      var serQ=FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:_firmaId);
      var devQ=FirebaseFirestore.instance.collection('absence_requests')
          .where('firmaId',isEqualTo:_firmaId).where('durum',isEqualTo:'bekliyor');
      var basQ=FirebaseFirestore.instance.collection('kayit_basvurulari')
          .where('firmaId',isEqualTo:_firmaId).where('durum',isEqualTo:'bekliyor');
      if(_projeId.isNotEmpty){
        ogrQ=ogrQ.where('projeId',isEqualTo:_projeId);
        sofQ=sofQ.where('projeId',isEqualTo:_projeId);
        serQ=serQ.where('projeId',isEqualTo:_projeId);
      }
      final r=await Future.wait([sofQ.get(),ogrQ.get(),veliQ.get(),devQ.get(),basQ.get(),serQ.get()]);
      final aktif=r[0].docs.where((d)=>(d.data())['servisAktif']==true).length;
      int atanmamis=0,konumsuz=0;
      try{
        var atQ=FirebaseFirestore.instance.collection('students')
            .where('firmaId',isEqualTo:_firmaId).where('surucuId',isEqualTo:'');
        var konQ=FirebaseFirestore.instance.collection('students')
            .where('firmaId',isEqualTo:_firmaId).where('konumVar',isEqualTo:false);
        if(_projeId.isNotEmpty){atQ=atQ.where('projeId',isEqualTo:_projeId);konQ=konQ.where('projeId',isEqualTo:_projeId);}
        final atSnap=await atQ.count().get();final konSnap=await konQ.count().get();
        atanmamis=atSnap.count??0;konumsuz=konSnap.count??0;
      }catch(_){}
      if(mounted)setState((){
        _toplamSurucu=r[0].docs.length;_toplamOgrenci=r[1].docs.length;
        _toplamVeli=r[2].docs.length;_bekleyenDevamsizlik=r[3].docs.length;
        _bekleyenBasvuru=r[4].docs.length;_toplamServis=r[5].docs.length;
        _aktifServis=aktif;_atanmamisOgrenci=atanmamis;_konumsuzOgrenci=konumsuz;
      });
    }catch(_){}
  }

  void _projeAyarla(String pid,String pad){
    SessionService.instance.aktifProjeAyarla(pid,pad);
    setState((){_projeId=pid;_projeAd=pad;_projeMenuAcik=false;});
    _istatistikYukle();
  }
  void _projeTumFirma(){
    SessionService.instance.projeTemizle();
    setState((){_projeId='';_projeAd='';_projeMenuAcik=false;});
    _istatistikYukle();
  }

  void _projeEkleDialog(){
    final adCtrl=TextEditingController();
    final donemCtrl=TextEditingController(text:'2025-2026');
    final okulAdresCtrl=TextEditingController();
    final baslangicCtrl=TextEditingController(text:'01.09.2025');
    final bitisCtrl=TextEditingController(text:'30.06.2026');
    String secFiyatTuru='mahalle';
    String tip='okul';
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
      title:const Row(children:[Icon(Icons.folder_outlined,color:Color(0xFF1a3a6b)),SizedBox(width:10),
        Text('Yeni Proje',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold,fontSize:16))]),
      content:SizedBox(width:380,child:Column(mainAxisSize:MainAxisSize.min,children:[
        _tf(adCtrl,'Proje Adi *',Icons.folder_outlined),const SizedBox(height:10),
        _tf(donemCtrl,'Donem (2025-2026)',Icons.calendar_today_outlined),const SizedBox(height:10),
        _tf(okulAdresCtrl,'Okul / Isyeri Adresi',Icons.location_on_outlined),const SizedBox(height:10),
        _tf(baslangicCtrl,'Baslangic Tarihi',Icons.date_range_outlined),const SizedBox(height:10),
        _tf(bitisCtrl,'Bitis Tarihi',Icons.date_range_outlined),const SizedBox(height:10),
        DropdownButtonFormField<String>(
          value: secFiyatTuru,
          decoration: InputDecoration(labelText: 'Varsayilan Fiyat Turu',
              prefixIcon: const Icon(Icons.attach_money_outlined, color: Color(0xFF1a3a6b), size:18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true),
          items: const [
            DropdownMenuItem(value: 'mahalle', child: Text('Mahalle Bazli')),
            DropdownMenuItem(value: 'bolge',   child: Text('Bolge Bazli')),
            DropdownMenuItem(value: 'km',      child: Text('KM Bazli')),
            DropdownMenuItem(value: 'manuel',  child: Text('Manuel')),
          ],
          onChanged: (v) => setS(() => secFiyatTuru = v ?? 'mahalle'),
        ),
        const SizedBox(height:12),
        Row(children:[
          _TipBtn('okul','Okul',Icons.school_outlined,tip,(t)=>setS(()=>tip=t)),const SizedBox(width:8),
          _TipBtn('kolej','Kolej',Icons.account_balance_outlined,tip,(t)=>setS(()=>tip=t)),const SizedBox(width:8),
          _TipBtn('personel','Personel',Icons.badge_outlined,tip,(t)=>setS(()=>tip=t)),
        ]),
      ])),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
        ElevatedButton.icon(
          style:ElevatedButton.styleFrom(backgroundColor:_turuncu,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
          onPressed:() async {
            if(adCtrl.text.trim().isEmpty)return;
            final ref=await FirebaseFirestore.instance.collection('projects').add({
              'firmaId':_firmaId,'projeAd':adCtrl.text.trim(),
              'donem':donemCtrl.text.trim(),'tip':tip,
              'okulAdresi':okulAdresCtrl.text.trim(),
              'baslangicTarihi':baslangicCtrl.text.trim(),
              'bitisTarihi':bitisCtrl.text.trim(),
              'fiyatTuru':secFiyatTuru,
              'aktif':true,'olusturmaTarihi':FieldValue.serverTimestamp(),
            });
            if(ctx.mounted){
              Navigator.pop(ctx);
              _projeler.add({'id':ref.id,'projeAd':adCtrl.text.trim(),'tip':tip});
              _projeAyarla(ref.id,adCtrl.text.trim());
            }
          },
          icon:const Icon(Icons.add,size:16),
          label:const Text('Olustur',style:TextStyle(fontWeight:FontWeight.bold)),
        ),
      ],
    )));
  }

  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:const Color(0xFF1a3a6b),size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12)));

  @override
  Widget build(BuildContext context){
    if(_yukleniyor)return const Scaffold(backgroundColor:Color(0xFF1a3a6b),
        body:Center(child:CircularProgressIndicator(color:Color(0xFFFF8C00))));
    return Scaffold(
      backgroundColor:const Color(0xFFF0F2F5),
      body:Row(children:[
        Container(width:220,color:_navy,child:Column(children:[
          Container(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Container(width:36,height:36,decoration:BoxDecoration(color:_turuncu,borderRadius:BorderRadius.circular(8)),
                  child:const Center(child:Text('S',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:18)))),
              const SizedBox(width:10),
              const Expanded(child:Text('Servisim360',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:14))),
            ]),
            const SizedBox(height:5),
            Text(_firmaAdi,style:TextStyle(color:Colors.white.withValues(alpha:0.55),fontSize:11),overflow:TextOverflow.ellipsis),
          ])),
          Container(
            margin:const EdgeInsets.symmetric(horizontal:10),
            decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10),
                border:Border.all(color:_projeId.isNotEmpty?_turuncu.withValues(alpha:0.6):Colors.white24)),
            child:Column(children:[
              GestureDetector(onTap:()=>setState(()=>_projeMenuAcik=!_projeMenuAcik),
                  child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                      child:Row(children:[
                        Icon(Icons.folder_outlined,color:_projeId.isNotEmpty?_turuncu:Colors.white54,size:16),
                        const SizedBox(width:8),
                        Expanded(child:Text(_projeAd.isNotEmpty?_projeAd:'Tum Firma',
                            style:TextStyle(color:_projeAd.isNotEmpty?_turuncu:Colors.white70,fontSize:12,fontWeight:FontWeight.w600),
                            overflow:TextOverflow.ellipsis)),
                        Icon(_projeMenuAcik?Icons.expand_less:Icons.expand_more,color:Colors.white54,size:16),
                      ]))),
              if(_projeMenuAcik)...[
                const Divider(color:Colors.white12,height:1),
                GestureDetector(onTap:_projeTumFirma,
                    child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                        decoration:BoxDecoration(color:_projeId.isEmpty?Colors.white.withValues(alpha:0.1):Colors.transparent),
                        child:Row(children:[
                          Icon(Icons.business_outlined,color:_projeId.isEmpty?Colors.white:Colors.white54,size:14),
                          const SizedBox(width:8),
                          Expanded(child:Text('Tum Firma',style:TextStyle(color:_projeId.isEmpty?Colors.white:Colors.white60,
                              fontSize:11,fontWeight:_projeId.isEmpty?FontWeight.bold:FontWeight.normal))),
                          if(_projeId.isEmpty)const Icon(Icons.check,color:Color(0xFFFF8C00),size:12),
                        ]))),
                ..._projeler.map((prj){
                  final secili=_projeId==prj['id'];
                  return GestureDetector(onTap:()=>_projeAyarla(prj['id'],prj['projeAd']??''),
                      child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                          decoration:BoxDecoration(color:secili?_turuncu.withValues(alpha:0.15):Colors.transparent),
                          child:Row(children:[
                            Icon(Icons.folder_outlined,color:secili?_turuncu:Colors.white54,size:14),
                            const SizedBox(width:8),
                            Expanded(child:Text(prj['projeAd']??'',style:TextStyle(color:secili?_turuncu:Colors.white60,
                                fontSize:11,fontWeight:secili?FontWeight.bold:FontWeight.normal),overflow:TextOverflow.ellipsis)),
                            if(secili)const Icon(Icons.check,color:Color(0xFFFF8C00),size:12),
                          ])));
                }),
                const Divider(color:Colors.white12,height:1),
                GestureDetector(onTap:(){setState(()=>_projeMenuAcik=false);_projeEkleDialog();},
                    child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
                        child:Row(children:[
                          Container(padding:const EdgeInsets.all(3),
                              decoration:BoxDecoration(color:_turuncu.withValues(alpha:0.2),borderRadius:BorderRadius.circular(4)),
                              child:const Icon(Icons.add,color:Color(0xFFFF8C00),size:12)),
                          const SizedBox(width:8),
                          const Text('Yeni Proje Olustur',style:TextStyle(color:Color(0xFFFF8C00),fontSize:11,fontWeight:FontWeight.bold)),
                        ]))),
              ],
            ]),
          ),
          const SizedBox(height:8),
          const Divider(color:Colors.white12),
          Expanded(child:ListView(padding:EdgeInsets.zero,children:_menuler.map((item){
            final secili=_aktifSekme==item.index;
            int badge=0;
            if(item.index==7)badge=_bekleyenBasvuru;
            if(item.index==11)badge=_bekleyenDevamsizlik;
            return GestureDetector(onTap:()=>setState(()=>_aktifSekme=item.index),
                child:Container(
                    margin:const EdgeInsets.symmetric(horizontal:10,vertical:2),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                    decoration:BoxDecoration(
                      color:secili?Colors.white.withValues(alpha:0.1):Colors.transparent,
                      borderRadius:BorderRadius.circular(10),
                      border:secili?Border.all(color:_turuncu.withValues(alpha:0.5)):null,
                    ),
                    child:Row(children:[
                      Icon(item.ikon,color:secili?_turuncu:Colors.white54,size:17),
                      const SizedBox(width:10),
                      Expanded(child:Text(item.ad,style:TextStyle(color:secili?Colors.white:Colors.white60,
                          fontWeight:secili?FontWeight.bold:FontWeight.normal,fontSize:12))),
                      if(badge>0)Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                          decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(10)),
                          child:Text('$badge',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold))),
                    ])));
          }).toList())),
          Container(padding:const EdgeInsets.all(14),
              child:Row(children:[
                CircleAvatar(radius:14,backgroundColor:_turuncu,
                    child:Text(_kullaniciAd.isNotEmpty?_kullaniciAd[0].toUpperCase():'A',
                        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:12))),
                const SizedBox(width:8),
                Expanded(child:Text(_kullaniciAd,style:const TextStyle(color:Colors.white70,fontSize:11),overflow:TextOverflow.ellipsis)),
                IconButton(icon:const Icon(Icons.logout_outlined,color:Colors.white38,size:16),
                    onPressed:() async {
                      await SessionService.instance.cikisYap();
                      if(mounted)Navigator.pushReplacementNamed(context,'/');
                    }),
              ])),
        ])),
        Expanded(child:Column(children:[
          Container(padding:const EdgeInsets.symmetric(horizontal:28,vertical:14),color:Colors.white,
              child:Row(children:[
                Text(_menuler[_aktifSekme].ad,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
                if(_projeAd.isNotEmpty)...[
                  const SizedBox(width:10),
                  Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                      decoration:BoxDecoration(color:_turuncu.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:_turuncu.withValues(alpha:0.3))),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        const Icon(Icons.folder_outlined,color:Color(0xFFFF8C00),size:12),const SizedBox(width:4),
                        Text(_projeAd,style:const TextStyle(color:Color(0xFFFF8C00),fontSize:11,fontWeight:FontWeight.bold)),
                        const SizedBox(width:6),
                        GestureDetector(onTap:_projeTumFirma,child:const Icon(Icons.close,color:Color(0xFFFF8C00),size:12)),
                      ])),
                ],
                const Spacer(),
                if(_aktifServis>0)Container(
                    padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
                    decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(20),
                        border:Border.all(color:Colors.green.withValues(alpha:0.3))),
                    child:Row(children:[
                      Container(width:8,height:8,decoration:const BoxDecoration(color:Colors.green,shape:BoxShape.circle)),
                      const SizedBox(width:6),
                      Text('$_aktifServis Aktif Servis',style:const TextStyle(color:Colors.green,fontWeight:FontWeight.bold,fontSize:12)),
                    ])),
              ])),
          Expanded(child:_sekmeIcerigi()),
        ])),
      ]),
    );
  }

  Widget _sekmeIcerigi(){
    switch(_aktifSekme){
      case 0:return _WebAnaSayfa(firmaId:_firmaId,projeId:_projeId,projeAd:_projeAd,
          toplamSurucu:_toplamSurucu,toplamOgrenci:_toplamOgrenci,toplamVeli:_toplamVeli,
          toplamServis:_toplamServis,aktifServis:_aktifServis,bekleyenDevamsizlik:_bekleyenDevamsizlik,
          bekleyenBasvuru:_bekleyenBasvuru,atanmamisOgrenci:_atanmamisOgrenci,konumsuzOgrenci:_konumsuzOgrenci,
          onNavigate:(i)=>setState(()=>_aktifSekme=i));
      case 1:return _ProjelerSekme(firmaId:_firmaId,projeler:_projeler,onProjeAyarla:_projeAyarla,onProjeEkle:_projeEkleDialog);
      case 2:return _ServislerSekme(firmaId:_firmaId,projeId:_projeId);
      case 3:return _AraclarSekme(firmaId:_firmaId);
      case 4:return WebSoforler(firmaId:_firmaId);
      case 5:return const WebOgrenciler();
      case 6:return _VelilerSekme(firmaId:_firmaId,projeId:_projeId);
      case 7:return _KayitSistemiSekme(firmaId:_firmaId);
      case 8:return _SozlesmelerSekme(firmaId:_firmaId);
      case 9:return _FiyatlandirmaSekme(firmaId:_firmaId);
      case 10:return WebHarita(firmaId:_firmaId,projeId:_projeId);
      case 11:return _DevamsizlikSekme(firmaId:_firmaId);
      case 12:return _PlakaTanimaSekme(firmaId:_firmaId);
      case 13:return _KarekodQrSekme(firmaId:_firmaId);
      case 14:return _BildirimlerSekme(firmaId:_firmaId);
      case 15:return WebRaporlar(projeId:_projeId);
      case 16:return _ArsivSekme(firmaId:_firmaId);
      case 17:return const WebAyarlar();
      case 18:return const WebTestMerkezi();
      case 19:return _BosEkran(baslik:'Arac Yonetimi',ikon:Icons.build_circle_outlined);
      case 20:return const WebArsivMerkezi();
      case 21:return _BosEkran(baslik:'Yedekleme',ikon:Icons.backup_outlined);
      default:return const SizedBox();
    }
  }
}

class _MenuItem{
  final String ad;final IconData ikon;final int index;
  const _MenuItem(this.ad,this.ikon,this.index);
}

//  ANA EKRAN
class _WebAnaSayfa extends StatelessWidget{
  final String firmaId,projeId,projeAd;
  final int toplamSurucu,toplamOgrenci,toplamVeli,toplamServis,aktifServis;
  final int bekleyenDevamsizlik,bekleyenBasvuru,atanmamisOgrenci,konumsuzOgrenci;
  final void Function(int) onNavigate;
  static const _navy=Color(0xFF1a3a6b);
  const _WebAnaSayfa({required this.firmaId,required this.projeId,required this.projeAd,
    required this.toplamSurucu,required this.toplamOgrenci,required this.toplamVeli,
    required this.toplamServis,required this.aktifServis,required this.bekleyenDevamsizlik,
    required this.bekleyenBasvuru,required this.atanmamisOgrenci,required this.konumsuzOgrenci,
    required this.onNavigate});

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(bekleyenBasvuru>0)    _bnr('$bekleyenBasvuru bekleyen kayit basvurusu',Colors.orange,'Incele',()=>onNavigate(7)),
        if(bekleyenDevamsizlik>0)_bnr('$bekleyenDevamsizlik bekleyen devamsizlik',Colors.red,'Gor',()=>onNavigate(11)),
        if(atanmamisOgrenci>0)   _bnr('$atanmamisOgrenci ogrenci servise atanmamis',Colors.purple,'Ata',()=>onNavigate(5)),
        if(konumsuzOgrenci>0)    _bnr('$konumsuzOgrenci ogrencinin konumu eksik',Colors.deepOrange,'Duzenle',()=>onNavigate(5)),
        Wrap(spacing:12,runSpacing:12,children:[
          _SK('Toplam Servis',   '$toplamServis',        Icons.directions_bus_outlined, _navy,         t:()=>onNavigate(2)),
          _SK('Toplam Sofor',    '$toplamSurucu',        Icons.person_outlined,          Colors.blue,   a:aktifServis>0?'$aktifServis aktif':null,t:()=>onNavigate(4)),
          _SK('Toplam Ogrenci',  '$toplamOgrenci',       Icons.school_outlined,          Colors.teal,   t:()=>onNavigate(5)),
          _SK('Toplam Veli',     '$toplamVeli',          Icons.family_restroom_outlined, Colors.purple, t:()=>onNavigate(6)),
          _SK('Aktif Servis',    '$aktifServis',         Icons.my_location_outlined,     Colors.green),
          _SK('Devamsizlik',     '$bekleyenDevamsizlik', Icons.event_busy_outlined,      bekleyenDevamsizlik>0?Colors.red:Colors.grey,t:()=>onNavigate(11)),
          _SK('Bekl.Kayit',      '$bekleyenBasvuru',     Icons.how_to_reg_outlined,      bekleyenBasvuru>0?Colors.orange:Colors.grey,t:()=>onNavigate(7)),
          _SK('Atanmamis Ogr',   '$atanmamisOgrenci',   Icons.person_off_outlined,      atanmamisOgrenci>0?Colors.deepOrange:Colors.grey,t:()=>onNavigate(5)),
          _SK('Konumsuz Ogr',    '$konumsuzOgrenci',    Icons.location_off_outlined,    konumsuzOgrenci>0?Colors.red:Colors.grey,t:()=>onNavigate(5)),
        ]),
        const SizedBox(height:22),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Text('Canli Harita',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
              const Spacer(),
              GestureDetector(onTap:()=>onNavigate(10),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                      decoration:BoxDecoration(color:_navy,borderRadius:BorderRadius.circular(8)),
                      child:const Text('Tam Ekran',style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)))),
            ]),
            const SizedBox(height:10),
            Container(height:340,
                decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:10)]),
                clipBehavior:Clip.antiAlias,
                child:WebHarita(firmaId:firmaId,projeId:projeId)),
          ])),
          const SizedBox(width:18),
          Expanded(flex:2,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Hizli Erisim',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
            const SizedBox(height:10),
            Wrap(spacing:8,runSpacing:8,children:[
              _HB(Icons.directions_bus_outlined, 'Servis Ekle',   Color(0xFF1a3a6b),()=>onNavigate(2)),
              _HB(Icons.person_add_outlined,     'Sofor Ekle',    Colors.blue,       ()=>onNavigate(4)),
              _HB(Icons.school_outlined,         'Ogrenci Ekle',  Colors.teal,       ()=>onNavigate(5)),
              _HB(Icons.family_restroom_outlined,'Veli Ekle',     Colors.purple,     ()=>onNavigate(6)),
              _HB(Icons.link_outlined,           'Kayit Linki',   Colors.green,      ()=>onNavigate(7)),
              _HB(Icons.qr_code_outlined,        'QR Olustur',    Color(0xFFFF8C00), ()=>onNavigate(13)),
              _HB(Icons.add_road_outlined,       'Rota Olustur',  Colors.indigo,     ()=>onNavigate(10)),
              _HB(Icons.auto_awesome_outlined,   'Otomatik Dagit',Colors.teal,       ()=>onNavigate(10)),
              _HB(Icons.event_busy_outlined,     'Devamsizlik',   Colors.red,        ()=>onNavigate(11)),
              _HB(Icons.campaign_outlined,       'Afis Olustur',  Colors.deepPurple, ()=>onNavigate(7)),
            ]),
            const SizedBox(height:18),
            _YaklasanServisler(firmaId:firmaId,onNavigate:onNavigate),
            const SizedBox(height:18),
            Row(children:[
              const Text('Son Devamsizliklar',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
              const Spacer(),
              GestureDetector(onTap:()=>onNavigate(11),
                  child:const Text('Tumunu Gor',style:TextStyle(color:Color(0xFF1a3a6b),fontSize:12,fontWeight:FontWeight.bold))),
            ]),
            const SizedBox(height:10),
            _SonDevamsizliklar(firmaId:firmaId),
          ])),
        ]),
      ]));

  Widget _bnr(String m,Color r,String l,VoidCallback f)=>Container(
      margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
      decoration:BoxDecoration(color:r.withValues(alpha:0.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:r.withValues(alpha:0.3))),
      child:Row(children:[Container(width:8,height:8,decoration:BoxDecoration(color:r,shape:BoxShape.circle)),
        const SizedBox(width:10),Expanded(child:Text(m,style:TextStyle(color:r,fontWeight:FontWeight.bold,fontSize:13))),
        GestureDetector(onTap:f,child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
            decoration:BoxDecoration(color:r,borderRadius:BorderRadius.circular(7)),
            child:Text(l,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:12))))]));
}

class _SK extends StatelessWidget{
  final String baslik,deger;final IconData ikon;final Color renk;final String? a;final VoidCallback? t;
  const _SK(this.baslik,this.deger,this.ikon,this.renk,{this.a,this.t});
  @override Widget build(BuildContext context)=>GestureDetector(onTap:t,
      child:Container(width:155,padding:const EdgeInsets.all(14),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
              border:Border.all(color:renk.withValues(alpha:0.15)),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:6)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                child:Icon(ikon,color:renk,size:17)),
            const SizedBox(height:7),
            Text(deger,style:TextStyle(fontSize:24,fontWeight:FontWeight.bold,color:renk)),
            Text(baslik,style:TextStyle(fontSize:10,color:Colors.grey[600])),
            if(a!=null)Text(a!,style:TextStyle(fontSize:10,color:renk,fontWeight:FontWeight.w600)),
          ])));
}

class _HB extends StatelessWidget{
  final IconData i;final String e;final Color r;final VoidCallback f;
  const _HB(this.i,this.e,this.r,this.f);
  @override Widget build(BuildContext context)=>GestureDetector(onTap:f,
      child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
          decoration:BoxDecoration(color:r.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8),border:Border.all(color:r.withValues(alpha:0.2))),
          child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(i,color:r,size:13),const SizedBox(width:5),
            Text(e,style:TextStyle(color:r,fontSize:11,fontWeight:FontWeight.w600))])));
}

//  PROJELER
class _ProjelerSekme extends StatelessWidget{
  final String firmaId;final List<Map<String,dynamic>> projeler;
  final void Function(String,String) onProjeAyarla;final VoidCallback onProjeEkle;
  static const _navy=Color(0xFF1a3a6b);static const _turuncu=Color(0xFFFF8C00);
  const _ProjelerSekme({required this.firmaId,required this.projeler,required this.onProjeAyarla,required this.onProjeEkle});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[const Text('Projeler',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
          const Spacer(),ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_turuncu,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:onProjeEkle,icon:const Icon(Icons.add,size:16),label:const Text('Yeni Proje'))]),
        const SizedBox(height:20),
        if(projeler.isEmpty)Container(padding:const EdgeInsets.all(40),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),
            child:Column(children:[Icon(Icons.folder_open_outlined,size:56,color:Colors.grey[300]),
              const SizedBox(height:12),const Text('Henuz proje yok',style:TextStyle(color:Colors.grey,fontSize:16))]))
        else Wrap(spacing:16,runSpacing:16,children:projeler.map((prj){
          final tip=prj['tip']??'okul';
          final r=tip=='kolej'?Colors.purple:tip=='personel'?Colors.teal:_navy;
          return GestureDetector(onTap:()=>onProjeAyarla(prj['id'],prj['projeAd']??''),
              child:Container(width:220,padding:const EdgeInsets.all(20),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                      border:Border.all(color:r.withValues(alpha:0.2)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:8)]),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
                        child:Icon(Icons.folder_outlined,color:r,size:24)),
                    const SizedBox(height:12),
                    Text(prj['projeAd']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                    Text(prj['donem']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                    const SizedBox(height:8),
                    Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                        decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                        child:Text(tip,style:TextStyle(fontSize:11,color:r,fontWeight:FontWeight.bold))),
                    const SizedBox(height:10),
                    Row(children:[
                      Expanded(child:OutlinedButton.icon(
                          style:OutlinedButton.styleFrom(foregroundColor:r,side:BorderSide(color:r.withValues(alpha:0.4)),padding:const EdgeInsets.symmetric(vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                          onPressed:() async{
                            await FirebaseFirestore.instance.collection('projects').add({
                              'firmaId':firmaId,'projeAd':'${prj['projeAd']} (kopya)',
                              'donem':prj['donem']??'','tip':tip,'aktif':true,
                              'olusturmaTarihi':FieldValue.serverTimestamp(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Proje kopyalandi'),backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));
                          },
                          icon:const Icon(Icons.copy_outlined,size:13),label:const Text('Kopyala',style:TextStyle(fontSize:11)))),
                      const SizedBox(width:6),
                      Expanded(child:OutlinedButton.icon(
                          style:OutlinedButton.styleFrom(foregroundColor:Colors.grey,side:const BorderSide(color:Colors.grey),padding:const EdgeInsets.symmetric(vertical:8),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                          onPressed:() async{
                            final onay=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
                              title:const Text('Projeyi Arsivle'),
                              content:const Text('Bu proje arsive tasinacak. Devam?'),
                              actions:[TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
                                ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.grey),onPressed:()=>Navigator.pop(_,true),child:const Text('Arsivle',style:TextStyle(color:Colors.white)))],
                            ));
                            if(onay==true){
                              await FirebaseFirestore.instance.collection('projects').doc(prj['id']).update({'aktif':false,'arsivTarihi':FieldValue.serverTimestamp()});
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Proje arsivlendi'),backgroundColor:Colors.grey,behavior:SnackBarBehavior.floating));
                            }
                          },
                          icon:const Icon(Icons.archive_outlined,size:13),label:const Text('Arsivle',style:TextStyle(fontSize:11)))),
                    ]),
                  ])));
        }).toList()),
      ]));
}

//  SERVISLER
class _ServislerSekme extends StatefulWidget{
  final String firmaId,projeId;const _ServislerSekme({required this.firmaId,required this.projeId});
  @override State<_ServislerSekme> createState()=>_ServislerSekmeState();
}
class _ServislerSekmeState extends State<_ServislerSekme>{
  static const _navy=Color(0xFF1a3a6b);static const _t=Color(0xFFFF8C00);
  List<Map<String,dynamic>> _soforler=[],_araclar=[];
  @override void initState(){super.initState();_y();}
  Future<void> _y() async{
    final sS=await FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:widget.firmaId).get();
    final aS=await FirebaseFirestore.instance.collection('vehicles').where('firmaId',isEqualTo:widget.firmaId).get();
    if(mounted)setState((){_soforler=sS.docs.map((d)=>{'id':d.id,...d.data()}).toList();_araclar=aS.docs.map((d)=>{'id':d.id,...d.data()}).toList();});
  }
  void _ekle(){
    final adC=TextEditingController();final kapC=TextEditingController(text:'17');
    final sabC=TextEditingController(text:'07:30');final aksC=TextEditingController(text:'16:30');
    String tip='sabah';String? soforId,aracId;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Yeni Servis',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
        content:SizedBox(width:440,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          _tf(adC,'Servis Adi *',Icons.directions_bus_outlined),const SizedBox(height:10),
          Row(children:[Expanded(child:_tf(kapC,'Kapasite',Icons.people_outline)),const SizedBox(width:10),
            Expanded(child:DropdownButtonFormField<String?>(value:soforId,
                decoration:const InputDecoration(labelText:'Sofor',prefixIcon:Icon(Icons.person_outlined,size:18),
                    border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
                items:[const DropdownMenuItem(value:null,child:Text('Sec...')),
                  ..._soforler.map((s)=>DropdownMenuItem(value:s['id'] as String,child:Text(s['ad']??'')))],
                onChanged:(v)=>setS(()=>soforId=v)))]),
          const SizedBox(height:10),
          DropdownButtonFormField<String?>(value:aracId,
              decoration:const InputDecoration(labelText:'Arac',prefixIcon:Icon(Icons.directions_car_outlined,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
              items:[const DropdownMenuItem(value:null,child:Text('Sec...')),
                ..._araclar.map((a)=>DropdownMenuItem(value:a['id'] as String,child:Text(a['plaka']??'')))],
              onChanged:(v)=>setS(()=>aracId=v)),
          const SizedBox(height:10),
          Row(children:[Expanded(child:_tf(sabC,'Sabah Saati',Icons.wb_sunny_outlined)),const SizedBox(width:10),
            Expanded(child:_tf(aksC,'Aksam Saati',Icons.nights_stay_outlined))]),
          const SizedBox(height:10),
          Row(children:[for(final t in [('sabah','Sabah'),('aksam','Aksam'),('her_iki','Her Ikisi')])
            Expanded(child:GestureDetector(onTap:()=>setS(()=>tip=t.$1),
                child:Container(margin:const EdgeInsets.only(right:6),padding:const EdgeInsets.symmetric(vertical:10),
                    decoration:BoxDecoration(color:tip==t.$1?const Color(0xFF1a3a6b):Colors.grey[50],
                        borderRadius:BorderRadius.circular(8),border:Border.all(color:tip==t.$1?const Color(0xFF1a3a6b):Colors.grey)),
                    child:Center(child:Text(t.$2,style:TextStyle(fontSize:11,color:tip==t.$1?Colors.white:Colors.grey,
                        fontWeight:tip==t.$1?FontWeight.bold:FontWeight.normal))))))]),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(adC.text.trim().isEmpty)return;
                final sofor=_soforler.firstWhere((s)=>s['id']==soforId,orElse:()=>{});
                final arac=_araclar.firstWhere((a)=>a['id']==aracId,orElse:()=>{});
                await FirebaseFirestore.instance.collection('services').add({
                  'firmaId':widget.firmaId,'projeId':widget.projeId,'ad':adC.text.trim(),
                  'kapasite':int.tryParse(kapC.text)??17,'tip':tip,
                  'sabahSaati':sabC.text,'aksamSaati':aksC.text,
                  'soforId':soforId??'','soforAd':sofor['ad']??'',
                  'aracId':aracId??'','aracPlaka':arac['plaka']??'',
                  'aktif':true,'olusturmaTarihi':FieldValue.serverTimestamp(),
                });
                if(ctx.mounted)Navigator.pop(ctx);
              },icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ])));
  }
  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:const Color(0xFF1a3a6b),size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
          contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)));
  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),color:Colors.white,
        child:Row(children:[const Text('Servisler',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:16)),
          const Spacer(),ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:_ekle,icon:const Icon(Icons.add,size:16),label:const Text('Servis Ekle'))])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:(){var q=FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:widget.firmaId);
        if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);return q.snapshots();}(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Servis bulunamadi','Servis ekleyin.',Icons.directions_bus_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;final aktif=d['aktif']==true;
                return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(10)),
                          child:const Icon(Icons.directions_bus_outlined,color:Color(0xFF1a3a6b),size:22)),
                      const SizedBox(width:14),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        const SizedBox(height:4),
                        Wrap(spacing:6,children:[
                          if((d['soforAd']??'').isNotEmpty)_ch(d['soforAd'],Colors.blue),
                          if((d['aracPlaka']??'').isNotEmpty)_ch(d['aracPlaka'],Colors.grey),
                          if((d['sabahSaati']??'').isNotEmpty)_ch('S:${d['sabahSaati']}',Colors.orange),
                          if((d['aksamSaati']??'').isNotEmpty)_ch('A:${d['aksamSaati']}',Colors.indigo),
                          _ch('${d['kapasite']??17} koltuk',Colors.teal),
                        ]),
                      ])),
                      Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                          decoration:BoxDecoration(color:(aktif?Colors.green:Colors.grey).withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:Text(aktif?'Aktif':'Pasif',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:aktif?Colors.green:Colors.grey))),
                    ]));
              });
        })),
  ]);
  Widget _ch(String t,Color c)=>Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
      decoration:BoxDecoration(color:c.withValues(alpha:0.1),borderRadius:BorderRadius.circular(5)),
      child:Text(t,style:TextStyle(fontSize:10,color:c,fontWeight:FontWeight.bold)));
}

//  ARACLAR
class _AraclarSekme extends StatefulWidget{
  final String firmaId;const _AraclarSekme({required this.firmaId});
  @override State<_AraclarSekme> createState()=>_AraclarSekmeState();
}
class _AraclarSekmeState extends State<_AraclarSekme>{
  static const _navy=Color(0xFF1a3a6b);static const _t=Color(0xFFFF8C00);
  void _ekle(){
    final pC=TextEditingController();final mrC=TextEditingController();
    final mdC=TextEditingController();final kC=TextEditingController(text:'17');
    final muC=TextEditingController();final siC=TextEditingController();
    showDialog(context:context,builder:(_)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Arac Ekle',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
        content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[
          _tf(pC,'Plaka *',Icons.directions_car_outlined),const SizedBox(height:10),
          Row(children:[Expanded(child:_tf(mrC,'Marka',Icons.branding_watermark_outlined)),
            const SizedBox(width:10),Expanded(child:_tf(mdC,'Model',Icons.model_training_outlined))]),
          const SizedBox(height:10),_tf(kC,'Kapasite',Icons.people_outline),const SizedBox(height:10),
          Row(children:[Expanded(child:_tf(muC,'Muayene Tarihi',Icons.calendar_today_outlined)),
            const SizedBox(width:10),Expanded(child:_tf(siC,'Sigorta Tarihi',Icons.shield_outlined))]),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Iptal')),
          ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(pC.text.trim().isEmpty)return;
                await FirebaseFirestore.instance.collection('vehicles').add({
                  'firmaId':widget.firmaId,'plaka':pC.text.trim().toUpperCase(),
                  'marka':mrC.text.trim(),'model':mdC.text.trim(),
                  'kapasite':int.tryParse(kC.text)??17,
                  'muayeneTarihi':muC.text.trim(),'sigortaTarihi':siC.text.trim(),
                  'aktif':true,'olusturmaTarihi':FieldValue.serverTimestamp(),
                });
                if(mounted)Navigator.pop(context);
              },icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ]));
  }
  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:const Color(0xFF1a3a6b),size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12)));
  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),color:Colors.white,
        child:Row(children:[const Text('Araclar',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:16)),
          const Spacer(),ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:_ekle,icon:const Icon(Icons.add,size:16),label:const Text('Arac Ekle'))])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('vehicles').where('firmaId',isEqualTo:widget.firmaId).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Arac bulunamadi','Arac ekleyin.',Icons.directions_car_outlined);
          return GridView.builder(padding:const EdgeInsets.all(16),
              gridDelegate:const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent:280,mainAxisExtent:170,crossAxisSpacing:14,mainAxisSpacing:14),
              itemCount:docs.length,itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                return Container(padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:8)]),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Row(children:[Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.directions_car_outlined,color:Color(0xFF1a3a6b),size:20)),
                        const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                            decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                            child:const Text('Aktif',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Colors.green)))]),
                      const SizedBox(height:10),
                      Text(d['plaka']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18,letterSpacing:1.2)),
                      Text('${d['marka']??''} ${d['model']??''}'.trim(),style:TextStyle(fontSize:12,color:Colors.grey[500])),
                      const Spacer(),
                      Row(children:[Text('${d['kapasite']??17} koltuk',style:TextStyle(fontSize:12,color:Colors.grey[400])),const Spacer(),
                        if((d['muayeneTarihi']??'').isNotEmpty)Text('M:${d['muayeneTarihi']}',style:const TextStyle(fontSize:10,color:Colors.orange))]),
                    ]));
              });
        })),
  ]);
}

//  VELILER
class _VelilerSekme extends StatefulWidget{
  final String firmaId,projeId;
  const _VelilerSekme({required this.firmaId,this.projeId=''});
  @override State<_VelilerSekme> createState()=>_VelilerSekmeState();
}
class _VelilerSekmeState extends State<_VelilerSekme>{
  static const _t=Color(0xFFFF8C00);
  String _q='';final _c=TextEditingController();
  @override void dispose(){_c.dispose();super.dispose();}
  void _ekle(){
    final aC=TextEditingController();final tC=TextEditingController();final eC=TextEditingController();
    showDialog(context:context,builder:(_)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Veli Ekle',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
        content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[
          _tf(aC,'Veli Adi Soyadi *',Icons.person_outlined),const SizedBox(height:10),
          _tf(tC,'Telefon *',Icons.phone_outlined),const SizedBox(height:10),
          _tf(eC,'E-posta',Icons.email_outlined),
        ])),
        actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Iptal')),
          ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(aC.text.trim().isEmpty||tC.text.trim().isEmpty)return;
                final tel=tC.text.trim();
                final sif='S${tel.replaceAll(RegExp(r'\D'),'').substring(0,4.clamp(0,tel.length))}';
                await FirebaseFirestore.instance.collection('parents').add({
                  'firmaId':widget.firmaId,'ad':aC.text.trim(),'telefon':tel,
                  'email':eC.text.trim(),'kullaniciAdi':tel,'geciciSifre':sif,
                  'sozlesmeOnay':false,'aktif':true,'ogrenciId':'','ogrenciAd':'',
                  'projeId':widget.projeId,'projeAd':'','servisId':'','servisAd':'',
                  'rol':'veli','olusturmaTarihi':FieldValue.serverTimestamp(),
                });
                if(mounted)Navigator.pop(context);
              },icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ]));
  }
  void _ogrenciBaglaDialog(String veliId,Map<String,dynamic> veli){
    String? secOgrId;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(dCtx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Ogrenciye Bagla',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
        content:SizedBox(width:360,child:FutureBuilder<QuerySnapshot>(
            future:FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:widget.firmaId).get(),
            builder:(_,snap){
              final ogrs=snap.data?.docs??[];
              return Column(mainAxisSize:MainAxisSize.min,children:[
                const Text('Veliye baglanacak ogrenciyi secin:',style:TextStyle(fontSize:13,color:Colors.grey)),
                const SizedBox(height:12),
                ...ogrs.map((o){
                  final od=o.data() as Map<String,dynamic>;final secili=secOgrId==o.id;
                  return GestureDetector(onTap:()=>setS(()=>secOgrId=o.id),
                      child:Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                          decoration:BoxDecoration(color:secili?const Color(0xFF1a3a6b).withValues(alpha:0.08):Colors.grey[50],
                              borderRadius:BorderRadius.circular(8),border:Border.all(color:secili?const Color(0xFF1a3a6b):Colors.grey.shade200)),
                          child:Row(children:[Icon(Icons.school_outlined,size:14,color:secili?const Color(0xFF1a3a6b):Colors.grey),
                            const SizedBox(width:8),
                            Expanded(child:Text(od['adSoyad']??od['ad']??'',style:TextStyle(fontWeight:secili?FontWeight.bold:FontWeight.normal,color:secili?const Color(0xFF1a3a6b):Colors.grey[700]))),
                            if(secili)const Icon(Icons.check_circle,color:Color(0xFF1a3a6b),size:14)])));
                }),
              ]);
            })),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(dCtx),child:const Text('Iptal')),
          ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF1a3a6b),foregroundColor:Colors.white),
              onPressed:() async{
                if(secOgrId==null)return;
                final oSnap=await FirebaseFirestore.instance.collection('students').doc(secOgrId).get();
                final oData=oSnap.data()??{};
                await FirebaseFirestore.instance.collection('parents').doc(veliId).update({'ogrenciId':secOgrId,'ogrenciAd':oData['adSoyad']??oData['ad']??''});
                await FirebaseFirestore.instance.collection('students').doc(secOgrId).update({'veliId':veliId,'veliAd':veli['ad']??'','veliTel':veli['telefon']??''});
                if(dCtx.mounted)Navigator.pop(dCtx);
              },child:const Text('Bagla')),
        ])));
  }
  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:const Color(0xFF1a3a6b),size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12)));
  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.all(14),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(controller:_c,decoration:InputDecoration(hintText:'Veli ara...',
              prefixIcon:const Icon(Icons.search,color:Color(0xFF1a3a6b),size:18),filled:true,fillColor:const Color(0xFFF5F7FA),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide.none)),
              onChanged:(v)=>setState(()=>_q=v.toLowerCase()))),
          const SizedBox(width:12),
          ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:_ekle,icon:const Icon(Icons.add,size:16),label:const Text('Veli Ekle')),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('parents').where('firmaId',isEqualTo:widget.firmaId).snapshots(),
        builder:(_,snap){
          var docs=snap.data?.docs??[];
          if(_q.isNotEmpty)docs=docs.where((d){final x=d.data() as Map<String,dynamic>;
          return(x['ad']??x['email']??'').toString().toLowerCase().contains(_q);}).toList();
          if(docs.isEmpty)return _bos('Veli bulunamadi','Veli ekleyin.',Icons.family_restroom_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;final sozl=d['sozlesmeOnay']==true;
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      CircleAvatar(radius:20,backgroundColor:Colors.purple.withValues(alpha:0.1),
                          child:Text((d['ad']??d['email']??'?').isNotEmpty?(d['ad']??d['email'])[0].toUpperCase():'?',
                              style:const TextStyle(color:Colors.purple,fontWeight:FontWeight.bold))),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??d['email']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                        Text(d['telefon']??d['email']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        if((d['kullaniciAdi']??'').isNotEmpty)Text('Kul:${d['kullaniciAdi']}  Sifre:${d['geciciSifre']??'---'}',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                        if((d['ogrenciAd']??'').isNotEmpty)Text('Ogrenci: ${d['ogrenciAd']}',style:TextStyle(fontSize:11,color:Colors.blue[400])),
                        if((d['kayitTuru']??'').isNotEmpty)Container(margin:const EdgeInsets.only(top:3),padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.teal.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),child:Text('Kayit: ${d['kayitTuru']}',style:const TextStyle(fontSize:10,color:Colors.teal,fontWeight:FontWeight.bold))),
                        if((d['servisAd']??'').isNotEmpty)Text('Servis: ${d['servisAd']}',style:TextStyle(fontSize:11,color:Colors.teal[400])),
                        if((d['projeAd']??'').isNotEmpty)Text('Proje: ${d['projeAd']}',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                      ])),
                      Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                            decoration:BoxDecoration(color:(sozl?Colors.green:Colors.orange).withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                            child:Text(sozl?'Onaylandi':'Bekleniyor',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:sozl?Colors.green:Colors.orange))),
                        const SizedBox(height:6),
                        Row(mainAxisSize:MainAxisSize.min,children:[
                          if((d['telefon']??'').isNotEmpty)
                            GestureDetector(onTap:() async{
                              final tel=(d['telefon'] as String).replaceAll(RegExp(r'[^0-9]'),'');
                              final kul=d['kullaniciAdi']??'';final sif=d['geciciSifre']??'';
                              final msg=Uri.encodeComponent('Servisim360 giris bilgileriniz:\nKullanici Adi: '+kul+'\nSifre: '+sif+'\nservisim.org.tr');
                              final uri=Uri.parse('https://wa.me/90'+tel+'?text='+msg);
                              if(await canLaunchUrl(uri))await launchUrl(uri,mode:LaunchMode.externalApplication);},
                                child:Container(padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:const Color(0xFF25D366).withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                    child:const Icon(Icons.chat_outlined,size:16,color:Color(0xFF25D366)))),
                          const SizedBox(width:4),
                          GestureDetector(onTap:()=>_ogrenciBaglaDialog(docs[i].id,d),
                              child:Container(padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                  child:const Icon(Icons.link_outlined,size:16,color:Colors.blue))),
                          const SizedBox(width:4),
                          GestureDetector(onTap:() async{
                            final yeniSifre='S${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                            await FirebaseFirestore.instance.collection('parents').doc(docs[i].id).update({'geciciSifre':yeniSifre});
                            if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Yeni sifre: $yeniSifre'),backgroundColor:Colors.blue,behavior:SnackBarBehavior.floating));},
                              child:Container(padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                  child:const Icon(Icons.key_outlined,size:16,color:Colors.blue))),
                          const SizedBox(width:4),
                          GestureDetector(onTap:() async{await FirebaseFirestore.instance.collection('parents').doc(docs[i].id).update({'aktif':!(d['aktif']??true)});},
                              child:Container(padding:const EdgeInsets.all(6),
                                  decoration:BoxDecoration(color:((d['aktif']??true)?Colors.green:Colors.grey).withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                  child:Icon((d['aktif']??true)?Icons.toggle_on_outlined:Icons.toggle_off_outlined,size:16,color:(d['aktif']??true)?Colors.green:Colors.grey))),
                        ]),
                      ]),
                    ]));
              });
        })),
  ]);
}

//  KAYIT SISTEMI
class _KayitSistemiSekme extends StatefulWidget{
  final String firmaId;const _KayitSistemiSekme({required this.firmaId});
  @override State<_KayitSistemiSekme> createState()=>_KayitSistemiSekmeState();
}
class _KayitSistemiSekmeState extends State<_KayitSistemiSekme>{
  static const _t=Color(0xFFFF8C00);int _s=0;
  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:20,vertical:0),
        child:Row(children:[
          for(final item in[(0,Icons.inbox_outlined,'Bekleyen Basvurular'),(1,Icons.link_outlined,'Kayit Linki'),
            (2,Icons.qr_code_outlined,'QR Karekod'),(3,Icons.person_add_outlined,'Yuz Yuze Kayit')])
            GestureDetector(onTap:()=>setState(()=>_s=item.$1),
                child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(color:_s==item.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[Icon(item.$2,size:16,color:_s==item.$1?_t:Colors.grey),
                      const SizedBox(width:6),Text(item.$3,style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:_s==item.$1?_t:Colors.grey))]))),
        ])),
    Expanded(child:_s==0?_BekleyenBasvurular(firmaId:widget.firmaId):
    _s==1?_KayitLinki(firmaId:widget.firmaId):
    _s==2?_QrKayit(firmaId:widget.firmaId):
    _YuzYuzeKayit(firmaId:widget.firmaId)),
  ]);
}

class _BekleyenBasvurular extends StatelessWidget{
  final String firmaId;static const _navy=Color(0xFF1a3a6b);
  const _BekleyenBasvurular({required this.firmaId});
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('kayit_basvurulari').where('firmaId',isEqualTo:firmaId).orderBy('tarih',descending:true).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Bekleyen basvuru yok','Link veya QR ile gelen basvurular burada gorunur.',Icons.inbox_outlined);
        return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;final dur=d['durum']??'bekliyor';
              final r=dur=='onaylandi'?Colors.green:dur=='reddedildi'?Colors.red:Colors.orange;
              return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:r.withValues(alpha:0.25))),
                  child:Row(children:[
                    CircleAvatar(radius:20,backgroundColor:_navy.withValues(alpha:0.1),
                        child:Text((d['ogrenciAd']??'B')[0].toUpperCase(),style:const TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold))),
                    const SizedBox(width:12),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(d['ogrenciAd']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                      Text(d['veliAd']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                      Text(d['adres']??'',style:TextStyle(fontSize:11,color:Colors.grey[400]),maxLines:1,overflow:TextOverflow.ellipsis),
                      if(d['fiyat']!=null)Text('Fiyat:${d['fiyat']} TL',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600,color:Colors.green)),
                    ])),
                    if(dur=='bekliyor')Row(children:[
                      _AksBtn('Onayla',Colors.green,()async=>FirebaseFirestore.instance.collection('kayit_basvurulari').doc(docs[i].id).update({'durum':'onaylandi'})),
                      const SizedBox(width:6),
                      _AksBtn('Reddet',Colors.red,()async=>FirebaseFirestore.instance.collection('kayit_basvurulari').doc(docs[i].id).update({'durum':'reddedildi'})),
                    ])else Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                        decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                        child:Text(dur,style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:r))),
                  ]));
            });
      });
}

class _KayitLinki extends StatelessWidget{
  final String firmaId;static const _navy=Color(0xFF1a3a6b);
  const _KayitLinki({required this.firmaId});
  @override Widget build(BuildContext context){
    final link='https://servisim.org.tr/#/kayit?firma=$firmaId';
    return Center(child:Container(width:500,padding:const EdgeInsets.all(32),margin:const EdgeInsets.all(24),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:12)]),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),shape:BoxShape.circle),
              child:const Icon(Icons.link_outlined,color:Color(0xFF1a3a6b),size:40)),
          const SizedBox(height:20),const Text('Kayit Linki',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
          const SizedBox(height:8),const Text('Bu linki velilere gonderin.',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey,fontSize:13)),
          const SizedBox(height:20),
          Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF5F7FA),borderRadius:BorderRadius.circular(10)),
              child:SelectableText(link,style:const TextStyle(fontSize:12,fontFamily:'monospace'))),
          const SizedBox(height:16),
          Row(children:[
            Expanded(child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
                onPressed:() async{await Clipboard.setData(ClipboardData(text:link));ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Link kopyalandi!'),backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));},icon:const Icon(Icons.copy_outlined,size:16),label:const Text('Linki Kopyala'))),
            const SizedBox(width:12),
            Expanded(child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF25D366),foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
                onPressed:() async{
                  final msg=Uri.encodeComponent('Servisim360 kayit linki:\n$link');
                  final uri=Uri.parse('https://wa.me/?text='+msg);
                  if(await canLaunchUrl(uri))await launchUrl(uri,mode:LaunchMode.externalApplication);
                },icon:const Icon(Icons.send_outlined,size:16),label:const Text('WhatsApp'))),
          ]),
        ])));
  }
}

class _QrKayit extends StatelessWidget{
  final String firmaId;static const _t=Color(0xFFFF8C00);
  const _QrKayit({required this.firmaId});
  @override Widget build(BuildContext context)=>Center(child:Container(width:400,padding:const EdgeInsets.all(32),margin:const EdgeInsets.all(24),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:12)]),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_t.withValues(alpha:0.1),shape:BoxShape.circle),
            child:const Icon(Icons.qr_code_outlined,color:Color(0xFFFF8C00),size:40)),
        const SizedBox(height:20),const Text('QR Karekod',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
        const SizedBox(height:8),const Text('QR okutan veli kayit formuna yonlendirilir.',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:24),
        Container(width:180,height:180,decoration:BoxDecoration(color:const Color(0xFFF5F7FA),borderRadius:BorderRadius.circular(14),border:Border.all(color:Colors.grey)),
            child:const Center(child:Icon(Icons.qr_code_2_outlined,size:110,color:Colors.black87))),
        const SizedBox(height:20),
        Row(children:[
          Expanded(child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
              onPressed:(){},icon:const Icon(Icons.download_outlined,size:16),label:const Text('QR Indir'))),
          const SizedBox(width:10),
          Expanded(child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF25D366),foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
              onPressed:(){},icon:const Icon(Icons.send_outlined,size:16),label:const Text('WhatsApp'))),
        ]),
      ])));
}

class _YuzYuzeKayit extends StatelessWidget{
  final String firmaId;static const _navy=Color(0xFF1a3a6b);
  const _YuzYuzeKayit({required this.firmaId});
  @override Widget build(BuildContext context)=>Center(child:Container(width:460,padding:const EdgeInsets.all(32),margin:const EdgeInsets.all(24),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:12)]),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),shape:BoxShape.circle),
            child:const Icon(Icons.person_add_outlined,color:Color(0xFF1a3a6b),size:40)),
        const SizedBox(height:20),const Text('Yuz Yuze Kayit',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
        const SizedBox(height:8),const Text('Velinin bilgilerini siz girin.',textAlign:TextAlign.center,style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:24),
        SizedBox(width:double.infinity,child:ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
            onPressed:()=>Navigator.pushNamed(context,'/yuz_yuze_kayit'),
            icon:const Icon(Icons.add_circle_outline,size:16),label:const Text('Kayit Formunu Ac',style:TextStyle(fontWeight:FontWeight.bold)))),
      ])));
}

//  SOZLESMELER
class _SozlesmelerSekme extends StatefulWidget{
  final String firmaId;const _SozlesmelerSekme({required this.firmaId});
  @override State<_SozlesmelerSekme> createState()=>_SozlesmelerSekmeState();
}
class _SozlesmelerSekmeState extends State<_SozlesmelerSekme> with SingleTickerProviderStateMixin{
  static const _navy=Color(0xFF1a3a6b);static const _orange=Color(0xFFFF8C00);
  late TabController _tab;String _filtreDonem='';
  @override void initState(){super.initState();_tab=TabController(length:4,vsync:this);}
  @override void dispose(){_tab.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:TabBar(controller:_tab,labelColor:_navy,unselectedLabelColor:Colors.grey,
        indicatorColor:_orange,isScrollable:true,tabAlignment:TabAlignment.start,
        tabs:const[Tab(icon:Icon(Icons.pending_outlined,size:16),text:'Bekleyen'),
          Tab(icon:Icon(Icons.check_circle_outline,size:16),text:'Imzalanan'),
          Tab(icon:Icon(Icons.timer_off_outlined,size:16),text:'Suresi Dolan'),
          Tab(icon:Icon(Icons.archive_outlined,size:16),text:'Arsiv')])),
    Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
        child:Row(children:[const Icon(Icons.calendar_month_outlined,size:16,color:Colors.grey),const SizedBox(width:8),
          Expanded(child:TextField(decoration:InputDecoration(hintText:'Donem filtre (2025-2026)',isDense:true,
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)),contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:6)),
              onChanged:(v)=>setState(()=>_filtreDonem=v.trim()))),
          const SizedBox(width:8),const Icon(Icons.lock_outlined,size:14,color:_navy),const SizedBox(width:4),
          const Text('Silinemez',style:TextStyle(fontSize:11,color:_navy))])),
    Expanded(child:TabBarView(controller:_tab,children:[
      _SozListesi(firmaId:widget.firmaId,durum:'bekliyor',filtreDonem:_filtreDonem),
      _SozListesi(firmaId:widget.firmaId,durum:'imzalandi',filtreDonem:_filtreDonem),
      _SozListesi(firmaId:widget.firmaId,durum:'suresi_doldu',filtreDonem:_filtreDonem),
      _SozListesi(firmaId:widget.firmaId,durum:'arsiv',filtreDonem:_filtreDonem),
    ])),
  ]);
}

class _SozListesi extends StatelessWidget{
  final String firmaId,durum,filtreDonem;
  const _SozListesi({required this.firmaId,required this.durum,required this.filtreDonem});
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('sozlesmeler').where('firmaId',isEqualTo:firmaId)
          .where('durum',isEqualTo:durum).orderBy('olusturmaTarihi',descending:true).snapshots(),
      builder:(_,snap){
        var docs=snap.data?.docs??[];
        if(filtreDonem.isNotEmpty)docs=docs.where((d){final dd=d.data() as Map<String,dynamic>;return(dd['donem']??'').toString().contains(filtreDonem);}).toList();
        if(docs.isEmpty)return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(Icons.description_outlined,size:56,color:Colors.grey[300]),const SizedBox(height:12),
          Text('$durum durumunda sozlesme yok',style:const TextStyle(color:Colors.grey))]));
        return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;
              final Color renk=durum=='imzalandi'?Colors.green:durum=='bekliyor'?Colors.orange:durum=='suresi_doldu'?Colors.red:Colors.grey;
              return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:renk.withValues(alpha:0.2)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:5)]),
                  child:Row(children:[Icon(Icons.description_outlined,color:renk,size:22),const SizedBox(width:12),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(d['ogrenciAd']??d['kisi']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                      Text('Veli: ${d['veliAd']??''}',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                      if((d['donem']??'').isNotEmpty)Text('Donem: ${d['donem']}',style:TextStyle(fontSize:11,color:Colors.blue[400])),
                      if((d['ucret']??d['fiyat']??0)>0)Text('${d['ucret']??d['fiyat']} TL/ay',style:const TextStyle(fontSize:12,color:Colors.green,fontWeight:FontWeight.w600)),
                    ])),
                    Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                          decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Text(durum,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:renk))),
                      const SizedBox(height:4),
                      GestureDetector(onTap:(){},child:Container(padding:const EdgeInsets.all(6),
                          decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:const Icon(Icons.picture_as_pdf_outlined,color:Colors.red,size:16))),
                      if(durum=='suresi_doldu')...[const SizedBox(height:4),
                        GestureDetector(onTap:()async{await FirebaseFirestore.instance.collection('sozlesmeler').doc(docs[i].id).update({'durum':'arsiv','arsivTarihi':FieldValue.serverTimestamp()});},
                            child:Container(padding:const EdgeInsets.all(6),decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                child:const Icon(Icons.archive_outlined,color:Colors.grey,size:16)))],
                    ]),
                  ]));
            });
      });
}

//  FIYATLANDIRMA
class _FiyatlandirmaSekme extends StatefulWidget{
  final String firmaId;const _FiyatlandirmaSekme({required this.firmaId});
  @override State<_FiyatlandirmaSekme> createState()=>_FiyatlandirmaSekmeState();
}
class _FiyatlandirmaSekmeState extends State<_FiyatlandirmaSekme>{
  static const _navy=Color(0xFF1a3a6b);static const _t=Color(0xFFFF8C00);
  final _bC=TextEditingController();final _fC=TextEditingController();String _tip='bolge';
  Future<void> _ekle() async{
    if(_bC.text.trim().isEmpty||_fC.text.trim().isEmpty)return;
    await FirebaseFirestore.instance.collection('fiyatlar').add({'firmaId':widget.firmaId,
      'bolge':_bC.text.trim(),'fiyat':double.tryParse(_fC.text)??0,'tip':_tip,'olusturmaTarihi':FieldValue.serverTimestamp()});
    _bC.clear();_fC.clear();
  }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Fiyat Listesi',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
          const SizedBox(height:16),
          StreamBuilder<QuerySnapshot>(
              stream:FirebaseFirestore.instance.collection('fiyatlar').where('firmaId',isEqualTo:widget.firmaId).snapshots(),
              builder:(_,snap){
                final docs=snap.data?.docs??[];
                if(docs.isEmpty)return _bos('Fiyat tanimlanmamis','Sagdan fiyat ekleyin.',Icons.payments_outlined);
                return Column(children:docs.map((doc){
                  final d=doc.data() as Map<String,dynamic>;
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                      child:Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.location_on_outlined,color:Colors.green,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['bolge']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                          Text(d['tip']??'bolge',style:TextStyle(fontSize:12,color:Colors.grey[500]))])),
                        Text('${d['fiyat']} TL/ay',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:Colors.green)),
                        const SizedBox(width:10),
                        IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red,size:18),onPressed:()=>FirebaseFirestore.instance.collection('fiyatlar').doc(doc.id).delete()),
                      ]));
                }).toList());
              }),
        ])),
        const SizedBox(width:24),
        Container(width:300,padding:const EdgeInsets.all(24),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:8)]),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Yeni Fiyat Ekle',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
              const SizedBox(height:12),
              Row(children:[for(final t in[('bolge','Bolge'),('mahalle','Mahalle'),('km','Km'),('manuel','Manuel')])
                Expanded(child:GestureDetector(onTap:()=>setState(()=>_tip=t.$1),
                    child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(vertical:8),
                        decoration:BoxDecoration(color:_tip==t.$1?_navy:Colors.grey[50],borderRadius:BorderRadius.circular(7),border:Border.all(color:_tip==t.$1?_navy:Colors.grey)),
                        child:Center(child:Text(t.$2,style:TextStyle(fontSize:10,color:_tip==t.$1?Colors.white:Colors.grey,fontWeight:_tip==t.$1?FontWeight.bold:FontWeight.normal))))))]),
              const SizedBox(height:12),
              TextField(controller:_bC,decoration:InputDecoration(labelText:'Bolge / Mahalle',prefixIcon:const Icon(Icons.location_on_outlined,color:Color(0xFF1a3a6b),size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12))),
              const SizedBox(height:10),
              TextField(controller:_fC,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Aylik Fiyat (TL)',prefixIcon:const Icon(Icons.payments_outlined,color:Color(0xFF1a3a6b),size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12))),
              const SizedBox(height:14),
              SizedBox(width:double.infinity,child:ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
                  onPressed:_ekle,child:const Text('Fiyat Ekle',style:TextStyle(fontWeight:FontWeight.bold)))),
            ])),
      ]));
}

//  DEVAMSIZLIK
class _DevamsizlikSekme extends StatefulWidget{
  final String firmaId;const _DevamsizlikSekme({required this.firmaId});
  @override State<_DevamsizlikSekme> createState()=>_DevamsizlikSekmeState();
}
class _DevamsizlikSekmeState extends State<_DevamsizlikSekme>{
  static const _navy=Color(0xFF1a3a6b);String _f='Tumu';
  Color _r(String d)=>d=='onaylandi'?Colors.green:d=='reddedildi'?Colors.red:Colors.orange;
  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.all(14),color:Colors.white,
        child:Row(children:[const Text('Filtre:',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),const SizedBox(width:12),
          ...['Tumu','bekliyor','onaylandi','reddedildi'].map((d){final sec=_f==d;
          return GestureDetector(onTap:()=>setState(()=>_f=d),
              child:Container(margin:const EdgeInsets.only(right:8),padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
                  decoration:BoxDecoration(color:sec?_navy:Colors.grey[100],borderRadius:BorderRadius.circular(20)),
                  child:Text(d,style:TextStyle(color:sec?Colors.white:Colors.grey[700],fontSize:12,fontWeight:sec?FontWeight.bold:FontWeight.normal))));
          }),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:_f=='Tumu'?FirebaseFirestore.instance.collection('absence_requests').where('firmaId',isEqualTo:widget.firmaId).orderBy('tarih',descending:true).snapshots()
            :FirebaseFirestore.instance.collection('absence_requests').where('firmaId',isEqualTo:widget.firmaId).where('durum',isEqualTo:_f).orderBy('tarih',descending:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Devamsizlik bildirimi yok','',Icons.event_busy_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;final dur=d['durum'] as String? ??'bekliyor';
                final r=_r(dur);final tip=d['tip']??d['tur']??'tum_gun';
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:r.withValues(alpha:0.2))),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Row(children:[Icon(Icons.event_busy_outlined,color:r,size:20),const SizedBox(width:10),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ogrenciAd']??'Ogrenci',style:const TextStyle(fontWeight:FontWeight.bold)),
                          Row(children:[
                            if((d['veliAd']??'').isNotEmpty)Text('Veli:${d['veliAd']}',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                            if((d['servisAd']??'').isNotEmpty)...[const Text(' | ',style:TextStyle(color:Colors.grey)),Text('Servis:${d['servisAd']}',style:TextStyle(fontSize:11,color:Colors.grey[500]))],
                            if((d['projeAd']??d['projeId']??'').isNotEmpty)...[const Text(' | ',style:TextStyle(color:Colors.grey)),Text('Proje:${d['projeAd']??d['projeId']}',style:TextStyle(fontSize:11,color:Colors.blue[400]))],
                          ]),
                          Row(children:[
                            Text(d['tarih']?.toString().substring(0,10)??'',style:TextStyle(fontSize:11,color:Colors.grey[400])),const SizedBox(width:8),
                            Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
                                child:Text(tip=='sabah'?'Sadece Sabah':tip=='aksam'?'Sadece Aksam':'Tum Gun',style:const TextStyle(fontSize:10,color:Colors.blue,fontWeight:FontWeight.bold))),
                          ]),
                          if((d['aciklama']??d['not']??'').isNotEmpty)Text('Sebep:${d['aciklama']??d['not']}',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        ])),
                        if(dur=='bekliyor')Row(children:[
                          _AksBtn('Onayla',Colors.green,()async=>FirebaseFirestore.instance.collection('absence_requests').doc(docs[i].id).update({'durum':'onaylandi','rotaGuncellendi':true,'onayTarihi':FieldValue.serverTimestamp()})),
                          const SizedBox(width:6),
                          _AksBtn('Reddet',Colors.red,()async=>FirebaseFirestore.instance.collection('absence_requests').doc(docs[i].id).update({'durum':'reddedildi'})),
                          const SizedBox(width:6),
                          _AksBtn('Not Ekle',Colors.blue,()async{
                            final notCtrl=TextEditingController(text:d['not']??'');
                            final sonuc=await showDialog<String>(context:context,builder:(_)=>AlertDialog(
                                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
                                title:const Text('Not Ekle',style:TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
                                content:TextField(controller:notCtrl,maxLines:3,decoration:InputDecoration(hintText:'Notunuzu yazin...',border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.all(12))),
                                actions:[TextButton(onPressed:()=>Navigator.pop(_),child:const Text('Iptal')),
                                  ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF1a3a6b),foregroundColor:Colors.white),onPressed:()=>Navigator.pop(_,notCtrl.text.trim()),child:const Text('Kaydet'))]));
                            if(sonuc!=null&&sonuc.isNotEmpty)await FirebaseFirestore.instance.collection('absence_requests').doc(docs[i].id).update({'not':sonuc});
                          }),
                        ])else Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                            child:Text(dur,style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:r))),
                      ]),
                    ]));
              });
        })),
  ]);
}

//  PLAKA TANIMA
class _PlakaTanimaSekme extends StatelessWidget{
  final String firmaId;const _PlakaTanimaSekme({required this.firmaId});
  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),color:Colors.white,
        child:Row(children:[const Text('Plaka Tanima Kayitlari',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:16)),
          const Spacer(),Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
              child:const Row(children:[Icon(Icons.camera_alt_outlined,size:14,color:Colors.green),SizedBox(width:6),Text('Sistem Aktif',style:TextStyle(fontSize:12,color:Colors.green,fontWeight:FontWeight.bold))]))])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('plate_logs').where('firmaId',isEqualTo:firmaId).orderBy('tarih',descending:true).limit(50).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Plaka kaydi yok','Araclar okul girisinde otomatik kayit olusacak.',Icons.camera_alt_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;final esl=d['eslesti']==true;
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:(esl?Colors.green:Colors.red).withValues(alpha:0.25))),
                    child:Row(children:[Icon(Icons.directions_car_outlined,color:esl?Colors.green:Colors.red,size:22),const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['plaka']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16,letterSpacing:1.2)),
                        if((d['soforAd']??'').isNotEmpty)Text(d['soforAd'],style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        Text(d['tarih']?.toString().substring(0,19)??'',style:TextStyle(fontSize:11,color:Colors.grey[400]))])),
                      Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:(esl?Colors.green:Colors.red).withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:Text(esl?'Eslesti':'Uyari',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:esl?Colors.green:Colors.red)))]));
              });
        })),
  ]);
}

//  KAREKOD / QR
class _KarekodQrSekme extends StatelessWidget{
  final String firmaId;static const _navy=Color(0xFF1a3a6b);
  const _KarekodQrSekme({required this.firmaId});
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('QR / Karekod Yonetimi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
        const SizedBox(height:6),const Text('Proje bazli QR olusturun.',style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:24),
        Wrap(spacing:20,runSpacing:20,children:[
          _qrKart('Ogrenci Kayit QR',Icons.school_outlined,Colors.blue,'Veli QR okutunca kayit formuna gider.',context),
          _qrKart('Personel Kayit QR',Icons.badge_outlined,Colors.teal,'Personel QR okutunca kayit formuna gider.',context),
          _qrKart('Veli Daveti QR',Icons.family_restroom_outlined,Colors.purple,'Velileri sisteme davet etmek icin.',context),
          _qrKart('Servis Bilgi QR',Icons.directions_bus_outlined,_navy,'Veli servisi takip etmek icin.',context),
        ]),
      ]));
  Widget _qrKart(String b,IconData i,Color r,String a,BuildContext context)=>Container(width:280,padding:const EdgeInsets.all(20),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:r.withValues(alpha:0.15)),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:8)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),child:Icon(i,color:r,size:24)),
          const Spacer(),Container(width:60,height:60,decoration:BoxDecoration(color:const Color(0xFFF5F7FA),borderRadius:BorderRadius.circular(8),border:Border.all(color:Colors.grey)),
              child:const Center(child:Icon(Icons.qr_code_outlined,size:40,color:Colors.black87)))]),
        const SizedBox(height:14),Text(b,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
        const SizedBox(height:4),Text(a,style:TextStyle(fontSize:12,color:Colors.grey[500])),
        const SizedBox(height:14),
        Row(children:[
          Expanded(child:OutlinedButton.icon(style:OutlinedButton.styleFrom(foregroundColor:r,side:BorderSide(color:r),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),padding:const EdgeInsets.symmetric(vertical:10)),
              onPressed:(){},icon:const Icon(Icons.download_outlined,size:14),label:const Text('Indir',style:TextStyle(fontSize:12)))),
          const SizedBox(width:8),
          Expanded(child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF25D366),foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),padding:const EdgeInsets.symmetric(vertical:10)),
              onPressed:(){},icon:const Icon(Icons.send_outlined,size:14),label:const Text('WA',style:TextStyle(fontSize:12)))),
        ]),
      ]));
}

//  BILDIRIMLER
class _BildirimlerSekme extends StatefulWidget{
  final String firmaId;const _BildirimlerSekme({required this.firmaId});
  @override State<_BildirimlerSekme> createState()=>_BildirimlerSekmeState();
}
class _BildirimlerSekmeState extends State<_BildirimlerSekme>{
  static const _navy=Color(0xFF1a3a6b);static const _t=Color(0xFFFF8C00);
  final _mC=TextEditingController();bool _g=false;String _h='veliler';
  Future<void> _gonder() async{
    if(_mC.text.trim().isEmpty)return;setState(()=>_g=true);
    await FirebaseFirestore.instance.collection('bildirimler').add({'firmaId':widget.firmaId,'mesaj':_mC.text.trim(),'hedef':_h,'tarih':FieldValue.serverTimestamp(),'gonderen':'admin'});
    _mC.clear();setState(()=>_g=false);
  }
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(flex:3,child:Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),color:Colors.white,
          child:const Align(alignment:Alignment.centerLeft,child:Text('Gecmis Bildirimler',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:16)))),
      Expanded(child:StreamBuilder<QuerySnapshot>(
          stream:FirebaseFirestore.instance.collection('bildirimler').where('firmaId',isEqualTo:widget.firmaId).orderBy('tarih',descending:true).limit(30).snapshots(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Bildirim gecmisi bos','',Icons.notifications_none_outlined);
            return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;final h=d['hedef']??'veliler';
                  final r=h=='veliler'?Colors.blue:h=='soforler'?_navy:Colors.purple;
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                      child:Row(children:[Container(padding:const EdgeInsets.all(8),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),child:Icon(Icons.notifications_outlined,color:r,size:18)),
                        const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['mesaj']??'',style:const TextStyle(fontWeight:FontWeight.w500)),
                          Text(d['tarih']?.toString().substring(0,19)??'',style:TextStyle(fontSize:11,color:Colors.grey[400]))])),
                        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                            child:Text(h,style:TextStyle(fontSize:10,color:r,fontWeight:FontWeight.bold)))]));
                });
          })),
    ])),
    Container(width:300,color:Colors.white,padding:const EdgeInsets.all(24),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Bildirim Gonder',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
          const SizedBox(height:18),const Text('Hedef Kitle',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:13)),const SizedBox(height:10),
          ...['veliler','soforler','herkese'].map((h)=>GestureDetector(onTap:()=>setState(()=>_h=h),
              child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  decoration:BoxDecoration(color:_h==h?_navy:Colors.grey[50],borderRadius:BorderRadius.circular(10),border:Border.all(color:_h==h?_navy:Colors.grey)),
                  child:Row(children:[Icon(_h==h?Icons.radio_button_checked:Icons.radio_button_off,color:_h==h?Colors.white:Colors.grey,size:16),const SizedBox(width:10),
                    Text(h[0].toUpperCase()+h.substring(1),style:TextStyle(color:_h==h?Colors.white:Colors.grey[700],fontWeight:FontWeight.w500))])))),
          const SizedBox(height:14),const Text('Mesaj',style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b),fontSize:13)),const SizedBox(height:8),
          TextField(controller:_mC,maxLines:5,decoration:InputDecoration(hintText:'Bildirim mesajini yazin...',border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.all(14))),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,child:ElevatedButton.icon(style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),padding:const EdgeInsets.symmetric(vertical:14)),
              onPressed:_g?null:_gonder,
              icon:_g?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.send_outlined,size:16),
              label:const Text('Gonder',style:TextStyle(fontWeight:FontWeight.bold)))),
        ])),
  ]);
}

//  ARSIV
class _ArsivSekme extends StatefulWidget{
  final String firmaId;const _ArsivSekme({required this.firmaId});
  @override State<_ArsivSekme> createState()=>_ArsivSekmeState();
}
class _ArsivSekmeState extends State<_ArsivSekme>{
  int _s=0;static const _t=Color(0xFFFF8C00);
  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:20,vertical:0),
        child:Row(children:[
          for(final item in[(0,'Eski Ogrenciler'),(1,'Eski Sozlesmeler'),(2,'Servis Raporlari'),(3,'Devamsizlik Gecmisi')])
            GestureDetector(onTap:()=>setState(()=>_s=item.$1),
                child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(color:_s==item.$1?_t:Colors.transparent,width:2))),
                    child:Text(item.$2,style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:_s==item.$1?_t:Colors.grey)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(stream:_str(),builder:(_,snap){
      final docs=snap.data?.docs??[];
      if(docs.isEmpty)return _bos('Arsiv bos','Arsivlenen kayitlar burada gorunecek.',Icons.archive_outlined);
      return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
          itemBuilder:(_,i){
            final d=docs[i].data() as Map<String,dynamic>;
            return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                child:Row(children:[Icon(Icons.archive_outlined,color:Colors.grey[400],size:20),const SizedBox(width:12),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(d['ad']??d['ogrenciAd']??d['kisi']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                    Text(d['tarih']?.toString().substring(0,10)??'',style:TextStyle(fontSize:12,color:Colors.grey[500]))])),
                  Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                      child:const Text('Arsiv',style:TextStyle(fontSize:10,color:Colors.grey,fontWeight:FontWeight.bold)))]));
          });
    })),
  ]);
  Stream<QuerySnapshot> _str(){
    switch(_s){
      case 0:return FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:false).snapshots();
      case 1:return FirebaseFirestore.instance.collection('contracts').where('firmaId',isEqualTo:widget.firmaId).where('durum',isEqualTo:'arsiv').snapshots();
      case 2:return FirebaseFirestore.instance.collection('servis_raporlari').where('firmaId',isEqualTo:widget.firmaId).orderBy('tarih',descending:true).snapshots();
      default:return FirebaseFirestore.instance.collection('absence_requests').where('firmaId',isEqualTo:widget.firmaId).orderBy('tarih',descending:true).snapshots();
    }
  }
}

//  YAKLASAN SERVISLER
class _YaklasanServisler extends StatelessWidget{
  final String firmaId;final void Function(int) onNavigate;
  const _YaklasanServisler({required this.firmaId,required this.onNavigate});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Text('Yaklasan Servis Saatleri',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
      const Spacer(),GestureDetector(onTap:()=>onNavigate(2),child:const Text('Tum Servisler',style:TextStyle(color:Color(0xFF1a3a6b),fontSize:12,fontWeight:FontWeight.bold)))]),
    const SizedBox(height:8),
    StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).snapshots(),
        builder:(ctx,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),
              child:const Row(children:[Icon(Icons.directions_bus_outlined,color:Colors.grey,size:16),SizedBox(width:8),Text('Aktif servis yok',style:TextStyle(color:Colors.grey,fontSize:12))]));
          final servisler=docs.where((d){final data=d.data() as Map<String,dynamic>;return(data['sabahSaati']??'').isNotEmpty||(data['aksamSaati']??'').isNotEmpty;}).take(4).toList();
          if(servisler.isEmpty)return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),
              child:const Row(children:[Icon(Icons.access_time_outlined,color:Colors.grey,size:16),SizedBox(width:8),Text('Servis saati girilmemis',style:TextStyle(color:Colors.grey,fontSize:12))]));
          return Column(children:servisler.map((doc){
            final d=doc.data() as Map<String,dynamic>;final sab=d['sabahSaati'] as String? ??'';final aks=d['aksamSaati'] as String? ??'';
            return GestureDetector(onTap:()=>_ServisDuzenleDialog.goster(ctx,doc.id,d,firmaId),
                child:Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0xFF1a3a6b).withValues(alpha:0.12))),
                    child:Row(children:[const Icon(Icons.directions_bus_outlined,color:Color(0xFF1a3a6b),size:16),const SizedBox(width:8),
                      Expanded(child:Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12))),
                      if(sab.isNotEmpty)Container(margin:const EdgeInsets.only(right:6),padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                          decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.wb_sunny_outlined,size:11,color:Colors.orange),const SizedBox(width:3),Text(sab,style:const TextStyle(fontSize:11,color:Colors.orange,fontWeight:FontWeight.bold))])),
                      if(aks.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                          decoration:BoxDecoration(color:Colors.indigo.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Row(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.nights_stay_outlined,size:11,color:Colors.indigo),const SizedBox(width:3),Text(aks,style:const TextStyle(fontSize:11,color:Colors.indigo,fontWeight:FontWeight.bold))])),
                    ])));
          }).toList());
        }),
  ]);
}

//  SHARED
class _SonDevamsizliklar extends StatelessWidget{
  final String firmaId;const _SonDevamsizliklar({required this.firmaId});
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('absence_requests').where('firmaId',isEqualTo:firmaId).orderBy('tarih',descending:true).limit(5).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),
            child:const Row(children:[Icon(Icons.check_circle_outline,color:Colors.green,size:16),SizedBox(width:8),Text('Bekleyen devamsizlik yok',style:TextStyle(color:Colors.grey))]));
        return Column(children:docs.map((doc){
          final d=doc.data() as Map<String,dynamic>;final dur=d['durum'] as String? ??'bekliyor';
          final r=dur=='onaylandi'?Colors.green:dur=='reddedildi'?Colors.red:Colors.orange;
          return Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:r.withValues(alpha:0.3))),
              child:Row(children:[Icon(Icons.event_busy_outlined,color:r,size:15),const SizedBox(width:8),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(d['ogrenciAd']??'Ogrenci',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                  Text(d['aciklama']??'',style:TextStyle(fontSize:10,color:Colors.grey[500]),maxLines:1,overflow:TextOverflow.ellipsis)])),
                Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(5)),
                    child:Text(dur,style:TextStyle(fontSize:9,fontWeight:FontWeight.bold,color:r)))]));
        }).toList());
      });
}

class _AksBtn extends StatelessWidget{
  final String label;final Color renk;final VoidCallback onTap;
  const _AksBtn(this.label,this.renk,this.onTap);
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,
      child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
          decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6),border:Border.all(color:renk.withValues(alpha:0.3))),
          child:Text(label,style:TextStyle(fontSize:11,color:renk,fontWeight:FontWeight.bold))));
}

//  SERVIS DUZENLEME DIYALOGU
class _ServisDuzenleDialog{
  static void goster(BuildContext context,String servisId,Map<String,dynamic> servis,String firmaId){
    final adCtrl=TextEditingController(text:servis['ad']??'');
    final kapCtrl=TextEditingController(text:servis['kapasite']?.toString()??'17');
    final sabahCtrl=TextEditingController(text:servis['sabahSaati']??'');
    final aksamCtrl=TextEditingController(text:servis['aksamSaati']??'');
    String? secSoforId=servis['soforId']?.toString().isNotEmpty==true?servis['soforId']:null;
    String? secProjeId=servis['projeId']?.toString().isNotEmpty==true?servis['projeId']:null;
    bool aktif=servis['aktif']==true;bool otoBaslat=servis['autoStartEnabled']==true;bool kaydediliyor=false;
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),contentPadding:EdgeInsets.zero,
        content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(padding:const EdgeInsets.all(16),decoration:const BoxDecoration(color:Color(0xFF1a3a6b),borderRadius:BorderRadius.vertical(top:Radius.circular(16))),
              child:Row(children:[const Icon(Icons.directions_bus_outlined,color:Colors.white,size:20),const SizedBox(width:10),
                Expanded(child:Text(adCtrl.text.isNotEmpty?adCtrl.text:'Servis Duzenle',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))),
                IconButton(icon:const Icon(Icons.close,color:Colors.white54,size:18),onPressed:()=>Navigator.pop(ctx),padding:EdgeInsets.zero,constraints:const BoxConstraints())])),
          Flexible(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(children:[
            Row(children:[Expanded(child:_tf(adCtrl,'Servis Adi *',Icons.directions_bus_outlined)),const SizedBox(width:10),Expanded(child:_tf(kapCtrl,'Kapasite',Icons.people_outlined))]),
            const SizedBox(height:10),
            FutureBuilder(future:FirebaseFirestore.instance.collection('projects').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).get(),
                builder:(_,snap){final prjList=snap.data?.docs.map((d)=>{'id':d.id,...d.data()}).toList()??[];
                return DropdownButtonFormField<String?>(value:secProjeId,decoration:const InputDecoration(labelText:'Bagli Proje',prefixIcon:Icon(Icons.folder_outlined,size:18,color:Color(0xFF1a3a6b)),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
                    items:[const DropdownMenuItem<String?>(value:null,child:Text('Proje Sec...')),
                      ...prjList.map((p)=>DropdownMenuItem<String?>(value:p['id'] as String,child:Text(p['projeAd']??'')))],onChanged:(v)=>setS(()=>secProjeId=v));}),
            const SizedBox(height:10),
            FutureBuilder(future:FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:firmaId).get(),
                builder:(_,snap){final sofList=snap.data?.docs.map((d)=>{'id':d.id,...d.data()}).toList()??[];
                return DropdownButtonFormField<String?>(value:secSoforId,decoration:const InputDecoration(labelText:'Bagli Sofor',prefixIcon:Icon(Icons.person_outlined,size:18,color:Color(0xFF1a3a6b)),border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
                    items:[const DropdownMenuItem<String?>(value:null,child:Text('Sofor Sec...')),
                      ...sofList.map((s)=>DropdownMenuItem<String?>(value:s['id'] as String,child:Text(s['ad']??s['adSoyad']??'Sofor')))],onChanged:(v)=>setS(()=>secSoforId=v));}),
            const SizedBox(height:10),
            Row(children:[Expanded(child:_tf(sabahCtrl,'Sabah Saati',Icons.wb_sunny_outlined)),const SizedBox(width:10),Expanded(child:_tf(aksamCtrl,'Aksam Saati',Icons.nights_stay_outlined))]),
            const SizedBox(height:12),
            Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),decoration:BoxDecoration(color:const Color(0xFFF5F7FA),borderRadius:BorderRadius.circular(10)),
                child:Column(children:[
                  Row(children:[const Icon(Icons.power_settings_new_outlined,size:18,color:Color(0xFF1a3a6b)),const SizedBox(width:10),const Expanded(child:Text('Aktif',style:TextStyle(fontWeight:FontWeight.w600))),Switch(value:aktif,activeColor:Colors.green,onChanged:(v)=>setS(()=>aktif=v))]),
                  Row(children:[const Icon(Icons.alarm_outlined,size:18,color:Color(0xFF1a3a6b)),const SizedBox(width:10),const Expanded(child:Text('Otomatik Baslat',style:TextStyle(fontWeight:FontWeight.w600))),Switch(value:otoBaslat,activeColor:Color(0xFFFF8C00),onChanged:(v)=>setS(()=>otoBaslat=v))]),
                ])),
          ]))),
          Padding(padding:const EdgeInsets.all(16),child:Row(children:[
            Expanded(child:OutlinedButton(style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:13),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal'))),
            const SizedBox(width:12),
            Expanded(flex:2,child:ElevatedButton.icon(
                style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF1a3a6b),foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(vertical:13),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                onPressed:kaydediliyor?null:() async{
                  if(adCtrl.text.trim().isEmpty)return;setS(()=>kaydediliyor=true);
                  try{
                    await FirebaseFirestore.instance.collection('services').doc(servisId).update({'ad':adCtrl.text.trim(),'kapasite':int.tryParse(kapCtrl.text)??17,'projeId':secProjeId??'','soforId':secSoforId??'','sabahSaati':sabahCtrl.text.trim(),'aksamSaati':aksamCtrl.text.trim(),'aktif':aktif,'autoStartEnabled':otoBaslat,'updatedAt':FieldValue.serverTimestamp()});
                    if(secSoforId!=null&&secSoforId!.isNotEmpty)await FirebaseFirestore.instance.collection('drivers').doc(secSoforId).update({'servisId':servisId,'servisAd':adCtrl.text.trim(),'projeId':secProjeId??'','durum':'projeye_dahil','updatedAt':FieldValue.serverTimestamp()});
                    if(ctx.mounted){Navigator.pop(ctx);ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Servis guncellendi'),backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));}
                  }catch(e){setS(()=>kaydediliyor=false);}
                },
                icon:kaydediliyor?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.save_outlined,size:16),
                label:Text(kaydediliyor?'Kaydediliyor...':'Kaydet',style:const TextStyle(fontWeight:FontWeight.bold)))),
          ])),
        ])))));
  }
  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:const Color(0xFF1a3a6b),size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12)));
}

class _TipBtn extends StatelessWidget{
  final String deger,etiket,secili;final IconData ikon;final ValueChanged<String> onSec;
  const _TipBtn(this.deger,this.etiket,this.ikon,this.secili,this.onSec);
  @override Widget build(BuildContext context){
    final aktif=secili==deger;const navy=Color(0xFF1a3a6b);
    return Expanded(child:GestureDetector(onTap:()=>onSec(deger),
        child:Container(padding:const EdgeInsets.symmetric(vertical:10),
            decoration:BoxDecoration(color:aktif?navy:Colors.grey[50],borderRadius:BorderRadius.circular(8),border:Border.all(color:aktif?navy:Colors.grey)),
            child:Column(children:[Icon(ikon,color:aktif?Colors.white:Colors.grey,size:18),const SizedBox(height:4),
              Text(etiket,style:TextStyle(fontSize:11,color:aktif?Colors.white:Colors.grey,fontWeight:aktif?FontWeight.bold:FontWeight.normal))]))));
  }
}

Widget _bos(String b,String a,IconData i)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
  Icon(i,size:64,color:Colors.grey[300]),const SizedBox(height:14),
  Text(b,style:const TextStyle(fontSize:16,color:Colors.grey,fontWeight:FontWeight.bold)),
  if(a.isNotEmpty)...[const SizedBox(height:8),Text(a,style:TextStyle(fontSize:13,color:Colors.grey[400]),textAlign:TextAlign.center)],
]));

class _BosEkran extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  const _BosEkran({required this.baslik, required this.ikon});
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha:0.1), shape: BoxShape.circle),
        child: Icon(ikon, size: 56, color: Colors.grey[300])),
    const SizedBox(height: 16),
    Text(baslik, style: const TextStyle(
        fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
    const SizedBox(height: 8),
    Text('Bu modul henuz aktif degil.',
        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    const SizedBox(height: 4),
    Text('Dosyayi lib/screens/ klasorune kopyalayinca aktif olacak.',
        style: TextStyle(color: Colors.grey[300], fontSize: 11),
        textAlign: TextAlign.center),
  ],
  ));
}
