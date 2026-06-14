// lib/screens/web_admin_panel.dart - Servisim360 Web Admin v5 - 21 Menu
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'package:servisim360/screens/web_soforler.dart' as wsofor;
import 'web_harita.dart';
import 'web_ayarlar.dart';
import 'web_test_merkezi.dart';
import 'web_aracmerkezi.dart';
import 'web_arsiv_merkezi.dart';
import 'rotalar_screen.dart';
import 'web_yedekleme_arsiv.dart';

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
  int _bekleyenSozlesme=0,_acilDurum=0;
  int _toplamProje=0;
  String _aramaFirma='';
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
    _MenuItem('Guzergahlar',    Icons.alt_route_outlined,          22),
    _MenuItem('Canli Takip',    Icons.gps_fixed_outlined,           23),
    _MenuItem('Tahsilat',       Icons.account_balance_wallet_outlined, 24),
    _MenuItem('Guvenlik',       Icons.security_outlined,                25),
    _MenuItem('Acil Durum',     Icons.emergency_outlined,               26),
    _MenuItem('Yapay Zeka',      Icons.auto_awesome_outlined,            27),
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
        // Duplicate temizle - ayni projeAd varsa sadece ilkini al
        final _raw=projSnap.docs.map((d)=>{'id':d.id,...d.data()}).toList();
        final _goruldu=<String>{};
        _projeler=_raw.where((p){
          final ad=(p['projeAd']??p['ad']??'').toString().trim().toLowerCase();
          if(ad.isEmpty)return true;
          if(_goruldu.contains(ad))return false;
          _goruldu.add(ad);
          return true;
        }).toList();
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
      // Toplam proje sayisi
      try{
        final projSnap=await FirebaseFirestore.instance.collection('projects').where('firmaId',isEqualTo:_firmaId).where('aktif',isEqualTo:true).count().get();
        if(mounted)setState(()=>_toplamProje=projSnap.count??0);
      }catch(_){}
      // Bekleyen sozlesme ve acil durum - setState disinda
      try{
        final sozSnap=await FirebaseFirestore.instance.collection('sozlesmeler')
            .where('firmaId',isEqualTo:_firmaId).where('durum',isEqualTo:'bekliyor').count().get();
        final acilSnap=await FirebaseFirestore.instance.collection('bildirimler')
            .where('firmaId',isEqualTo:_firmaId).where('tip',isEqualTo:'acil')
            .where('okundu',isEqualTo:false).count().get();
        if(mounted)setState((){
          _bekleyenSozlesme=sozSnap.count??0;
          _acilDurum=acilSnap.count??0;
        });
      }catch(_){}
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

  Future<void> _ciftKayitTemizle() async{
    final snack=ScaffoldMessenger.of(context);
    // Ayni projeAd'a sahip duplicate'leri bul
    final snap=await FirebaseFirestore.instance.collection('projects')
        .where('firmaId',isEqualTo:_firmaId).get();
    final Map<String,List<String>> adMap=<String,List<String>>{};
    for(final doc in snap.docs){
      final ad=(doc.data()['projeAd']??doc.data()['ad']??'').toString().trim();
      if(ad.isEmpty)continue;
      adMap.putIfAbsent(ad,()=><String>[]);
      adMap[ad]!.add(doc.id);
    }
    int silinen=0;
    for(final entry in adMap.entries){
      if(entry.value.length>1){
        // Ilkini tut, gerisini sil (aktif:false yap)
        for(int i=1;i<entry.value.length;i++){
          await FirebaseFirestore.instance.collection('projects')
              .doc(entry.value[i]).update({'aktif':false,'durum':'arsiv'});
          silinen++;
        }
      }
    }
    snack.showSnackBar(SnackBar(
        content:Text(silinen>0?'$silinen tekrar kayit temizlendi':'Tekrar kayit bulunamadi'),
        backgroundColor:silinen>0?Colors.green:Colors.blue,
        behavior:SnackBarBehavior.floating));
    if(silinen>0)_yukle();
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
        // ═══════════════════════════════════════════════
        // SOL SIDEBAR - FIRMA AGACI
        // ═══════════════════════════════════════════════
        Container(width:220,color:_navy,child:Column(children:[

          // ── LOGO + FIRMA ADI ──
          Container(padding:const EdgeInsets.all(14),child:Column(children:[
            Row(children:[
              Container(width:32,height:32,decoration:BoxDecoration(color:_turuncu,borderRadius:BorderRadius.circular(8)),
                  child:const Center(child:Text('S',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:16)))),
              const SizedBox(width:10),
              const Expanded(child:Text('Servisim360',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:14))),
            ]),
            const SizedBox(height:4),
            Text(_firmaAdi,style:TextStyle(color:Colors.white.withValues(alpha:0.5),fontSize:10),overflow:TextOverflow.ellipsis),
          ])),

          // ── ARAMA KUTUSU ──
          Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
              child:TextField(
                  onChanged:(v)=>setState(()=>_aramaFirma=v),
                  style:const TextStyle(color:Colors.white,fontSize:11),
                  decoration:InputDecoration(
                    hintText:'Firma / Proje ara...',hintStyle:TextStyle(color:Colors.white38,fontSize:11),
                    prefixIcon:const Icon(Icons.search,color:Colors.white38,size:14),
                    filled:true,fillColor:Colors.white.withValues(alpha:0.08),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:BorderSide.none),
                    contentPadding:const EdgeInsets.symmetric(horizontal:8,vertical:6),isDense:true,
                  ))),

          const SizedBox(height:4),
          const Divider(color:Colors.white12),

          // ── FIRMA AGACI ──
          Container(
            margin:const EdgeInsets.symmetric(horizontal:10,vertical:4),
            decoration:BoxDecoration(
              color:Colors.white.withValues(alpha:0.08),
              borderRadius:BorderRadius.circular(10),
              border:Border.all(color:_projeId.isNotEmpty?_turuncu.withValues(alpha:0.5):Colors.white.withValues(alpha:0.1)),
            ),
            child:Column(children:[
              // Firma header - tiklaninca expand
              GestureDetector(
                  onTap:()=>setState(()=>_projeMenuAcik=!_projeMenuAcik),
                  child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:10),
                      child:Row(children:[
                        Icon(Icons.business_outlined,color:_projeId.isNotEmpty?_turuncu:Colors.white54,size:15),
                        const SizedBox(width:8),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(_firmaAdi.isNotEmpty?_firmaAdi:'Tum Firma',
                              style:TextStyle(color:_projeId.isNotEmpty?_turuncu:Colors.white,fontSize:11,fontWeight:FontWeight.bold),
                              overflow:TextOverflow.ellipsis),
                          if(_projeMenuAcik)Text('${_projeler.length} proje',
                              style:const TextStyle(color:Colors.white38,fontSize:9)),
                        ])),
                        PopupMenuButton<String>(
                            icon:const Icon(Icons.more_vert,color:Colors.white38,size:14),
                            padding:EdgeInsets.zero,
                            onSelected:(v){
                              if(v=='proje')_projeEkleDialog();
                              else if(v=='temizle')_ciftKayitTemizle();
                            },
                            itemBuilder:(_)=>[
                              const PopupMenuItem(value:'proje',child:Row(children:[Icon(Icons.add,size:14),SizedBox(width:8),Text('Proje Ekle')])),
                              const PopupMenuItem(value:'temizle',child:Row(children:[Icon(Icons.cleaning_services_outlined,size:14,color:Colors.red),SizedBox(width:8),Text('Cift Kayitlari Temizle',style:TextStyle(color:Colors.red))])),
                            ]),
                        Icon(_projeMenuAcik?Icons.expand_less:Icons.expand_more,color:Colors.white38,size:14),
                      ]))),
              // Proje listesi - expand olunca acilir
              if(_projeMenuAcik)...[
                const Divider(color:Colors.white12,height:1),
                // Tum Firma butonu
                GestureDetector(onTap:_projeTumFirma,
                    child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                        decoration:BoxDecoration(color:_projeId.isEmpty?Colors.white.withValues(alpha:0.1):Colors.transparent),
                        child:Row(children:[
                          Icon(Icons.folder_open_outlined,color:_projeId.isEmpty?_turuncu:Colors.white54,size:13),
                          const SizedBox(width:8),
                          Expanded(child:Text('Tum Firma',style:TextStyle(
                              color:_projeId.isEmpty?Colors.white:Colors.white60,
                              fontSize:10,fontWeight:_projeId.isEmpty?FontWeight.bold:FontWeight.normal))),
                          if(_projeId.isEmpty)const Icon(Icons.check,color:Color(0xFFFF8C00),size:11),
                        ]))),
                // Proje listesi - deduplicate + arama filtresi
                ...(){
                  // Deduplicate: ayni projeAd varsa sadece ilkini goster
                  final goruldu=<String>{};
                  final unique=_projeler.where((p){
                    final ad=(p['projeAd']??p['ad']??'').toString().trim().toLowerCase();
                    if(ad.isEmpty)return true;
                    if(goruldu.contains(ad))return false;
                    goruldu.add(ad);
                    return true;
                  }).toList();
                  // Arama filtresi
                  return unique.where((p)=>_aramaFirma.isEmpty||
                      (p['projeAd']??'').toString().toLowerCase().contains(_aramaFirma.toLowerCase()));
                }().map((prj){
                  final secili=_projeId==prj['id'];
                  return Container(
                      decoration:BoxDecoration(color:secili?_turuncu.withValues(alpha:0.15):Colors.transparent),
                      child:Row(children:[
                        // Proje tiklama alani
                        Expanded(child:GestureDetector(onTap:()=>_projeAyarla(prj['id'],prj['projeAd']??''),
                            child:Padding(padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
                                child:Row(children:[
                                  Container(width:4,height:4,decoration:BoxDecoration(
                                      color:secili?_turuncu:Colors.white38,shape:BoxShape.circle)),
                                  const SizedBox(width:10),
                                  Expanded(child:Text(prj['projeAd']??'',
                                      style:TextStyle(color:secili?_turuncu:Colors.white60,
                                          fontSize:10,fontWeight:secili?FontWeight.bold:FontWeight.normal),
                                      overflow:TextOverflow.ellipsis)),
                                  if(secili)const Icon(Icons.check,color:Color(0xFFFF8C00),size:10),
                                ])))),
                        // Uc nokta menu
                        PopupMenuButton<String>(
                            icon:Icon(Icons.more_vert,color:Colors.white38.withValues(alpha:secili?0.8:0.4),size:13),
                            padding:EdgeInsets.zero,
                            onSelected:(v) async{
                              if(v=='ac'){_projeAyarla(prj['id'],prj['projeAd']??'');}
                              else if(v=='harita'){setState(()=>_aktifSekme=10);_projeAyarla(prj['id'],prj['projeAd']??'');}
                              else if(v=='soforler'){setState(()=>_aktifSekme=4);_projeAyarla(prj['id'],prj['projeAd']??'');}
                              else if(v=='servisler'){setState(()=>_aktifSekme=2);_projeAyarla(prj['id'],prj['projeAd']??'');}
                              else if(v=='arsiv'){
                                await FirebaseFirestore.instance.collection('projects')
                                    .doc(prj['id']).update({'aktif':false,'durum':'arsiv'});
                                _yukle();
                              }
                            },
                            itemBuilder:(_)=>[
                              const PopupMenuItem(value:'ac',child:Row(children:[Icon(Icons.open_in_new_outlined,size:13),SizedBox(width:8),Text('Ac',style:TextStyle(fontSize:12))])),
                              const PopupMenuItem(value:'harita',child:Row(children:[Icon(Icons.map_outlined,size:13),SizedBox(width:8),Text('Haritada Goster',style:TextStyle(fontSize:12))])),
                              const PopupMenuItem(value:'soforler',child:Row(children:[Icon(Icons.person_outlined,size:13),SizedBox(width:8),Text('Soforleri Gor',style:TextStyle(fontSize:12))])),
                              const PopupMenuItem(value:'servisler',child:Row(children:[Icon(Icons.directions_bus_outlined,size:13),SizedBox(width:8),Text('Servisleri Gor',style:TextStyle(fontSize:12))])),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value:'arsiv',child:Row(children:[Icon(Icons.archive_outlined,size:13,color:Colors.orange),SizedBox(width:8),Text('Arsivle',style:TextStyle(fontSize:12,color:Colors.orange))])),
                            ]),
                      ]));
                }).toList(),
                // Yeni proje ekle
                const Divider(color:Colors.white12,height:1),
                GestureDetector(
                    onTap:(){setState(()=>_projeMenuAcik=false);_projeEkleDialog();},
                    child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:9),
                        child:Row(children:[
                          Container(padding:const EdgeInsets.all(3),
                              decoration:BoxDecoration(color:_turuncu.withValues(alpha:0.2),borderRadius:BorderRadius.circular(4)),
                              child:const Icon(Icons.add,color:Color(0xFFFF8C00),size:11)),
                          const SizedBox(width:8),
                          const Text('Yeni Proje Olustur',style:TextStyle(color:Color(0xFFFF8C00),fontSize:10,fontWeight:FontWeight.bold)),
                        ]))),
              ],
            ]),
          ),

          const SizedBox(height:6),
          const Divider(color:Colors.white12),

          // ── MENU LISTESI ──
          Expanded(child:ListView(padding:EdgeInsets.zero,children:_menuler.map((item){
            final secili=_aktifSekme==item.index;
            int badge=0;
            if(item.index==7)badge=_bekleyenBasvuru;
            if(item.index==11)badge=_bekleyenDevamsizlik;
            return GestureDetector(onTap:()=>setState(()=>_aktifSekme=item.index),
                child:Container(
                    margin:const EdgeInsets.symmetric(horizontal:10,vertical:2),
                    padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
                    decoration:BoxDecoration(
                      color:secili?Colors.white.withValues(alpha:0.1):Colors.transparent,
                      borderRadius:BorderRadius.circular(10),
                      border:secili?Border.all(color:_turuncu.withValues(alpha:0.5)):null,
                    ),
                    child:Row(children:[
                      Icon(item.ikon,color:secili?_turuncu:Colors.white54,size:16),
                      const SizedBox(width:10),
                      Expanded(child:Text(item.ad,style:TextStyle(color:secili?Colors.white:Colors.white60,
                          fontWeight:secili?FontWeight.bold:FontWeight.normal,fontSize:11))),
                      if(badge>0)Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:1),
                          decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(10)),
                          child:Text('$badge',style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.bold))),
                    ])));
          }).toList())),

          // ── KULLANICI ──
          Container(padding:const EdgeInsets.all(12),
              child:Row(children:[
                CircleAvatar(radius:13,backgroundColor:_turuncu,
                    child:Text(_kullaniciAd.isNotEmpty?_kullaniciAd[0].toUpperCase():'A',
                        style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:11))),
                const SizedBox(width:8),
                Expanded(child:Text(_kullaniciAd,style:const TextStyle(color:Colors.white70,fontSize:10),overflow:TextOverflow.ellipsis)),
                IconButton(icon:const Icon(Icons.logout_outlined,color:Colors.white38,size:14),
                    padding:EdgeInsets.zero,constraints:const BoxConstraints(),
                    onPressed:() async{
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
          bekleyenSozlesme:_bekleyenSozlesme,acilDurum:_acilDurum,toplamProje:_toplamProje,
          onNavigate:(i)=>setState(()=>_aktifSekme=i));
      case 1:return _ProjelerSekme(firmaId:_firmaId,projeler:_projeler,onProjeAyarla:_projeAyarla,onProjeEkle:_projeEkleDialog);
      case 2:return _ServislerSekme(firmaId:_firmaId,projeId:_projeId);
      case 3:return _AraclarSekme(firmaId:_firmaId);
      case 4:return wsofor.WebSoforler(firmaId:_firmaId);
      case 5:return _WebOgrencilerSekme(firmaId:_firmaId);
      case 6:return _VelilerSekme(firmaId:_firmaId,projeId:_projeId);
      case 7:return _KayitSistemiSekme(firmaId:_firmaId);
      case 8:return _SozlesmelerSekme(firmaId:_firmaId);
      case 9:return _FiyatlandirmaSekme(firmaId:_firmaId);
      case 10:return _HaritaModul(firmaId:_firmaId,projeId:_projeId);
      case 11:return _DevamsizlikSekme(firmaId:_firmaId);
      case 12:return _PlakaTanimaSekme(firmaId:_firmaId);
      case 13:return _KarekodQrSekme(firmaId:_firmaId);
      case 14:return _BildirimlerSekme(firmaId:_firmaId);
      case 15:return _WebRaporlarSekme(firmaId:_firmaId,projeId:_projeId);
      case 16:return _ArsivSekme(firmaId:_firmaId);
      case 17:return const WebAyarlar();
      case 18:return const WebTestMerkezi();
      case 19:return const WebAracMerkezi();
      case 20:return const WebArsivMerkezi();
      case 21:return const WebYedekleme();
      case 22:return const _WebRotalarWrapper();
      case 23:return _CanliTakipEkrani();
      case 24:return _TahsilatSekme(firmaId:_firmaId,projeId:_projeId);
      case 25:return _GuvenlikSekme(firmaId:_firmaId);
      case 26:return _AcilDurumSekme(firmaId:_firmaId);
      case 27:return _YapayZekaSekme(firmaId:_firmaId);

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
  final int bekleyenSozlesme,acilDurum,toplamProje;
  final void Function(int) onNavigate;
  static const _navy=Color(0xFF1a3a6b);
  const _WebAnaSayfa({required this.firmaId,required this.projeId,required this.projeAd,
    required this.toplamSurucu,required this.toplamOgrenci,required this.toplamVeli,
    required this.toplamServis,required this.aktifServis,required this.bekleyenDevamsizlik,
    required this.bekleyenBasvuru,required this.atanmamisOgrenci,required this.konumsuzOgrenci,
    required this.bekleyenSozlesme,required this.acilDurum,required this.toplamProje,required this.onNavigate});

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if(bekleyenBasvuru>0)    _bnr(bekleyenBasvuru.toString()+' bekleyen kayit basvurusu',Colors.orange,'Incele',()=>onNavigate(7)),
        if(bekleyenSozlesme>0)   _bnr(bekleyenSozlesme.toString()+' bekleyen sozlesme imzasi',Colors.purple,'Gor',()=>onNavigate(8)),
        if(acilDurum>0)          _bnr(acilDurum.toString()+' acil durum bildirimi!',Colors.red,'Hemen Bak',()=>onNavigate(23)),

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
            _YaklasanServislerEski(firmaId:firmaId,onNavigate:onNavigate),
            const SizedBox(height:18),
            _DashTahsilatOzeti(firmaId:firmaId),
            const SizedBox(height:18),
            Row(children:[
              const Text('Son Devamsizliklar',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Color(0xFF1a3a6b))),
              const Spacer(),
              GestureDetector(onTap:()=>onNavigate(11),
                  child:const Text('Tumunu Gor',style:TextStyle(color:Color(0xFF1a3a6b),fontSize:12,fontWeight:FontWeight.bold))),
            ]),
            const SizedBox(height:10),
            _SonDevamsizliklar(firmaId:firmaId),
            const SizedBox(height:18),
            _AracUyarilar(firmaId:firmaId,onNavigate:onNavigate),
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
// ─────────────────────────────────────────────────────────────────
//  PROJELER SEKMESI  –  Tam Ozellikli
// ─────────────────────────────────────────────────────────────────
class _ProjelerSekme extends StatefulWidget{
  final String firmaId;
  final List<Map<String,dynamic>> projeler;
  final void Function(String,String) onProjeAyarla;
  final VoidCallback onProjeEkle;
  const _ProjelerSekme({required this.firmaId,required this.projeler,
    required this.onProjeAyarla,required this.onProjeEkle});
  @override State<_ProjelerSekme> createState()=>_ProjelerSekmeState();
}
class _ProjelerSekmeState extends State<_ProjelerSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  // 0=Tumu 1=Aktif 2=Pasif 3=Arsiv 4=Taslak
  int _filtre=0;

  // Firestore'dan tam proje listesi - istatistiklerle birlikte
  Stream<QuerySnapshot> get _projeStream =>
      FirebaseFirestore.instance.collection('projects')
          .where('firmaId',isEqualTo:widget.firmaId)
          .orderBy('olusturmaTarihi',descending:true)
          .snapshots();

  @override Widget build(BuildContext context)=>Column(children:[
    // Header
    Container(padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),color:Colors.white,
        child:Row(children:[
          const Text('Projeler',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:18)),
          const Spacer(),
          // Filtre chips
          for(final f in [
            (0,'Tumu',Colors.grey),
            (1,'Aktif',Colors.green),
            (2,'Pasif',Colors.orange),
            (3,'Arsiv',Colors.grey),
            (4,'Taslak',Colors.blue),
          ])
            GestureDetector(
              onTap:()=>setState(()=>_filtre=f.$1),
              child:Container(
                margin:const EdgeInsets.only(right:6),
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                decoration:BoxDecoration(
                    color:_filtre==f.$1?f.$3.withValues(alpha:0.15):Colors.grey.withValues(alpha:0.06),
                    borderRadius:BorderRadius.circular(8),
                    border:Border.all(color:_filtre==f.$1?f.$3:Colors.transparent)),
                child:Text(f.$2,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,
                    color:_filtre==f.$1?f.$3:Colors.grey)),
              ),
            ),
          const SizedBox(width:8),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:10)),
            onPressed:()=>_projeEkleDialog(context),
            icon:const Icon(Icons.add,size:16),
            label:const Text('Yeni Proje'),
          ),
        ])),
    // Liste
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:_projeStream,
        builder:(_,snap){
          if(!snap.hasData) return const Center(child:CircularProgressIndicator(color:_navy));
          var docs=snap.data!.docs;
          if(_filtre!=0){
            final durumMap={1:'aktif',2:'pasif',3:'arsiv',4:'taslak'};
            final hedef=durumMap[_filtre]!;
            docs=docs.where((d){
              final data=d.data() as Map<String,dynamic>;
              final durum=(data['durum'] as String?)??(data['aktif']==true?'aktif':'arsiv');
              return durum==hedef;
            }).toList();
          }
          if(docs.isEmpty) return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.folder_open_outlined,size:64,color:Colors.grey[300]),
            const SizedBox(height:12),
            const Text('Proje bulunamadi',style:TextStyle(color:Colors.grey,fontSize:16)),
            const SizedBox(height:16),
            ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:()=>_projeEkleDialog(context),
              icon:const Icon(Icons.add),label:const Text('Ilk Projeyi Olustur'),
            ),
          ]));
          return ListView.builder(
            padding:const EdgeInsets.all(20),
            itemCount:docs.length,
            itemBuilder:(_,i){
              final doc=docs[i];
              final d=doc.data() as Map<String,dynamic>;
              return _ProjeKarti(
                projeId:doc.id,
                data:d,
                firmaId:widget.firmaId,
                onSec:()=>widget.onProjeAyarla(doc.id,d['projeAd']??d['ad']??''),
                onDuzenle:()=>_projeDuzenleDialog(context,doc.id,d),
                onAyarlar:()=>_projeAyarlarDialog(context,doc.id,d),
                onKopyala:()=>_projeKopyala(context,doc.id,d),
                onArsivle:()=>_projeArsivle(context,doc.id,d),
              );
            },
          );
        })),
  ]);

  // ── PROJE EKLE ─────────────────────────────────────────────────
  void _projeEkleDialog(BuildContext context){
    final adCtrl=TextEditingController();
    final donemCtrl=TextEditingController(text:'2025-2026');
    final basCtrl=TextEditingController(text:'01.09.2025');
    final bitCtrl=TextEditingController(text:'30.06.2026');
    String tip='okul';
    String durum='aktif';
    bool sabahAktif=true;
    bool aksamAktif=true;
    final List<String> secilenGunler=['Pzt','Sal','Car','Per','Cum'];

    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        title:const Text('Yeni Proje',style:TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _tf(adCtrl,'Proje Adi *',Icons.folder_outlined),const SizedBox(height:10),
          _tf(donemCtrl,'Donem (2025-2026)',Icons.calendar_today_outlined),const SizedBox(height:10),
          Row(children:[
            Expanded(child:_tf(basCtrl,'Baslangic',Icons.date_range_outlined)),
            const SizedBox(width:10),
            Expanded(child:_tf(bitCtrl,'Bitis',Icons.date_range_outlined)),
          ]),
          const SizedBox(height:14),
          const Text('Proje Tipi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:8,runSpacing:8,children:[
            for(final t in [
              ('okul','Okul Servisi',Icons.school_outlined),
              ('kolej','Kolej Servisi',Icons.account_balance_outlined),
              ('personel','Personel Servisi',Icons.badge_outlined),
              ('vip','VIP Servis',Icons.star_outlined),
              ('tur','Tur Servisi',Icons.tour_outlined),
            ])
              GestureDetector(onTap:()=>setS(()=>tip=t.$1),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                      decoration:BoxDecoration(
                          color:tip==t.$1?_navy:Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:tip==t.$1?_navy:Colors.grey.shade300)),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        Icon(t.$3,size:14,color:tip==t.$1?Colors.white:Colors.grey),
                        const SizedBox(width:6),
                        Text(t.$2,style:TextStyle(fontSize:12,color:tip==t.$1?Colors.white:Colors.grey,
                            fontWeight:tip==t.$1?FontWeight.bold:FontWeight.normal)),
                      ]))),
          ]),
          const SizedBox(height:14),
          const Text('Calisma Gunleri',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:6,children:[
            for(final g in ['Pzt','Sal','Car','Per','Cum','Cmt','Paz'])
              GestureDetector(
                onTap:()=>setS((){
                  if(secilenGunler.contains(g)) secilenGunler.remove(g);
                  else secilenGunler.add(g);
                }),
                child:Container(
                  width:44,height:36,
                  decoration:BoxDecoration(
                      color:secilenGunler.contains(g)?_t:Colors.grey[100],
                      borderRadius:BorderRadius.circular(8),
                      border:Border.all(color:secilenGunler.contains(g)?_t:Colors.grey.shade300)),
                  child:Center(child:Text(g,style:TextStyle(fontSize:11,
                      color:secilenGunler.contains(g)?Colors.white:Colors.grey,
                      fontWeight:FontWeight.bold))),
                ),
              ),
          ]),
          const SizedBox(height:14),
          const Text('Servis Tipleri',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:GestureDetector(onTap:()=>setS(()=>sabahAktif=!sabahAktif),
                child:Container(padding:const EdgeInsets.symmetric(vertical:10),
                    decoration:BoxDecoration(
                        color:sabahAktif?Colors.orange.withValues(alpha:0.1):Colors.grey[50],
                        borderRadius:BorderRadius.circular(8),
                        border:Border.all(color:sabahAktif?Colors.orange:Colors.grey.shade300)),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(Icons.wb_sunny_outlined,size:16,color:sabahAktif?Colors.orange:Colors.grey),
                      const SizedBox(width:6),
                      Text('Sabah Servisi',style:TextStyle(fontSize:12,
                          color:sabahAktif?Colors.orange:Colors.grey,
                          fontWeight:sabahAktif?FontWeight.bold:FontWeight.normal)),
                    ])))),
            const SizedBox(width:10),
            Expanded(child:GestureDetector(onTap:()=>setS(()=>aksamAktif=!aksamAktif),
                child:Container(padding:const EdgeInsets.symmetric(vertical:10),
                    decoration:BoxDecoration(
                        color:aksamAktif?Colors.indigo.withValues(alpha:0.1):Colors.grey[50],
                        borderRadius:BorderRadius.circular(8),
                        border:Border.all(color:aksamAktif?Colors.indigo:Colors.grey.shade300)),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(Icons.nights_stay_outlined,size:16,color:aksamAktif?Colors.indigo:Colors.grey),
                      const SizedBox(width:6),
                      Text('Aksam Servisi',style:TextStyle(fontSize:12,
                          color:aksamAktif?Colors.indigo:Colors.grey,
                          fontWeight:aksamAktif?FontWeight.bold:FontWeight.normal)),
                    ])))),
          ]),
          const SizedBox(height:14),
          const Text('Proje Durumu',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(
            value:durum,
            decoration:InputDecoration(
                prefixIcon:const Icon(Icons.info_outline,color:_navy,size:18),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)),
            items:const[
              DropdownMenuItem(value:'taslak',child:Text('Taslak – Kurulum asamasinda')),
              DropdownMenuItem(value:'aktif',child:Text('Aktif – Sistem calisir')),
              DropdownMenuItem(value:'pasif',child:Text('Pasif – Yeni islem yapilamaz')),
            ],
            onChanged:(v)=>setS(()=>durum=v??'aktif'),
          ),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
            onPressed:() async{
              if(adCtrl.text.trim().isEmpty) return;
              // Duplicate kontrol - Firestore'dan kontrol et
              final yeniAd=adCtrl.text.trim().toLowerCase();
              final mevcut=await FirebaseFirestore.instance.collection('projects')
                  .where('firmaId',isEqualTo:widget.firmaId)
                  .where('aktif',isEqualTo:true).get();
              final dupVar=mevcut.docs.any((d)=>
              (d.data()['projeAd']??'').toString().trim().toLowerCase()==yeniAd);
              if(dupVar){
                if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content:Text('Bu isimde bir proje zaten mevcut!'),backgroundColor:Colors.orange,
                    behavior:SnackBarBehavior.floating));
                return;
              }
              await FirebaseFirestore.instance.collection('projects').add({
                'firmaId':widget.firmaId,
                'projeAd':adCtrl.text.trim(),
                'ad':adCtrl.text.trim(),
                'donem':donemCtrl.text.trim(),
                'tip':tip,
                'durum':durum,
                'aktif':durum=='aktif',
                'baslangicTarihi':basCtrl.text.trim(),
                'bitisTarihi':bitCtrl.text.trim(),
                'calismaGunleri':secilenGunler,
                'sabahServisAktif':sabahAktif,
                'aksamServisAktif':aksamAktif,
                'olusturmaTarihi':FieldValue.serverTimestamp(),
              });
              if(ctx.mounted) Navigator.pop(ctx);
            },
            icon:const Icon(Icons.add,size:16),
            label:const Text('Olustur'),
          ),
        ])));
  }

  // ── PROJE DUZENLE ───────────────────────────────────────────────
  void _projeDuzenleDialog(BuildContext context,String projeId,Map<String,dynamic> d){
    final adCtrl=TextEditingController(text:d['projeAd']??d['ad']??'');
    final donemCtrl=TextEditingController(text:d['donem']??'');
    final basCtrl=TextEditingController(text:d['baslangicTarihi']??'');
    final bitCtrl=TextEditingController(text:d['bitisTarihi']??'');
    String tip=d['tip']??'okul';
    String durum=d['durum']??(d['aktif']==true?'aktif':'arsiv');
    bool sabah=d['sabahServisAktif']??true;
    bool aksam=d['aksamServisAktif']??true;
    final gunler=List<String>.from(d['calismaGunleri']??['Pzt','Sal','Car','Per','Cum']);

    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        title:const Text('Projeyi Duzenle',style:TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:520,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _tf(adCtrl,'Proje Adi *',Icons.folder_outlined),const SizedBox(height:10),
          _tf(donemCtrl,'Donem',Icons.calendar_today_outlined),const SizedBox(height:10),
          Row(children:[
            Expanded(child:_tf(basCtrl,'Baslangic',Icons.date_range_outlined)),
            const SizedBox(width:10),
            Expanded(child:_tf(bitCtrl,'Bitis',Icons.date_range_outlined)),
          ]),const SizedBox(height:14),
          const Text('Proje Tipi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:8,runSpacing:8,children:[
            for(final t in [
              ('okul','Okul'),('kolej','Kolej'),('personel','Personel'),
              ('vip','VIP'),('tur','Tur'),
            ])
              GestureDetector(onTap:()=>setS(()=>tip=t.$1),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                      decoration:BoxDecoration(
                          color:tip==t.$1?_navy:Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:tip==t.$1?_navy:Colors.grey.shade300)),
                      child:Text(t.$2,style:TextStyle(fontSize:12,
                          color:tip==t.$1?Colors.white:Colors.grey,
                          fontWeight:tip==t.$1?FontWeight.bold:FontWeight.normal)))),
          ]),const SizedBox(height:14),
          const Text('Calisma Gunleri',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:6,children:[
            for(final g in ['Pzt','Sal','Car','Per','Cum','Cmt','Paz'])
              GestureDetector(
                onTap:()=>setS((){
                  if(gunler.contains(g)) gunler.remove(g);
                  else gunler.add(g);
                }),
                child:Container(width:44,height:36,
                    decoration:BoxDecoration(
                        color:gunler.contains(g)?_t:Colors.grey[100],
                        borderRadius:BorderRadius.circular(8),
                        border:Border.all(color:gunler.contains(g)?_t:Colors.grey.shade300)),
                    child:Center(child:Text(g,style:TextStyle(fontSize:11,
                        color:gunler.contains(g)?Colors.white:Colors.grey,
                        fontWeight:FontWeight.bold)))),
              ),
          ]),const SizedBox(height:14),
          Row(children:[
            Expanded(child:GestureDetector(onTap:()=>setS(()=>sabah=!sabah),
                child:Container(padding:const EdgeInsets.symmetric(vertical:10),
                    decoration:BoxDecoration(
                        color:sabah?Colors.orange.withValues(alpha:0.1):Colors.grey[50],
                        borderRadius:BorderRadius.circular(8),
                        border:Border.all(color:sabah?Colors.orange:Colors.grey.shade300)),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(Icons.wb_sunny_outlined,size:14,color:sabah?Colors.orange:Colors.grey),
                      const SizedBox(width:4),
                      Text('Sabah',style:TextStyle(fontSize:12,color:sabah?Colors.orange:Colors.grey,fontWeight:sabah?FontWeight.bold:FontWeight.normal)),
                    ])))),
            const SizedBox(width:10),
            Expanded(child:GestureDetector(onTap:()=>setS(()=>aksam=!aksam),
                child:Container(padding:const EdgeInsets.symmetric(vertical:10),
                    decoration:BoxDecoration(
                        color:aksam?Colors.indigo.withValues(alpha:0.1):Colors.grey[50],
                        borderRadius:BorderRadius.circular(8),
                        border:Border.all(color:aksam?Colors.indigo:Colors.grey.shade300)),
                    child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(Icons.nights_stay_outlined,size:14,color:aksam?Colors.indigo:Colors.grey),
                      const SizedBox(width:4),
                      Text('Aksam',style:TextStyle(fontSize:12,color:aksam?Colors.indigo:Colors.grey,fontWeight:aksam?FontWeight.bold:FontWeight.normal)),
                    ])))),
          ]),const SizedBox(height:14),
          DropdownButtonFormField<String>(
            value:durum,
            decoration:InputDecoration(
                labelText:'Durum',
                prefixIcon:const Icon(Icons.info_outline,color:_navy,size:18),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)),
            items:const[
              DropdownMenuItem(value:'taslak',child:Text('Taslak')),
              DropdownMenuItem(value:'aktif',child:Text('Aktif')),
              DropdownMenuItem(value:'pasif',child:Text('Pasif')),
              DropdownMenuItem(value:'arsiv',child:Text('Arsiv')),
            ],
            onChanged:(v)=>setS(()=>durum=v??'aktif'),
          ),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
            onPressed:() async{
              if(adCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('projects').doc(projeId).update({
                'projeAd':adCtrl.text.trim(),'ad':adCtrl.text.trim(),
                'donem':donemCtrl.text.trim(),'tip':tip,'durum':durum,
                'aktif':durum=='aktif',
                'baslangicTarihi':basCtrl.text.trim(),'bitisTarihi':bitCtrl.text.trim(),
                'calismaGunleri':gunler,'sabahServisAktif':sabah,'aksamServisAktif':aksam,
                'guncellenmeTarihi':FieldValue.serverTimestamp(),
              });
              if(ctx.mounted) Navigator.pop(ctx);
            },
            icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet'),
          ),
        ])));
  }

  // ── PROJE AYARLAR ──────────────────────────────────────────────
  void _projeAyarlarDialog(BuildContext context,String projeId,Map<String,dynamic> d){
    final sabahBasCtrl=TextEditingController(text:d['sabahBaslangic']??'07:00');
    final sabahBitCtrl=TextEditingController(text:d['sabahBitis']??'08:30');
    final aksamBasCtrl=TextEditingController(text:d['aksamBaslangic']??'16:00');
    final aksamBitCtrl=TextEditingController(text:d['aksamBitis']??'17:30');
    String bildirimMesafe=d['bildirimMesafe']??'500';
    int konumSure=d['konumGuncellemeSure']??30;
    bool sadeceSaatinde=d['sadeceSaatinde']??false;

    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        title:Row(children:[
          const Icon(Icons.settings_outlined,color:_navy),
          const SizedBox(width:10),
          Text((d['projeAd']??d['ad']??'')+' – Ayarlar',
              style:const TextStyle(color:_navy,fontWeight:FontWeight.bold,fontSize:16)),
        ]),
        content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          // Servis saatleri
          Container(padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.05),borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:Colors.orange.withValues(alpha:0.2))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Row(children:[Icon(Icons.wb_sunny_outlined,color:Colors.orange,size:16),SizedBox(width:6),
                  Text('Sabah Servisi',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.orange))]),
                const SizedBox(height:10),
                Row(children:[
                  Expanded(child:_tf(sabahBasCtrl,'Baslangic',Icons.access_time_outlined)),
                  const SizedBox(width:10),
                  Expanded(child:_tf(sabahBitCtrl,'Bitis',Icons.access_time_outlined)),
                ]),
              ])),
          const SizedBox(height:10),
          Container(padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:Colors.indigo.withValues(alpha:0.05),borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:Colors.indigo.withValues(alpha:0.2))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Row(children:[Icon(Icons.nights_stay_outlined,color:Colors.indigo,size:16),SizedBox(width:6),
                  Text('Aksam Servisi',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.indigo))]),
                const SizedBox(height:10),
                Row(children:[
                  Expanded(child:_tf(aksamBasCtrl,'Baslangic',Icons.access_time_outlined)),
                  const SizedBox(width:10),
                  Expanded(child:_tf(aksamBitCtrl,'Bitis',Icons.access_time_outlined)),
                ]),
              ])),
          const SizedBox(height:14),
          // Bildirim mesafesi
          const Text('Yaklasma Bildirimi Mesafesi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:8,children:[
            for(final m in [('500','500 metre'),('700','700 metre'),('1000','1 km')])
              GestureDetector(onTap:()=>setS(()=>bildirimMesafe=m.$1),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
                      decoration:BoxDecoration(
                          color:bildirimMesafe==m.$1?_navy:Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:bildirimMesafe==m.$1?_navy:Colors.grey.shade300)),
                      child:Text(m.$2,style:TextStyle(fontSize:12,
                          color:bildirimMesafe==m.$1?Colors.white:Colors.grey,
                          fontWeight:bildirimMesafe==m.$1?FontWeight.bold:FontWeight.normal)))),
          ]),
          const SizedBox(height:14),
          // Konum guncelleme suresi
          const Text('Konum Guncelleme Suresi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          Wrap(spacing:8,children:[
            for(final s in [(5,'5 sn'),(10,'10 sn'),(30,'30 sn')])
              GestureDetector(onTap:()=>setS(()=>konumSure=s.$1),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
                      decoration:BoxDecoration(
                          color:konumSure==s.$1?_navy:Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:konumSure==s.$1?_navy:Colors.grey.shade300)),
                      child:Text(s.$2,style:TextStyle(fontSize:12,
                          color:konumSure==s.$1?Colors.white:Colors.grey,
                          fontWeight:konumSure==s.$1?FontWeight.bold:FontWeight.normal)))),
          ]),
          const SizedBox(height:14),
          // Sadece servis saatinde
          Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:Colors.grey.shade200)),
              child:Row(children:[
                const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('Canli Takip',style:TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
                  Text('Sadece servis saatinde acik',style:TextStyle(fontSize:11,color:Colors.grey)),
                ])),
                Switch(
                  value:sadeceSaatinde,
                  activeColor:_t,
                  onChanged:(v)=>setS(()=>sadeceSaatinde=v),
                ),
              ])),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
            onPressed:() async{
              await FirebaseFirestore.instance.collection('projects').doc(projeId).update({
                'sabahBaslangic':sabahBasCtrl.text.trim(),
                'sabahBitis':sabahBitCtrl.text.trim(),
                'aksamBaslangic':aksamBasCtrl.text.trim(),
                'aksamBitis':aksamBitCtrl.text.trim(),
                'bildirimMesafe':bildirimMesafe,
                'konumGuncellemeSure':konumSure,
                'sadeceSaatinde':sadeceSaatinde,
                'ayarGuncelleme':FieldValue.serverTimestamp(),
              });
              if(ctx.mounted){Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:Text('Ayarlar kaydedildi'),backgroundColor:Colors.green,
                  behavior:SnackBarBehavior.floating));}
            },
            icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet'),
          ),
        ])));
  }

  // ── PROJE KOPYALA ───────────────────────────────────────────────
  Future<void> _projeKopyala(BuildContext context,String projeId,Map<String,dynamic> d) async{
    final adCtrl=TextEditingController(text:(d['projeAd']??d['ad']??'')+' (2027)');
    final donemCtrl=TextEditingController(text:'2026-2027');
    bool kopyalaAraclar=true;
    bool kopyalaSoforler=true;
    bool kopyalaFiyatlar=true;

    final onay=await showDialog<bool>(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
        title:const Text('Proje Kopyala',style:TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _tf(adCtrl,'Yeni Proje Adi',Icons.folder_outlined),
          const SizedBox(height:10),
          _tf(donemCtrl,'Donem',Icons.calendar_today_outlined),
          const SizedBox(height:14),
          const Text('Kopyalanacaklar',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
          const SizedBox(height:8),
          CheckboxListTile(dense:true,value:kopyalaAraclar,activeColor:_t,
              title:const Text('Araclar',style:TextStyle(fontSize:13)),
              onChanged:(v)=>setS(()=>kopyalaAraclar=v??true)),
          CheckboxListTile(dense:true,value:kopyalaSoforler,activeColor:_t,
              title:const Text('Soforler',style:TextStyle(fontSize:13)),
              onChanged:(v)=>setS(()=>kopyalaSoforler=v??true)),
          CheckboxListTile(dense:true,value:kopyalaFiyatlar,activeColor:_t,
              title:const Text('Fiyatlandirma',style:TextStyle(fontSize:13)),
              onChanged:(v)=>setS(()=>kopyalaFiyatlar=v??true)),
          Container(margin:const EdgeInsets.only(top:8),padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8)),
              child:const Row(children:[
                Icon(Icons.info_outline,color:Colors.orange,size:14),SizedBox(width:6),
                Expanded(child:Text('Ogrenci kayitlari, odemeler ve raporlar kopyalanmaz.',
                    style:TextStyle(fontSize:11,color:Colors.orange))),
              ])),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Iptal')),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
            onPressed:()=>Navigator.pop(ctx,true),
            icon:const Icon(Icons.copy_outlined,size:16),label:const Text('Kopyala'),
          ),
        ])));

    if(onay!=true) return;

    try{
      // Yeni proje olustur
      final yeniRef=await FirebaseFirestore.instance.collection('projects').add({
        ...d,
        'projeAd':adCtrl.text.trim(),
        'ad':adCtrl.text.trim(),
        'donem':donemCtrl.text.trim(),
        'durum':'taslak',
        'aktif':false,
        'olusturmaTarihi':FieldValue.serverTimestamp(),
        'kopyalandiFrom':projeId,
      });

      // Araclari kopyala
      if(kopyalaAraclar){
        final araclar=await FirebaseFirestore.instance.collection('vehicles')
            .where('firmaId',isEqualTo:widget.firmaId).get();
        for(final a in araclar.docs){
          final ad=a.data();
          await FirebaseFirestore.instance.collection('vehicles').add({
            ...ad,'projeId':yeniRef.id,
            'olusturmaTarihi':FieldValue.serverTimestamp(),
          });
        }
      }

      // Soforleri kopyala (projeye ekle)
      if(kopyalaSoforler){
        final soforler=await FirebaseFirestore.instance.collection('drivers')
            .where('firmaId',isEqualTo:widget.firmaId)
            .where('projeId',isEqualTo:projeId).get();
        for(final s in soforler.docs){
          final sd=s.data();
          await FirebaseFirestore.instance.collection('drivers').add({
            ...sd,'projeId':yeniRef.id,
            'servisAktif':false,
            'olusturmaTarihi':FieldValue.serverTimestamp(),
          });
        }
      }

      // Fiyatlari kopyala
      if(kopyalaFiyatlar){
        final fiyatlar=await FirebaseFirestore.instance.collection('fiyatlar')
            .where('firmaId',isEqualTo:widget.firmaId).get();
        for(final f in fiyatlar.docs){
          final fd=f.data();
          await FirebaseFirestore.instance.collection('fiyatlar').add({
            ...fd,'projeId':yeniRef.id,
            'olusturmaTarihi':FieldValue.serverTimestamp(),
          });
        }
      }

      if(context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:Text('Proje kopyalandi! Taslak olarak olusturuldu.'),
            backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));
    }catch(e){
      if(context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:Text('Hata: '+e.toString()),
            backgroundColor:Colors.red,behavior:SnackBarBehavior.floating));
    }
  }

  // ── PROJE ARSIVLE ───────────────────────────────────────────────
  Future<void> _projeArsivle(BuildContext context,String projeId,Map<String,dynamic> d) async{
    final onay=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
        title:const Text('Projeyi Arsivle'),
        content:Text((d['projeAd']??d['ad']??'')+' arsive tasinacak. Devam?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
          ElevatedButton(
              style:ElevatedButton.styleFrom(backgroundColor:Colors.grey),
              onPressed:()=>Navigator.pop(_,true),
              child:const Text('Arsivle',style:TextStyle(color:Colors.white))),
        ]));
    if(onay==true){
      await FirebaseFirestore.instance.collection('projects').doc(projeId).update({
        'durum':'arsiv','aktif':false,'arsivTarihi':FieldValue.serverTimestamp(),
      });
    }
  }

  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:_navy,size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)));
}

// ── PROJE KART WIDGET ───────────────────────────────────────────
class _ProjeKarti extends StatelessWidget{
  final String projeId,firmaId;
  final Map<String,dynamic> data;
  final VoidCallback onSec,onDuzenle,onAyarlar,onKopyala,onArsivle;
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  const _ProjeKarti({required this.projeId,required this.firmaId,required this.data,
    required this.onSec,required this.onDuzenle,required this.onAyarlar,
    required this.onKopyala,required this.onArsivle});

  @override Widget build(BuildContext context){
    final tip=data['tip']??'okul';
    final durum=data['durum']??(data['aktif']==true?'aktif':'arsiv');
    final r=tip=='kolej'?Colors.purple:tip=='personel'?Colors.teal:
    tip=='vip'?Colors.amber:tip=='tur'?Colors.green:_navy;
    final durumRenk=durum=='aktif'?Colors.green:durum=='pasif'?Colors.orange:
    durum=='taslak'?Colors.blue:Colors.grey;

    return Container(
      margin:const EdgeInsets.only(bottom:14),
      decoration:BoxDecoration(
          color:Colors.white,
          borderRadius:BorderRadius.circular(16),
          border:Border.all(color:r.withValues(alpha:0.15)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:8)]),
      child:Column(children:[
        // Header
        GestureDetector(
          onTap:onSec,
          child:Container(
            padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(
                color:r.withValues(alpha:0.04),
                borderRadius:const BorderRadius.vertical(top:Radius.circular(16))),
            child:Row(children:[
              Container(padding:const EdgeInsets.all(10),
                  decoration:BoxDecoration(color:r.withValues(alpha:0.12),borderRadius:BorderRadius.circular(10)),
                  child:Icon(
                      tip=='kolej'?Icons.account_balance_outlined:
                      tip=='personel'?Icons.badge_outlined:
                      tip=='vip'?Icons.star_outlined:
                      tip=='tur'?Icons.tour_outlined:Icons.school_outlined,
                      color:r,size:22)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(data['projeAd']??data['ad']??'',
                    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
                Text((data['donem']??'')+' • '+(data['baslangicTarihi']??''),
                    style:TextStyle(fontSize:11,color:Colors.grey[500])),
              ])),
              // Durum badge
              Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                  decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                  child:Text(durum.toUpperCase(),style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:durumRenk))),
            ]),
          ),
        ),
        // Istatistikler
        FutureBuilder<Map<String,int>>(
          future:_istatistikCek(),
          builder:(_,snap){
            final ist=snap.data??{};
            return Padding(
              padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
              child:Row(children:[
                _istatKarti(ist['ogrenci']??0,'Ogrenci',Icons.school_outlined,Colors.blue),
                _istatKarti(ist['sofor']??0,'Sofor',Icons.person_outlined,_navy),
                _istatKarti(ist['arac']??0,'Arac',Icons.directions_car_outlined,Colors.teal),
                _istatKarti(ist['servis']??0,'Servis',Icons.directions_bus_outlined,Colors.orange),
              ]),
            );
          },
        ),
        // Calisma gunleri
        if((data['calismaGunleri'] as List?)?.isNotEmpty==true)
          Padding(
            padding:const EdgeInsets.only(left:16,right:16,bottom:10),
            child:Row(children:[
              const Icon(Icons.calendar_today_outlined,size:12,color:Colors.grey),
              const SizedBox(width:6),
              Wrap(spacing:4,children:(data['calismaGunleri'] as List).map((g)=>
                  Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                      decoration:BoxDecoration(color:_t.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
                      child:Text(g.toString(),style:const TextStyle(fontSize:10,color:_t,fontWeight:FontWeight.bold)))
              ).toList()),
              const Spacer(),
              if(data['sabahServisAktif']==true)
                const Icon(Icons.wb_sunny_outlined,size:14,color:Colors.orange),
              if(data['aksamServisAktif']==true) ...const[
                SizedBox(width:6),Icon(Icons.nights_stay_outlined,size:14,color:Colors.indigo),
              ],
            ]),
          ),
        // Aksiyonlar
        Container(
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
          decoration:BoxDecoration(
              color:Colors.grey[50],
              borderRadius:const BorderRadius.vertical(bottom:Radius.circular(16))),
          child:Row(children:[
            // Sec
            Expanded(child:ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:r,foregroundColor:Colors.white,
                  padding:const EdgeInsets.symmetric(vertical:8),
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:onSec,
              icon:const Icon(Icons.check_circle_outline,size:14),
              label:const Text('Sec',style:TextStyle(fontSize:12)),
            )),
            const SizedBox(width:6),
            // Duzenle
            IconButton(tooltip:'Duzenle',
                onPressed:onDuzenle,
                icon:const Icon(Icons.edit_outlined,color:_navy,size:18)),
            // Ayarlar
            IconButton(tooltip:'Ayarlar',
                onPressed:onAyarlar,
                icon:const Icon(Icons.settings_outlined,color:Colors.grey,size:18)),
            // Kopyala
            IconButton(tooltip:'Kopyala',
                onPressed:onKopyala,
                icon:const Icon(Icons.copy_outlined,color:Colors.teal,size:18)),
            // Arsivle
            if(durum!='arsiv')
              IconButton(tooltip:'Arsivle',
                  onPressed:onArsivle,
                  icon:const Icon(Icons.archive_outlined,color:Colors.grey,size:18)),
          ]),
        ),
      ]),
    );
  }

  Widget _istatKarti(int sayi,String etiket,IconData ikon,Color renk)=>Expanded(child:Column(children:[
    Text(sayi.toString(),style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:renk)),
    const SizedBox(height:2),
    Text(etiket,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));

  Future<Map<String,int>> _istatistikCek() async{
    try{
      final results=await Future.wait([
        FirebaseFirestore.instance.collection('students')
            .where('firmaId',isEqualTo:firmaId).where('projeId',isEqualTo:projeId)
            .where('aktif',isEqualTo:true).count().get(),
        FirebaseFirestore.instance.collection('drivers')
            .where('firmaId',isEqualTo:firmaId).where('projeId',isEqualTo:projeId).count().get(),
        FirebaseFirestore.instance.collection('vehicles')
            .where('firmaId',isEqualTo:firmaId).where('projeId',isEqualTo:projeId).count().get(),
        FirebaseFirestore.instance.collection('services')
            .where('firmaId',isEqualTo:firmaId).where('projeId',isEqualTo:projeId).count().get(),
      ]);
      return{
        'ogrenci':results[0].count??0,
        'sofor':results[1].count??0,
        'arac':results[2].count??0,
        'servis':results[3].count??0,
      };
    }catch(_){return{};}
  }
}


//  SERVISLER
// ─────────────────────────────────────────────────────────────────
//  SERVISLER SEKMESI – Bolum 4 Tam Surum
// ─────────────────────────────────────────────────────────────────
class _ServislerSekme extends StatefulWidget{
  final String firmaId,projeId;
  const _ServislerSekme({required this.firmaId,required this.projeId});
  @override State<_ServislerSekme> createState()=>_ServislerSekmeState();
}
class _ServislerSekmeState extends State<_ServislerSekme>
    with SingleTickerProviderStateMixin{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  List<Map<String,dynamic>> _soforler=[],_araclar=[];
  late TabController _tab;
  String _aramaMetni='';
  final _aramaCtrl=TextEditingController();

  // Servis renkleri
  static const _renkler=[
    Color(0xFF1a3a6b), Color(0xFFE53935), Color(0xFF43A047),
    Color(0xFFFB8C00), Color(0xFF8E24AA), Color(0xFF00ACC1),
    Color(0xFFF4511E), Color(0xFF3949AB),
  ];
  static const _renkAdlari=['Lacivert','Kirmizi','Yesil','Turuncu','Mor','Camgobegi','Mercan','Indigo'];

  @override void initState(){
    super.initState();
    _tab=TabController(length:3,vsync:this);
    _yukle();
  }
  @override void dispose(){_tab.dispose();_aramaCtrl.dispose();super.dispose();}

  Future<void> _yukle() async{
    final sS=await FirebaseFirestore.instance.collection('drivers')
        .where('firmaId',isEqualTo:widget.firmaId).get();
    final aS=await FirebaseFirestore.instance.collection('vehicles')
        .where('firmaId',isEqualTo:widget.firmaId).get();
    if(mounted)setState((){
      _soforler=sS.docs.map((d)=>{'id':d.id,...d.data()}).toList();
      _araclar=aS.docs.map((d)=>{'id':d.id,...d.data()}).toList();
    });
  }

  @override Widget build(BuildContext context)=>Column(children:[
    // Tabs
    Container(color:Colors.white,child:TabBar(
        controller:_tab,labelColor:_navy,unselectedLabelColor:Colors.grey,
        indicatorColor:_t,isScrollable:true,tabAlignment:TabAlignment.start,
        tabs:const[
          Tab(icon:Icon(Icons.directions_bus_outlined,size:16),text:'Servisler'),
          Tab(icon:Icon(Icons.people_outline,size:16),text:'Doluluk'),
          Tab(icon:Icon(Icons.bar_chart_outlined,size:16),text:'Raporlar'),
        ])),
    // Header
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(
              controller:_aramaCtrl,
              onChanged:(v)=>setState(()=>_aramaMetni=v.toLowerCase()),
              decoration:InputDecoration(
                  hintText:'Servis ara...',
                  prefixIcon:const Icon(Icons.search,size:18,color:Colors.grey),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
          const SizedBox(width:10),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
            onPressed:_ekle,
            icon:const Icon(Icons.add,size:16),label:const Text('Servis Ekle'),
          ),
        ])),
    Expanded(child:TabBarView(controller:_tab,children:[
      // Tab 1: Servis Listesi
      StreamBuilder<QuerySnapshot>(
          stream:(){
            var q=FirebaseFirestore.instance.collection('services')
                .where('firmaId',isEqualTo:widget.firmaId);
            if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
            return q.snapshots();
          }(),
          builder:(_,snap){
            var docs=snap.data?.docs??[];
            if(_aramaMetni.isNotEmpty){
              docs=docs.where((d){
                final data=d.data() as Map<String,dynamic>;
                return (data['ad']??'').toString().toLowerCase().contains(_aramaMetni)
                    || (data['soforAd']??'').toString().toLowerCase().contains(_aramaMetni)
                    || (data['aracPlaka']??'').toString().toLowerCase().contains(_aramaMetni);
              }).toList();
            }
            if(docs.isEmpty)return _bos('Servis bulunamadi','Servis ekleyin.',Icons.directions_bus_outlined);
            return ListView.builder(
                padding:const EdgeInsets.all(16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final doc=docs[i];
                  final d=doc.data() as Map<String,dynamic>;
                  final aktif=d['aktif']==true;
                  final arsiv=d['arsiv']==true;
                  final ad=(d['ad']??'').toString();
                  final soforAd=(d['soforAd']??'').toString();
                  final aracPlaka=(d['aracPlaka']??'').toString();
                  final sabah=(d['sabahSaati']??'').toString();
                  final aksam=(d['aksamSaati']??'').toString();
                  final kap=(d['kapasite']??17) as int;
                  final ogrSay=(d['ogrenciSayisi']??0) as int;
                  final renkIdx=(d['renkIndex']??0) as int;
                  final servisRenk=_renkler[renkIdx.clamp(0,_renkler.length-1)];
                  final doluluk=kap>0?(ogrSay/kap).clamp(0.0,1.0):0.0;
                  final dolulukRenk=doluluk>0.85?Colors.red:doluluk>0.6?Colors.orange:Colors.green;

                  return Container(
                    margin:const EdgeInsets.only(bottom:12),
                    decoration:BoxDecoration(
                        color:Colors.white,
                        borderRadius:BorderRadius.circular(16),
                        border:Border(left:BorderSide(color:servisRenk,width:4)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
                    child:Column(children:[
                      // Ana bilgi satiri
                      Padding(
                        padding:const EdgeInsets.all(14),
                        child:Row(children:[
                          Container(
                              width:44,height:44,
                              decoration:BoxDecoration(color:servisRenk.withValues(alpha:0.12),borderRadius:BorderRadius.circular(12)),
                              child:Icon(Icons.directions_bus_outlined,color:servisRenk,size:22)),
                          const SizedBox(width:12),
                          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Row(children:[
                              Text(ad,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                              const SizedBox(width:8),
                              if(arsiv)
                                Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                                    decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
                                    child:const Text('ARSIV',style:TextStyle(fontSize:9,color:Colors.grey,fontWeight:FontWeight.bold))),
                            ]),
                            const SizedBox(height:4),
                            Wrap(spacing:6,runSpacing:4,children:[
                              if(soforAd.isNotEmpty)_ch(soforAd,Colors.blue),
                              if(aracPlaka.isNotEmpty)_ch(aracPlaka,Colors.grey),
                              if(sabah.isNotEmpty)_ch('S:'+sabah,Colors.orange),
                              if(aksam.isNotEmpty)_ch('A:'+aksam,Colors.indigo),
                            ]),
                          ])),
                          // Sag taraf: durum + aksiyon
                          Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                            Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                decoration:BoxDecoration(
                                    color:(aktif?Colors.green:Colors.grey).withValues(alpha:0.1),
                                    borderRadius:BorderRadius.circular(6)),
                                child:Text(aktif?'Aktif':'Pasif',
                                    style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,
                                        color:aktif?Colors.green:Colors.grey))),
                            const SizedBox(height:6),
                            Row(children:[
                              // Baslat/Durdur
                              _aksBtn(
                                  aktif?Icons.stop_circle_outlined:Icons.play_circle_outlined,
                                  aktif?Colors.orange:Colors.green,
                                      ()async{
                                    await FirebaseFirestore.instance.collection('services')
                                        .doc(doc.id).update({'aktif':!aktif,'guncelleme':FieldValue.serverTimestamp()});
                                  }),
                              const SizedBox(width:4),
                              // Duzenle
                              _aksBtn(Icons.edit_outlined,_navy,
                                      ()=>_ServisDuzenleDialog.goster(context,doc.id,d,widget.firmaId)),
                              const SizedBox(width:4),
                              // Ogrenci ata
                              _aksBtn(Icons.person_add_outlined,Colors.teal,
                                      ()=>_ogrenciAtaDialog(context,doc.id,ad)),
                              const SizedBox(width:4),
                              // Arsivle/Arsivden cikar
                              _aksBtn(arsiv?Icons.unarchive_outlined:Icons.archive_outlined,
                                  Colors.grey,()=>_arsivle(doc.id,arsiv)),
                            ]),
                          ]),
                        ]),
                      ),
                      // Doluluk cubugu
                      Padding(
                        padding:const EdgeInsets.only(left:14,right:14,bottom:12),
                        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Row(children:[
                            Text(ogrSay.toString()+'/'+kap.toString()+' ogrenci',
                                style:TextStyle(fontSize:11,color:Colors.grey[600])),
                            const Spacer(),
                            Text((doluluk*100).round().toString()+'%',
                                style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:dolulukRenk)),
                          ]),
                          const SizedBox(height:4),
                          ClipRRect(
                              borderRadius:BorderRadius.circular(4),
                              child:LinearProgressIndicator(
                                  value:doluluk,minHeight:6,
                                  backgroundColor:Colors.grey.withValues(alpha:0.15),
                                  valueColor:AlwaysStoppedAnimation<Color>(dolulukRenk))),
                        ]),
                      ),
                    ]),
                  );
                });
          }),
      // Tab 2: Doluluk Ozeti
      StreamBuilder<QuerySnapshot>(
          stream:(){
            var q=FirebaseFirestore.instance.collection('services')
                .where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true);
            if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
            return q.snapshots();
          }(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Aktif servis yok','',Icons.directions_bus_outlined);
            int toplamKap=0,toplamOgr=0;
            for(final doc in docs){
              final d=doc.data() as Map<String,dynamic>;
              toplamKap+=(d['kapasite']??17) as int;
              toplamOgr+=(d['ogrenciSayisi']??0) as int;
            }
            return Column(children:[
              // Genel ozet
              Container(margin:const EdgeInsets.all(16),padding:const EdgeInsets.all(16),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                  child:Row(children:[
                    _dolulukKarti('Toplam Koltuk',toplamKap.toString(),_navy),
                    _dolulukKarti('Dolu Koltuk',toplamOgr.toString(),Colors.orange),
                    _dolulukKarti('Bos Koltuk',(toplamKap-toplamOgr).toString(),Colors.green),
                    _dolulukKarti('Doluluk',toplamKap>0?((toplamOgr/toplamKap)*100).round().toString()+'%':'-',Colors.blue),
                  ])),
              Expanded(child:ListView.builder(
                  padding:const EdgeInsets.symmetric(horizontal:16),
                  itemCount:docs.length,
                  itemBuilder:(_,i){
                    final d=docs[i].data() as Map<String,dynamic>;
                    final kap=(d['kapasite']??17) as int;
                    final ogr=(d['ogrenciSayisi']??0) as int;
                    final dol=kap>0?(ogr/kap).clamp(0.0,1.0):0.0;
                    final renkIdx=(d['renkIndex']??0) as int;
                    final sRenk=_renkler[renkIdx.clamp(0,_renkler.length-1)];
                    return Container(margin:const EdgeInsets.only(bottom:8),
                        padding:const EdgeInsets.all(14),
                        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                            border:Border(left:BorderSide(color:sRenk,width:3))),
                        child:Row(children:[
                          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                            const SizedBox(height:6),
                            ClipRRect(borderRadius:BorderRadius.circular(4),
                                child:LinearProgressIndicator(value:dol,minHeight:8,
                                    backgroundColor:Colors.grey.withValues(alpha:0.1),
                                    valueColor:AlwaysStoppedAnimation<Color>(
                                        dol>0.85?Colors.red:dol>0.6?Colors.orange:Colors.green))),
                          ])),
                          const SizedBox(width:12),
                          Text(ogr.toString()+'/'+kap.toString(),
                              style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
                        ]));
                  })),
            ]);
          }),
      // Tab 3: Raporlar
      StreamBuilder<QuerySnapshot>(
          stream:(){
            var q=FirebaseFirestore.instance.collection('servis_raporlari')
                .where('firmaId',isEqualTo:widget.firmaId);
            if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
            return q.orderBy('tarih',descending:true).limit(50).snapshots();
          }(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Servis raporu yok','Servis tamamlandiginda rapor olusur.',Icons.bar_chart_outlined);
            return ListView.builder(
                padding:const EdgeInsets.all(16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final ts=d['tarih'];
                  String tarihStr='';
                  if(ts is Timestamp){final dt=ts.toDate();tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString()+' '+dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                  return Container(margin:const EdgeInsets.only(bottom:8),
                      padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                      child:Row(children:[
                        Container(padding:const EdgeInsets.all(8),
                            decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8)),
                            child:const Icon(Icons.assessment_outlined,color:_navy,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(tarihStr,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                          const SizedBox(height:4),
                          Wrap(spacing:8,children:[
                            _raporChip('Toplam:'+(d['toplamOgrenci']??0).toString(),Colors.blue),
                            _raporChip('Bindi:'+(d['bindiler']??0).toString(),Colors.green),
                            _raporChip('Gelmedi:'+(d['gelmediler']??0).toString(),Colors.red),
                          ]),
                        ])),
                        if((d['tamamlandi']??false)==true)
                          const Icon(Icons.check_circle_outline,color:Colors.green,size:18),
                      ]));
                });
          }),
    ])),
  ]);

  // ── SERVIS EKLE ─────────────────────────────────────────────────
  void _ekle(){
    final adC=TextEditingController();
    final kapC=TextEditingController(text:'17');
    final sabC=TextEditingController(text:'07:30');
    final aksC=TextEditingController(text:'16:30');
    String tip='sabah';
    String? soforId,aracId;
    int renkIdx=0;

    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Yeni Servis',style:TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          _tf(adC,'Servis Adi *',Icons.directions_bus_outlined),const SizedBox(height:10),
          Row(children:[
            Expanded(child:_tf(kapC,'Kapasite',Icons.people_outline)),
            const SizedBox(width:10),
            Expanded(child:DropdownButtonFormField<String?>(
                value:soforId,
                decoration:const InputDecoration(labelText:'Sofor',prefixIcon:Icon(Icons.person_outlined,size:18),
                    border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
                items:[const DropdownMenuItem(value:null,child:Text('Sec...')),
                  ..._soforler.map((s)=>DropdownMenuItem(value:s['id'] as String,child:Text(s['ad']??'')))],
                onChanged:(v)=>setS(()=>soforId=v))),
          ]),
          const SizedBox(height:10),
          DropdownButtonFormField<String?>(
              value:aracId,
              decoration:const InputDecoration(labelText:'Arac',prefixIcon:Icon(Icons.directions_car_outlined,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(10))),isDense:true),
              items:[const DropdownMenuItem(value:null,child:Text('Sec...')),
                ..._araclar.map((a)=>DropdownMenuItem(value:a['id'] as String,
                    child:Text((a['plaka']??'')+(a['marka']!=null?' – '+a['marka']:''))))],
              onChanged:(v)=>setS(()=>aracId=v)),
          const SizedBox(height:10),
          Row(children:[
            Expanded(child:_tf(sabC,'Sabah Saati',Icons.wb_sunny_outlined)),
            const SizedBox(width:10),
            Expanded(child:_tf(aksC,'Aksam Saati',Icons.nights_stay_outlined)),
          ]),
          const SizedBox(height:10),
          // Servis tipi
          Row(children:[
            for(final t in [('sabah','Sabah'),('aksam','Aksam'),('her_iki','Her Ikisi')])
              Expanded(child:GestureDetector(
                  onTap:()=>setS(()=>tip=t.$1),
                  child:Container(margin:const EdgeInsets.only(right:6),
                      padding:const EdgeInsets.symmetric(vertical:10),
                      decoration:BoxDecoration(
                          color:tip==t.$1?_navy:Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:Border.all(color:tip==t.$1?_navy:Colors.grey.shade300)),
                      child:Center(child:Text(t.$2,style:TextStyle(fontSize:11,
                          color:tip==t.$1?Colors.white:Colors.grey,
                          fontWeight:tip==t.$1?FontWeight.bold:FontWeight.normal)))))),
          ]),
          const SizedBox(height:12),
          // Servis rengi
          const Align(alignment:Alignment.centerLeft,
              child:Text('Servis Rengi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13))),
          const SizedBox(height:8),
          Wrap(spacing:8,children:[
            for(int ri=0;ri<_renkler.length;ri++)
              GestureDetector(
                  onTap:()=>setS(()=>renkIdx=ri),
                  child:Container(
                      width:32,height:32,
                      decoration:BoxDecoration(
                          color:_renkler[ri],
                          shape:BoxShape.circle,
                          border:Border.all(color:renkIdx==ri?Colors.white:Colors.transparent,width:3),
                          boxShadow:renkIdx==ri?[BoxShadow(color:_renkler[ri].withValues(alpha:0.5),blurRadius:6)]:null),
                      child:renkIdx==ri?const Icon(Icons.check,color:Colors.white,size:16):null)),
          ]),
          const SizedBox(height:6),
          Align(alignment:Alignment.centerLeft,
              child:Text(_renkAdlari[renkIdx],style:TextStyle(fontSize:11,color:_renkler[renkIdx],fontWeight:FontWeight.w600))),
        ]))),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(adC.text.trim().isEmpty)return;
                final sofor=_soforler.firstWhere((s)=>s['id']==soforId,orElse:()=>{});
                final arac=_araclar.firstWhere((a)=>a['id']==aracId,orElse:()=>{});
                await FirebaseFirestore.instance.collection('services').add({
                  'firmaId':widget.firmaId,'projeId':widget.projeId,
                  'ad':adC.text.trim(),
                  'kapasite':int.tryParse(kapC.text)??17,
                  'tip':tip,
                  'sabahSaati':sabC.text,'aksamSaati':aksC.text,
                  'soforId':soforId??'','soforAd':sofor['ad']??'',
                  'aracId':aracId??'','aracPlaka':arac['plaka']??'',
                  'aracMarka':arac['marka']??'','aracModel':arac['model']??'',
                  'renkIndex':renkIdx,
                  'aktif':true,'arsiv':false,
                  'ogrenciSayisi':0,
                  // 360 kamera altyapisi
                  'kameraOn':false,'kameraArkа':false,
                  'kameraIc':false,'kameraYanL':false,'kameraYanR':false,
                  'olusturmaTarihi':FieldValue.serverTimestamp(),
                });
                if(ctx.mounted)Navigator.pop(ctx);
              },
              icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ])));
  }

  // ── OGRENCI ATA DIALOG ──────────────────────────────────────────
  void _ogrenciAtaDialog(BuildContext context,String servisId,String servisAd){
    showDialog(context:context,builder:(_)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:Row(children:[
          const Icon(Icons.people_outline,color:_navy),
          const SizedBox(width:8),
          Expanded(child:Text(servisAd+' – Ogrenci Atama',
              style:const TextStyle(color:_navy,fontWeight:FontWeight.bold,fontSize:14))),
          IconButton(icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(_),
              padding:EdgeInsets.zero,constraints:const BoxConstraints()),
        ]),
        contentPadding:EdgeInsets.zero,
        content:SizedBox(
          width:520,height:500,
          child:Column(children:[
            // Atanmis ogrenciler
            Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),color:Colors.green.withValues(alpha:0.05),
                child:const Row(children:[
                  Icon(Icons.check_circle_outline,color:Colors.green,size:14),SizedBox(width:6),
                  Text('Bu servisteki ogrenciler',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Colors.green)),
                ])),
            Expanded(child:StreamBuilder<QuerySnapshot>(
                stream:FirebaseFirestore.instance.collection('students')
                    .where('firmaId',isEqualTo:widget.firmaId)
                    .where('servisId',isEqualTo:servisId).snapshots(),
                builder:(_,snap){
                  final docs=snap.data?.docs??[];
                  if(docs.isEmpty)return const Center(child:Text('Bu serviste ogrenci yok',style:TextStyle(color:Colors.grey)));
                  return ListView.builder(
                      padding:const EdgeInsets.all(8),
                      itemCount:docs.length,
                      itemBuilder:(_,i){
                        final d=docs[i].data() as Map<String,dynamic>;
                        return ListTile(dense:true,
                            leading:CircleAvatar(radius:16,backgroundColor:Colors.green.withValues(alpha:0.1),
                                child:Text((d['ad']??'?')[0].toUpperCase(),style:const TextStyle(color:Colors.green,fontSize:12))),
                            title:Text(d['ad']??'',style:const TextStyle(fontSize:13)),
                            subtitle:Text(d['adres']??'',style:const TextStyle(fontSize:11),maxLines:1,overflow:TextOverflow.ellipsis),
                            trailing:IconButton(icon:const Icon(Icons.person_remove_outlined,color:Colors.red,size:18),
                                tooltip:'Servisten Cikar',
                                onPressed:() async{
                                  await FirebaseFirestore.instance.collection('students').doc(docs[i].id)
                                      .update({'servisId':'','servisAd':'','updatedAt':FieldValue.serverTimestamp()});
                                  // Servis sayisini guncelle
                                  final cnt=await FirebaseFirestore.instance.collection('students')
                                      .where('firmaId',isEqualTo:widget.firmaId)
                                      .where('servisId',isEqualTo:servisId).count().get();
                                  await FirebaseFirestore.instance.collection('services').doc(servisId)
                                      .update({'ogrenciSayisi':cnt.count??0});
                                }));
                      });
                })),
            const Divider(height:1),
            // Atanmamis ogrenciler
            Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),color:Colors.orange.withValues(alpha:0.05),
                child:const Row(children:[
                  Icon(Icons.pending_outlined,color:Colors.orange,size:14),SizedBox(width:6),
                  Text('Servissiz ogrenciler',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Colors.orange)),
                ])),
            Expanded(child:StreamBuilder<QuerySnapshot>(
                stream:FirebaseFirestore.instance.collection('students')
                    .where('firmaId',isEqualTo:widget.firmaId)
                    .where('projeId',isEqualTo:widget.projeId)
                    .where('servisId',isEqualTo:'').snapshots(),
                builder:(_,snap){
                  final docs=snap.data?.docs??[];
                  if(docs.isEmpty)return const Center(child:Text('Atanmamis ogrenci yok',style:TextStyle(color:Colors.grey)));
                  return ListView.builder(
                      padding:const EdgeInsets.all(8),
                      itemCount:docs.length,
                      itemBuilder:(_,i){
                        final d=docs[i].data() as Map<String,dynamic>;
                        return ListTile(dense:true,
                            leading:CircleAvatar(radius:16,backgroundColor:Colors.orange.withValues(alpha:0.1),
                                child:Text((d['ad']??'?')[0].toUpperCase(),style:const TextStyle(color:Colors.orange,fontSize:12))),
                            title:Text(d['ad']??'',style:const TextStyle(fontSize:13)),
                            subtitle:Text(d['adres']??'',style:const TextStyle(fontSize:11),maxLines:1,overflow:TextOverflow.ellipsis),
                            trailing:IconButton(icon:const Icon(Icons.person_add_outlined,color:Colors.teal,size:18),
                                tooltip:'Bu Servise Ata',
                                onPressed:() async{
                                  await FirebaseFirestore.instance.collection('students').doc(docs[i].id)
                                      .update({'servisId':servisId,'servisAd':servisAd,'updatedAt':FieldValue.serverTimestamp()});
                                  final cnt=await FirebaseFirestore.instance.collection('students')
                                      .where('firmaId',isEqualTo:widget.firmaId)
                                      .where('servisId',isEqualTo:servisId).count().get();
                                  await FirebaseFirestore.instance.collection('services').doc(servisId)
                                      .update({'ogrenciSayisi':cnt.count??0});
                                }));
                      });
                })),
          ]),
        ),
        actions:[
          ElevatedButton(
              style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:()=>Navigator.pop(_),
              child:const Text('Tamam')),
        ]));
  }

  // ── ARSIVLE ─────────────────────────────────────────────────────
  Future<void> _arsivle(String docId,bool mevcutArsiv) async{
    if(!mevcutArsiv){
      final onay=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
          title:const Text('Servisi Arsivle'),
          content:const Text('Bu servis arsive tasinacak. Silinmeyecek, gizlenecek.'),
          actions:[
            TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
            ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.grey),
                onPressed:()=>Navigator.pop(_,true),
                child:const Text('Arsivle',style:TextStyle(color:Colors.white))),
          ]));
      if(onay!=true)return;
    }
    await FirebaseFirestore.instance.collection('services').doc(docId)
        .update({'arsiv':!mevcutArsiv,'aktif':false,'arsivTarihi':FieldValue.serverTimestamp()});
  }

  // ── YARDIMCI ────────────────────────────────────────────────────
  Widget _aksBtn(IconData ikon,Color renk,VoidCallback onTap)=>GestureDetector(
      onTap:onTap,
      child:Container(padding:const EdgeInsets.all(6),
          decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(7)),
          child:Icon(ikon,size:15,color:renk)));

  Widget _dolulukKarti(String b,String v,Color r)=>Expanded(child:Column(children:[
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:r)),
    const SizedBox(height:2),
    Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));

  Widget _raporChip(String t,Color c)=>Container(
      padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
      decoration:BoxDecoration(color:c.withValues(alpha:0.1),borderRadius:BorderRadius.circular(5)),
      child:Text(t,style:TextStyle(fontSize:10,color:c,fontWeight:FontWeight.bold)));

  static TextField _tf(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:_navy,size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)));

  static Widget _ch(String t,Color c)=>Container(
      padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
      decoration:BoxDecoration(color:c.withValues(alpha:0.1),borderRadius:BorderRadius.circular(5)),
      child:Text(t,style:TextStyle(fontSize:10,color:c,fontWeight:FontWeight.bold)));
}


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
          for(final item in[
            (0,Icons.inbox_outlined,'Bekleyen'),
            (1,Icons.check_circle_outline,'Onaylanan'),
            (2,Icons.cancel_outlined,'Reddedilen'),
            (3,Icons.bar_chart_outlined,'Istatistik'),
            (4,Icons.link_outlined,'Kayit Linki'),
            (5,Icons.qr_code_outlined,'QR Karekod'),
            (6,Icons.person_add_outlined,'Yuz Yuze'),
          ])
            GestureDetector(onTap:()=>setState(()=>_s=item.$1),
                child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(color:_s==item.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[Icon(item.$2,size:16,color:_s==item.$1?_t:Colors.grey),
                      const SizedBox(width:6),Text(item.$3,style:TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:_s==item.$1?_t:Colors.grey))]))),
        ])),
    Expanded(child:_s==0?_BekleyenBasvurular(firmaId:widget.firmaId,filtre:'bekliyor'):
    _s==1?_BekleyenBasvurular(firmaId:widget.firmaId,filtre:'onaylandi'):
    _s==2?_BekleyenBasvurular(firmaId:widget.firmaId,filtre:'reddedildi'):
    _s==3?_KayitIstatistik(firmaId:widget.firmaId):
    _s==4?_KayitLinki(firmaId:widget.firmaId):
    _s==5?_QrKayit(firmaId:widget.firmaId):
    _YuzYuzeKayit(firmaId:widget.firmaId)),
  ]);
}

class _BekleyenBasvurular extends StatefulWidget{
  final String firmaId;
  final String filtre; // 'bekliyor' 'onaylandi' 'reddedildi'
  const _BekleyenBasvurular({required this.firmaId,this.filtre='bekliyor'});
  @override State<_BekleyenBasvurular> createState()=>_BekleyenBasvurularState();
}
class _BekleyenBasvurularState extends State<_BekleyenBasvurular>{
  static const _navy=Color(0xFF1a3a6b);

  Future<void> _onaylaBasvuru(BuildContext context,String docId,Map<String,dynamic> d) async{
    // Otomatik kayit olustur
    final fb=FirebaseFirestore.instance;
    final batch=fb.batch();
    // 1. Ogrenci kaydi
    final ogrRef=fb.collection('students').doc();
    batch.set(ogrRef,{
      'firmaId':widget.firmaId,
      'projeId':d['projeId']??'',
      'ad':(d['ogrenciAd']??'').toString().split(' ').first,
      'soyad':(d['ogrenciAd']??'').toString().split(' ').skip(1).join(' '),
      'okul':d['okul']??'',
      'sinif':d['sinif']??'',
      'adres':d['adres']??'',
      'fiyat':d['fiyat']??0,
      'ucret':d['fiyat']??0,
      'aktif':true,'arsiv':false,
      'sozlesmeDurum':'bekliyor',
      'basvuruId':docId,
      'olusturmaTarihi':FieldValue.serverTimestamp(),
    });
    // 2. Veli kaydi
    final veliRef=fb.collection('parents').doc();
    batch.set(veliRef,{
      'firmaId':widget.firmaId,
      'projeId':d['projeId']??'',
      'ad':d['veliAd']??'',
      'anneAd':d['anneAd']??d['veliAd']??'',
      'babaAd':d['babaAd']??'',
      'anneTelefon':d['anneTelefon']??d['telefon']??'',
      'babaTelefon':d['babaTelefon']??'',
      'adres':d['adres']??'',
      'ogrenciId':ogrRef.id,
      'olusturmaTarihi':FieldValue.serverTimestamp(),
    });
    // 3. Tahsilat kaydi
    if((d['fiyat']??0)>0){
      final tahRef=fb.collection('tahsilat').doc();
      batch.set(tahRef,{
        'firmaId':widget.firmaId,
        'projeId':d['projeId']??'',
        'ogrenciId':ogrRef.id,
        'ogrenciAd':d['ogrenciAd']??'',
        'tutar':d['fiyat']??0,
        'ay':'Ilk Kayit',
        'durum':'bekliyor',
        'tarih':FieldValue.serverTimestamp(),
      });
    }
    // 4. Basvuruyu onayla
    batch.update(fb.collection('kayit_basvurulari').doc(docId),{
      'durum':'onaylandi',
      'ogrenciId':ogrRef.id,
      'veliId':veliRef.id,
      'onayTarihi':FieldValue.serverTimestamp(),
    });
    // 5. Ogrenci veliId'sini guncelle
    batch.update(ogrRef,{'veliId':veliRef.id});
    await batch.commit();
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Basvuru onaylandi! Ogrenci ve veli kayitlari olusturuldu.'),
        backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));
  }

  Future<void> _reddetBasvuru(BuildContext context,String docId) async{
    final sebepCtrl=TextEditingController();
    final onay=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
        title:const Text('Basvuruyu Reddet'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Red sebebini yazin (opsiyonel):'),
          const SizedBox(height:10),
          TextField(controller:sebepCtrl,
              decoration:InputDecoration(hintText:'Sebep...',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(8))),
              maxLines:2),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
          ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.red),
              onPressed:()=>Navigator.pop(_,true),
              child:const Text('Reddet',style:TextStyle(color:Colors.white))),
        ]));
    if(onay==true){
      await FirebaseFirestore.instance.collection('kayit_basvurulari').doc(docId).update({
        'durum':'reddedildi',
        'redSebebi':sebepCtrl.text.trim(),
        'redTarihi':FieldValue.serverTimestamp(),
      });
    }
  }

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('kayit_basvurulari')
        .where('firmaId',isEqualTo:widget.firmaId);
    if(widget.filtre!='hepsi')q=q.where('durum',isEqualTo:widget.filtre);
    return StreamBuilder<QuerySnapshot>(
        stream:q.orderBy('tarih',descending:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty){
            final mesaj=widget.filtre=='bekliyor'?'Bekleyen basvuru yok':
            widget.filtre=='onaylandi'?'Onaylanan basvuru yok':'Reddedilen basvuru yok';
            return _bos(mesaj,'Link veya QR ile gelen basvurular burada gorunur.',Icons.inbox_outlined);
          }
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final dur=d['durum']??'bekliyor';
                final r=dur=='onaylandi'?Colors.green:dur=='reddedildi'?Colors.red:Colors.orange;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString();}
                return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:r.withValues(alpha:0.2)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Row(children:[
                        CircleAvatar(radius:20,backgroundColor:_navy.withValues(alpha:0.1),
                            child:Text((d['ogrenciAd']??'B')[0].toUpperCase(),
                                style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ogrenciAd']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                          Row(children:[
                            Text(d['veliAd']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                            if((d['telefon']??d['anneTelefon']??'').isNotEmpty)...[
                              const Text(' · ',style:TextStyle(color:Colors.grey)),
                              Text((d['telefon']??d['anneTelefon']??'').toString(),
                                  style:TextStyle(fontSize:11,color:Colors.grey[400])),
                            ],
                          ]),
                          Text(d['adres']??'',style:TextStyle(fontSize:11,color:Colors.grey[400]),
                              maxLines:1,overflow:TextOverflow.ellipsis),
                        ])),
                        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                              decoration:BoxDecoration(color:r.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                              child:Text(dur,style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:r))),
                          Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                        ]),
                      ]),
                      if((d['fiyat']??0)>0||d['redSebebi']!=null)
                        Padding(padding:const EdgeInsets.only(top:8),
                            child:Row(children:[
                              if((d['fiyat']??0)>0)Container(
                                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                  decoration:BoxDecoration(color:Colors.teal.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                  child:Text((d['fiyat']??0).toString()+' TL/ay',
                                      style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.teal))),
                              const Spacer(),
                              if(dur=='bekliyor')Row(children:[
                                GestureDetector(
                                  onTap:()=>_onaylaBasvuru(context,docs[i].id,d),
                                  child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),
                                      decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                                      child:const Row(mainAxisSize:MainAxisSize.min,children:[
                                        Icon(Icons.check_circle_outline,color:Colors.green,size:14),
                                        SizedBox(width:4),
                                        Text('Onayla + Kayit Olustur',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.green)),
                                      ])),
                                ),
                                const SizedBox(width:6),
                                GestureDetector(
                                  onTap:()=>_reddetBasvuru(context,docs[i].id),
                                  child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:7),
                                      decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                                      child:const Row(mainAxisSize:MainAxisSize.min,children:[
                                        Icon(Icons.cancel_outlined,color:Colors.red,size:14),
                                        SizedBox(width:4),
                                        Text('Reddet',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.red)),
                                      ])),
                                ),
                              ]),
                              if(dur=='reddedildi'&&(d['redSebebi']??'').isNotEmpty)
                                Flexible(child:Text('Red: '+(d['redSebebi']??''),
                                    style:const TextStyle(fontSize:11,color:Colors.red),
                                    maxLines:1,overflow:TextOverflow.ellipsis)),
                            ])),
                    ]));
              });
        });
  }
}


class _KayitIstatistik extends StatelessWidget{
  final String firmaId;
  const _KayitIstatistik({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('kayit_basvurulari')
          .where('firmaId',isEqualTo:firmaId).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        int bekleyen=0,onaylandi=0,reddedildi=0;
        final Map<String,int> projeBasvuru={};
        for(final doc in docs){
          final d=doc.data() as Map<String,dynamic>;
          final dur=d['durum']??'bekliyor';
          if(dur=='bekliyor')bekleyen++;
          else if(dur=='onaylandi')onaylandi++;
          else if(dur=='reddedildi')reddedildi++;
          final proje=(d['projeAd']??'Belirsiz').toString();
          projeBasvuru[proje]=(projeBasvuru[proje]??0)+1;
        }
        final sortedProjeler=projeBasvuru.entries.toList()
          ..sort((a,b)=>b.value.compareTo(a.value));
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Kayit Istatistikleri',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _iK('Toplam',docs.length.toString(),_navy,Icons.inbox_outlined),
            const SizedBox(width:12),
            _iK('Onaylanan',onaylandi.toString(),Colors.green,Icons.check_circle_outline),
            const SizedBox(width:12),
            _iK('Bekleyen',bekleyen.toString(),Colors.orange,Icons.pending_outlined),
            const SizedBox(width:12),
            _iK('Reddedilen',reddedildi.toString(),Colors.red,Icons.cancel_outlined),
          ]),
          const SizedBox(height:24),
          if(docs.isNotEmpty)...[
            const Text('Onay Orani',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:[
                  Row(children:[
                    Text(((onaylandi/docs.length)*100).round().toString()+'%',
                        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:28,color:_navy)),
                    const SizedBox(width:10),
                    const Text('onaylandi',style:TextStyle(color:Colors.grey)),
                  ]),
                  const SizedBox(height:10),
                  ClipRRect(borderRadius:BorderRadius.circular(6),
                      child:LinearProgressIndicator(
                          value:(onaylandi/docs.length).clamp(0.0,1.0),
                          minHeight:12,
                          backgroundColor:Colors.grey.withValues(alpha:0.15),
                          valueColor:const AlwaysStoppedAnimation<Color>(Colors.green))),
                ])),
            const SizedBox(height:24),
          ],
          if(sortedProjeler.isNotEmpty)...[
            const Text('Proje Bazli Basvurular',
                style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:sortedProjeler.take(8).map((e)=>
                    Padding(padding:const EdgeInsets.only(bottom:10),
                        child:Row(children:[
                          SizedBox(width:150,child:Text(e.key,
                              style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12),
                              maxLines:1,overflow:TextOverflow.ellipsis)),
                          const SizedBox(width:10),
                          Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                              child:LinearProgressIndicator(
                                  value:sortedProjeler.first.value>0
                                      ?(e.value/sortedProjeler.first.value).clamp(0.0,1.0):0,
                                  minHeight:8,
                                  backgroundColor:Colors.grey.withValues(alpha:0.1),
                                  valueColor:const AlwaysStoppedAnimation<Color>(_navy)))),
                          const SizedBox(width:10),
                          Text(e.value.toString(),
                              style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        ]))).toList())),
          ],
        ]));
      });

  Widget _iK(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:20,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
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
  @override void initState(){super.initState();_tab=TabController(length:7,vsync:this);}
  @override void dispose(){_tab.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:TabBar(controller:_tab,labelColor:_navy,unselectedLabelColor:Colors.grey,
        indicatorColor:_orange,isScrollable:true,tabAlignment:TabAlignment.start,
        tabs:const[
          Tab(icon:Icon(Icons.pending_outlined,size:16),text:'Bekleyen'),
          Tab(icon:Icon(Icons.check_circle_outline,size:16),text:'Imzalanan'),
          Tab(icon:Icon(Icons.timer_off_outlined,size:16),text:'Suresi Dolan'),
          Tab(icon:Icon(Icons.archive_outlined,size:16),text:'Arsiv'),
          Tab(icon:Icon(Icons.text_snippet_outlined,size:16),text:'Sablonlar'),
          Tab(icon:Icon(Icons.folder_outlined,size:16),text:'Evraklar'),
          Tab(icon:Icon(Icons.bar_chart_outlined,size:16),text:'Rapor'),
        ])),
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
      _SablonYonetim(firmaId:widget.firmaId),
      _EvrakMerkezi(firmaId:widget.firmaId),
      _EvrakRaporu(firmaId:widget.firmaId),
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
                      GestureDetector(
                          onTap:() async{
                            final url=d['pdfUrl'] as String? ??'';
                            if(url.isNotEmpty){
                              await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication);
                            } else {
                              if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content:Text('PDF henuz olusturulmamis'),behavior:SnackBarBehavior.floating));
                            }
                          },
                          child:Container(padding:const EdgeInsets.all(6),
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
// ─────────────────────────────────────────────────────────────────
//  HARITA MODULU – Bolum 10
// ─────────────────────────────────────────────────────────────────
class _HaritaModul extends StatefulWidget{
  final String firmaId,projeId;
  const _HaritaModul({required this.firmaId,required this.projeId});
  @override State<_HaritaModul> createState()=>_HaritaModulState();
}
class _HaritaModulState extends State<_HaritaModul>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    // Tab bar
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.map_outlined,'Harita'),
            (1,Icons.people_outline,'Ogrenci Dagilimi'),
            (2,Icons.directions_bus_outlined,'Servis Doluluk'),
            (3,Icons.alt_route_outlined,'Rota Yonetimi'),
            (4,Icons.bar_chart_outlined,'Harita Raporu'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:_tab==0
        ? WebHarita(firmaId:widget.firmaId,projeId:widget.projeId)
        : _tab==1 ? _OgrenciDagilimi(firmaId:widget.firmaId,projeId:widget.projeId)
        : _tab==2 ? _ServisDoluluk(firmaId:widget.firmaId,projeId:widget.projeId)
        : _tab==3 ? _RotaYonetimi(firmaId:widget.firmaId,projeId:widget.projeId)
        : _HaritaRaporu(firmaId:widget.firmaId,projeId:widget.projeId)),
  ]);
}

// ── OGRENCI DAGILIMI ─────────────────────────────────────────────
class _OgrenciDagilimi extends StatefulWidget{
  final String firmaId,projeId;
  const _OgrenciDagilimi({required this.firmaId,required this.projeId});
  @override State<_OgrenciDagilimi> createState()=>_OgrenciDagilimiState();
}
class _OgrenciDagilimiState extends State<_OgrenciDagilimi>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  String _filtre='hepsi'; // hepsi, atanmis, atanmamis

  @override Widget build(BuildContext context)=>Column(children:[
    // Filtre bar
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          const Text('Ogrenci Dagilimi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          for(final f in [('hepsi','Tumu'),('atanmis','Servise Atanmis'),('atanmamis','Atanamsis')])
            GestureDetector(onTap:()=>setState(()=>_filtre=f.$1),
                child:Container(margin:const EdgeInsets.only(left:8),
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                    decoration:BoxDecoration(
                        color:_filtre==f.$1?_navy:Colors.grey[100],
                        borderRadius:BorderRadius.circular(8)),
                    child:Text(f.$2,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,
                        color:_filtre==f.$1?Colors.white:Colors.grey)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:(){
          var q=FirebaseFirestore.instance.collection('students')
              .where('firmaId',isEqualTo:widget.firmaId);
          if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
          return q.snapshots();
        }(),
        builder:(_,snap){
          var docs=snap.data?.docs??[];
          if(_filtre=='atanmis')docs=docs.where((d)=>(d.data() as Map)['servisId']?.isNotEmpty==true).toList();
          if(_filtre=='atanmamis')docs=docs.where((d){final dd=d.data() as Map;return (dd['servisId']??'').isEmpty;}).toList();

          // Servis bazli gruplama
          final Map<String,List<Map<String,dynamic>>> servisGrubu={};
          final List<Map<String,dynamic>> atanmamis=[];
          for(final doc in docs){
            final d={...doc.data() as Map<String,dynamic>,'id':doc.id};
            final servisId=(d['servisId']??'') as String;
            if(servisId.isEmpty){atanmamis.add(d);continue;}
            servisGrubu.putIfAbsent(servisId,()=>[]);
            servisGrubu[servisId]!.add(d);
          }

          return Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            // Sol: Istatistik ozeti
            Container(width:220,color:Colors.white,padding:const EdgeInsets.all(16),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('Ozet',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
                  const SizedBox(height:12),
                  _ozetSatir('Toplam Ogrenci',docs.length.toString(),Icons.school_outlined,_navy),
                  _ozetSatir('Servise Atanmis',
                      docs.where((d)=>(d.data() as Map)['servisId']?.isNotEmpty==true).length.toString(),
                      Icons.check_circle_outline,Colors.green),
                  _ozetSatir('Atanmamis',atanmamis.length.toString(),Icons.pending_outlined,Colors.orange),
                  _ozetSatir('Servis Sayisi',servisGrubu.length.toString(),Icons.directions_bus_outlined,Colors.blue),
                  const Divider(),
                  const Text('Servis Bazli',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:12)),
                  const SizedBox(height:8),
                  Expanded(child:ListView(children:[
                    ...servisGrubu.entries.map((e)=>Padding(
                        padding:const EdgeInsets.only(bottom:6),
                        child:Row(children:[
                          Expanded(child:Text(e.key.substring(0,e.key.length.clamp(0,12)),
                              style:const TextStyle(fontSize:11),maxLines:1,overflow:TextOverflow.ellipsis)),
                          Text(e.value.length.toString()+' ogr',
                              style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:_navy)),
                        ]))),
                    if(atanmamis.isNotEmpty)Padding(
                        padding:const EdgeInsets.only(bottom:6),
                        child:Row(children:[
                          const Expanded(child:Text('Atanmamis',style:TextStyle(fontSize:11,color:Colors.orange))),
                          Text(atanmamis.length.toString()+' ogr',
                              style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.orange)),
                        ])),
                  ])),
                ])),
            // Sag: Liste
            Expanded(child:docs.isEmpty
                ? _bos('Ogrenci bulunamadi','',Icons.school_outlined)
                : ListView.builder(
                padding:const EdgeInsets.all(16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final servisId=(d['servisId']??'') as String;
                  final atanmis=servisId.isNotEmpty;
                  return Container(margin:const EdgeInsets.only(bottom:6),
                      padding:const EdgeInsets.all(12),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                          border:Border.all(color:(atanmis?Colors.green:Colors.orange).withValues(alpha:0.2)),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                      child:Row(children:[
                        Icon(atanmis?Icons.check_circle_outline:Icons.pending_outlined,
                            color:atanmis?Colors.green:Colors.orange,size:18),
                        const SizedBox(width:10),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                          Text(d['adres']??'',style:TextStyle(fontSize:11,color:Colors.grey[500]),
                              maxLines:1,overflow:TextOverflow.ellipsis),
                        ])),
                        Text(atanmis?(d['servisAd']??servisId):'Atanmamis',
                            style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,
                                color:atanmis?_navy:Colors.orange)),
                      ]));
                })),
          ]);
        })),
  ]);

  Widget _ozetSatir(String b,String v,IconData i,Color r)=>Padding(
      padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[
    Icon(i,size:14,color:r),const SizedBox(width:6),
    Expanded(child:Text(b,style:const TextStyle(fontSize:12))),
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:r)),
  ]));
}

// ── SERVIS DOLULUK ───────────────────────────────────────────────
class _ServisDoluluk extends StatelessWidget{
  final String firmaId,projeId;
  const _ServisDoluluk({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:(){
        var q=FirebaseFirestore.instance.collection('services')
            .where('firmaId',isEqualTo:firmaId);
        if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
        return q.snapshots();
      }(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Servis bulunamadi','',Icons.directions_bus_outlined);

        int toplamKap=0,toplamOgr=0;
        for(final doc in docs){
          final d=doc.data() as Map<String,dynamic>;
          toplamKap+=(d['kapasite']??17) as int;
          toplamOgr+=(d['ogrenciSayisi']??0) as int;
        }

        return Column(children:[
          // Genel ozet
          Container(margin:const EdgeInsets.all(16),padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
              child:Column(children:[
                Row(children:[
                  _ozetKarti('Toplam Koltuk',toplamKap.toString(),_navy),
                  _ozetKarti('Dolu',toplamOgr.toString(),Colors.orange),
                  _ozetKarti('Bos',(toplamKap-toplamOgr).toString(),Colors.green),
                  _ozetKarti('Servis Sayisi',docs.length.toString(),Colors.blue),
                ]),
                const SizedBox(height:12),
                ClipRRect(borderRadius:BorderRadius.circular(6),
                    child:LinearProgressIndicator(
                        value:toplamKap>0?(toplamOgr/toplamKap).clamp(0.0,1.0):0,
                        minHeight:14,
                        backgroundColor:Colors.grey.withValues(alpha:0.15),
                        valueColor:AlwaysStoppedAnimation<Color>(
                            toplamKap>0&&toplamOgr/toplamKap>0.85?Colors.red:Colors.orange))),
                const SizedBox(height:6),
                Text('Genel Doluluk: '+
                    (toplamKap>0?((toplamOgr/toplamKap)*100).round().toString()+'%':'0%'),
                    style:const TextStyle(fontWeight:FontWeight.bold,color:_navy)),
              ])),
          // Servis listesi
          Expanded(child:ListView.builder(
              padding:const EdgeInsets.symmetric(horizontal:16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final kap=(d['kapasite']??17) as int;
                final ogr=(d['ogrenciSayisi']??0) as int;
                final dol=kap>0?(ogr/kap).clamp(0.0,1.0):0.0;
                final renkIdx=(d['renkIndex']??0) as int;
                final renkler=[
                  const Color(0xFF1a3a6b),Colors.red,Colors.green,
                  Colors.orange,Colors.purple,Colors.cyan,Colors.deepOrange,Colors.indigo,
                ];
                final sRenk=renkler[renkIdx.clamp(0,renkler.length-1)];
                final dolulukRenk=dol>0.85?Colors.red:dol>0.6?Colors.orange:Colors.green;

                return Container(margin:const EdgeInsets.only(bottom:10),
                    padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        border:Border(left:BorderSide(color:sRenk,width:4)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Column(children:[
                      Row(children:[
                        Icon(Icons.directions_bus_outlined,color:sRenk,size:20),
                        const SizedBox(width:10),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                          Text((d['soforAd']??'Sofor Atanmamis').toString(),
                              style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        ])),
                        Text(ogr.toString()+'/'+kap.toString(),
                            style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:dolulukRenk)),
                        const SizedBox(width:8),
                        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                            decoration:BoxDecoration(color:dolulukRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                            child:Text((dol*100).round().toString()+'%',
                                style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:dolulukRenk))),
                      ]),
                      const SizedBox(height:8),
                      ClipRRect(borderRadius:BorderRadius.circular(5),
                          child:LinearProgressIndicator(value:dol,minHeight:8,
                              backgroundColor:Colors.grey.withValues(alpha:0.1),
                              valueColor:AlwaysStoppedAnimation<Color>(dolulukRenk))),
                      if(kap-ogr>0)Padding(
                          padding:const EdgeInsets.only(top:4),
                          child:Text((kap-ogr).toString()+' bos koltuk mevcut',
                              style:TextStyle(fontSize:10,color:Colors.grey[400]))),
                    ]));
              })),
        ]);
      });

  Widget _ozetKarti(String b,String v,Color r)=>Expanded(child:Column(children:[
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
    Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));
}

// ── ROTA YONETIMI ────────────────────────────────────────────────
class _RotaYonetimi extends StatefulWidget{
  final String firmaId,projeId;
  const _RotaYonetimi({required this.firmaId,required this.projeId});
  @override State<_RotaYonetimi> createState()=>_RotaYonetimiState();
}
class _RotaYonetimiState extends State<_RotaYonetimi>{
  static const _navy=Color(0xFF1a3a6b);
  String? _seciliServisId;

  @override Widget build(BuildContext context)=>Row(children:[
    // Sol: Servis secici
    Container(width:240,color:Colors.white,
        child:Column(children:[
          Container(padding:const EdgeInsets.all(14),color:_navy,
              child:const Row(children:[
                Icon(Icons.alt_route_outlined,color:Colors.white,size:16),SizedBox(width:8),
                Text('Rotalar',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
              ])),
          Expanded(child:StreamBuilder<QuerySnapshot>(
              stream:(){
                var q=FirebaseFirestore.instance.collection('services')
                    .where('firmaId',isEqualTo:widget.firmaId);
                if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
                return q.snapshots();
              }(),
              builder:(_,snap){
                final docs=snap.data?.docs??[];
                return ListView.builder(itemCount:docs.length,
                    itemBuilder:(_,i){
                      final d=docs[i].data() as Map<String,dynamic>;
                      final sec=_seciliServisId==docs[i].id;
                      return GestureDetector(
                          onTap:()=>setState(()=>_seciliServisId=docs[i].id),
                          child:Container(
                              padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                              color:sec?_navy.withValues(alpha:0.08):Colors.transparent,
                              child:Row(children:[
                                Container(width:4,height:36,
                                    decoration:BoxDecoration(
                                        color:sec?const Color(0xFFFF8C00):Colors.grey.withValues(alpha:0.2),
                                        borderRadius:BorderRadius.circular(2))),
                                const SizedBox(width:10),
                                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                  Text(d['ad']??'',style:TextStyle(fontWeight:FontWeight.w600,
                                      fontSize:13,color:sec?_navy:Colors.black87),maxLines:1,overflow:TextOverflow.ellipsis),
                                  Text((d['ogrenciSayisi']??0).toString()+' ogrenci',
                                      style:TextStyle(fontSize:11,color:Colors.grey[500])),
                                ])),
                              ])));
                    });
              })),
        ])),
    // Sag: Secili servisin duraklari
    Expanded(child:_seciliServisId==null
        ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(Icons.touch_app_outlined,size:56,color:Colors.grey[300]),
      const SizedBox(height:12),
      const Text('Sol panelden bir servis secin',style:TextStyle(color:Colors.grey,fontSize:16)),
    ]))
        : _ServisDuraklari(firmaId:widget.firmaId,servisId:_seciliServisId!)),
  ]);
}

class _ServisDuraklari extends StatelessWidget{
  final String firmaId,servisId;
  const _ServisDuraklari({required this.firmaId,required this.servisId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:Row(children:[
          const Text('Durak Sirasi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(color:_t.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
              child:const Row(children:[
                Icon(Icons.info_outline,size:14,color:_t),SizedBox(width:4),
                Text('Sofor Konum Al ile guncellenir',style:TextStyle(fontSize:11,color:_t)),
              ])),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('students')
            .where('firmaId',isEqualTo:firmaId)
            .where('servisId',isEqualTo:servisId)
            .orderBy('sira').snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Bu serviste ogrenci yok','Ogrenci atama sekmesinden ogrenci ekleyin.',Icons.people_outline);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final sira=(d['sira']??i+1) as int;
                final konum=(d['lat']!=null&&d['lng']!=null);
                return Container(margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:Colors.grey.withValues(alpha:0.15)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                    child:Row(children:[
                      Container(width:36,height:36,
                          decoration:BoxDecoration(
                              color:_navy.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:Center(child:Text(sira.toString(),
                              style:const TextStyle(fontWeight:FontWeight.bold,color:_navy)))),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(d['adres']??'',style:TextStyle(fontSize:11,color:Colors.grey[500]),
                            maxLines:1,overflow:TextOverflow.ellipsis),
                      ])),
                      Column(children:[
                        Icon(konum?Icons.location_on_outlined:Icons.location_off_outlined,
                            color:konum?Colors.green:Colors.grey,size:18),
                        Text(konum?'GPS var':'GPS yok',
                            style:TextStyle(fontSize:9,color:konum?Colors.green:Colors.grey)),
                      ]),
                    ]));
              });
        })),
  ]);
}

// ── HARITA RAPORU ────────────────────────────────────────────────
class _HaritaRaporu extends StatelessWidget{
  final String firmaId,projeId;
  const _HaritaRaporu({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data as Map<String,dynamic>;
        final servisler=data['servisler'] as List<Map<String,dynamic>>;

        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Harita ve Servis Raporu',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          // Ozet kartlar
          Row(children:[
            _rKarti('Toplam Servis',(data['toplamServis']??0).toString(),_navy,Icons.directions_bus_outlined),
            const SizedBox(width:12),
            _rKarti('Toplam Ogrenci',(data['toplamOgrenci']??0).toString(),Colors.blue,Icons.school_outlined),
            const SizedBox(width:12),
            _rKarti('Ort. Doluluk',(data['ortDoluluk']??'0')+'%',Colors.orange,Icons.donut_small_outlined),
            const SizedBox(width:12),
            _rKarti('Atanmamis',(data['atanmamis']??0).toString(),Colors.red,Icons.pending_outlined),
          ]),
          const SizedBox(height:24),
          // Servis karsilastirma
          const Text('Servis Karsilastirma',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:10),
          Container(padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
              child:Column(children:[
                // Header
                const Padding(padding:EdgeInsets.only(bottom:8),child:Row(children:[
                  SizedBox(width:120,child:Text('Servis',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Colors.grey))),
                  Expanded(child:Text('Doluluk',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Colors.grey))),
                  SizedBox(width:80,child:Text('Ogr/Kap',style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Colors.grey),textAlign:TextAlign.right)),
                ])),
                const Divider(),
                ...servisler.map((s){
                  final kap=(s['kapasite']??17) as int;
                  final ogr=(s['ogrenciSayisi']??0) as int;
                  final dol=kap>0?(ogr/kap).clamp(0.0,1.0):0.0;
                  final renkIdx=(s['renkIndex']??0) as int;
                  final renkler=[
                    const Color(0xFF1a3a6b),Colors.red,Colors.green,
                    Colors.orange,Colors.purple,Colors.cyan,Colors.deepOrange,Colors.indigo,
                  ];
                  final sRenk=renkler[renkIdx.clamp(0,renkler.length-1)];
                  return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
                    SizedBox(width:120,child:Text(s['ad']??'',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600),
                        maxLines:1,overflow:TextOverflow.ellipsis)),
                    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                        child:LinearProgressIndicator(value:dol,minHeight:10,
                            backgroundColor:Colors.grey.withValues(alpha:0.1),
                            valueColor:AlwaysStoppedAnimation<Color>(sRenk)))),
                    SizedBox(width:80,child:Text(ogr.toString()+'/'+kap.toString(),
                        style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:sRenk),
                        textAlign:TextAlign.right)),
                  ]));
                }),
              ])),
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      var sQ=FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:firmaId);
      if(projeId.isNotEmpty)sQ=sQ.where('projeId',isEqualTo:projeId);
      var oQ=FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:firmaId);
      if(projeId.isNotEmpty)oQ=oQ.where('projeId',isEqualTo:projeId);

      final results=await Future.wait([sQ.get(),oQ.get()]);
      final servisSnap=results[0].docs;
      final ogrSnap=results[1].docs;

      int toplamKap=0,toplamOgr=0;
      for(final doc in servisSnap){
        final d=doc.data() as Map<String,dynamic>;
        toplamKap+=(d['kapasite']??17) as int;
        toplamOgr+=(d['ogrenciSayisi']??0) as int;
      }

      final atanmamis=ogrSnap.where((d)=>(d.data() as Map)['servisId']?.isEmpty!=false).length;
      final ortDoluluk=toplamKap>0?((toplamOgr/toplamKap)*100).round().toString():'0';

      return{
        'toplamServis':servisSnap.length,
        'toplamOgrenci':ogrSnap.length,
        'ortDoluluk':ortDoluluk,
        'atanmamis':atanmamis,
        'servisler':servisSnap.map((d)=>{'id':d.id,...d.data() as Map<String,dynamic>}).toList(),
      };
    }catch(_){return{'servisler':[]};}
  }

  Widget _rKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}


// ─────────────────────────────────────────────────────────────────
//  SOZLESME SABLON YONETIMI
// ─────────────────────────────────────────────────────────────────
class _SablonYonetim extends StatefulWidget{
  final String firmaId;
  const _SablonYonetim({required this.firmaId});
  @override State<_SablonYonetim> createState()=>_SablonYonetimState();
}
class _SablonYonetimState extends State<_SablonYonetim>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  void _sablonEkleDialog(BuildContext context,[Map<String,dynamic>? mevcut,String? docId]){
    final adCtrl=TextEditingController(text:mevcut?['ad']??'');
    final icerikCtrl=TextEditingController(text:mevcut?['icerik']??_varsayilanSablon());
    bool aktif=mevcut?['aktif']??true;

    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:Text(mevcut==null?'Yeni Sablon':'Sablon Duzenle',
            style:const TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:700,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Row(children:[
            Expanded(child:TextField(controller:adCtrl,
                decoration:InputDecoration(labelText:'Sablon Adi *',
                    prefixIcon:const Icon(Icons.text_snippet_outlined,color:_navy,size:18),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                    isDense:true))),
            const SizedBox(width:12),
            Row(children:[
              const Text('Aktif:',style:TextStyle(fontWeight:FontWeight.w600)),
              const SizedBox(width:8),
              Switch(value:aktif,activeThumbColor:_t,onChanged:(v)=>setS(()=>aktif=v)),
            ]),
          ]),
          const SizedBox(height:12),
          Container(padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:_navy.withValues(alpha:0.04),borderRadius:BorderRadius.circular(8)),
              child:const Wrap(spacing:8,runSpacing:4,children:[
                _TagChip('[VELI_ADI]'),_TagChip('[OGRENCI_ADI]'),
                _TagChip('[PROJE_ADI]'),_TagChip('[UCRET]'),
                _TagChip('[TARIH]'),_TagChip('[FIRMA_ADI]'),
                _TagChip('[SOFOR_ADI]'),_TagChip('[ARAC_PLAKA]'),
              ])),
          const SizedBox(height:8),
          TextField(controller:icerikCtrl,maxLines:12,
              decoration:InputDecoration(
                  labelText:'Sozlesme Icerigi (yukaridaki etiketleri kullanin)',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  contentPadding:const EdgeInsets.all(12))),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(adCtrl.text.trim().isEmpty)return;
                final data={
                  'firmaId':widget.firmaId,
                  'ad':adCtrl.text.trim(),
                  'icerik':icerikCtrl.text.trim(),
                  'aktif':aktif,
                  'guncelleme':FieldValue.serverTimestamp(),
                };
                if(docId!=null){
                  await FirebaseFirestore.instance.collection('sozlesme_sablonlari').doc(docId).update(data);
                }else{
                  data['olusturmaTarihi']=FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('sozlesme_sablonlari').add(data);
                }
                if(ctx.mounted)Navigator.pop(ctx);
              },
              icon:const Icon(Icons.save_outlined,size:16),
              label:Text(mevcut==null?'Olustur':'Kaydet')),
        ])));
  }

  String _varsayilanSablon()=>'SERVIS SOZLESMESI'
      '\n\nSayin [VELI_ADI],'
      '\n\n[PROJE_ADI] projesi kapsaminda [OGRENCI_ADI] isimli ogrencimizin'
      '\nservis hizmetinden yararlanacagini teyid ederiz.'
      '\n\nAylik Servis Ucreti: [UCRET] TL'
      '\n\nSozlesme Tarihi: [TARIH]'
      '\n\nServis Firmasi: [FIRMA_ADI]'
      '\nSofor: [SOFOR_ADI]'
      '\nArac Plakasi: [ARAC_PLAKA]'
      '\n\nKVKK kapsaminda verileriniz servis yonetimi amaciyla islenecektir.'
      '\n\nYukaridaki bilgileri okudum ve kabul ediyorum.'
      '\n\nImza: _______________';

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          const Text('Sozlesme Sablonlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:()=>_sablonEkleDialog(context),
              icon:const Icon(Icons.add,size:16),label:const Text('Yeni Sablon')),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('sozlesme_sablonlari')
            .where('firmaId',isEqualTo:widget.firmaId)
            .orderBy('olusturmaTarihi',descending:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Sablon bulunamadi','Yeni sablon olusturun.',Icons.text_snippet_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final aktif=d['aktif']??true;
                return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        border:Border.all(color:(aktif?_navy:Colors.grey).withValues(alpha:0.15)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Row(children:[
                        Icon(Icons.text_snippet_outlined,color:aktif?_navy:Colors.grey,size:20),
                        const SizedBox(width:10),
                        Expanded(child:Text(d['ad']??'',
                            style:TextStyle(fontWeight:FontWeight.bold,fontSize:14,
                                color:aktif?_navy:Colors.grey))),
                        Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                            decoration:BoxDecoration(
                                color:(aktif?Colors.green:Colors.grey).withValues(alpha:0.1),
                                borderRadius:BorderRadius.circular(6)),
                            child:Text(aktif?'Aktif':'Pasif',style:TextStyle(fontSize:10,
                                fontWeight:FontWeight.bold,color:aktif?Colors.green:Colors.grey))),
                        const SizedBox(width:8),
                        IconButton(icon:const Icon(Icons.edit_outlined,size:18,color:_navy),
                            onPressed:()=>_sablonEkleDialog(context,d,docs[i].id)),
                        IconButton(icon:const Icon(Icons.delete_outline,size:18,color:Colors.red),
                            onPressed:() async{
                              final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
                                  title:const Text('Sablonu Sil'),
                                  content:const Text('Bu sablon silinecek (sozlesmeler etkilenmez). Devam?'),
                                  actions:[TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
                                    ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.red),
                                        onPressed:()=>Navigator.pop(_,true),
                                        child:const Text('Sil',style:TextStyle(color:Colors.white)))]));
                              if(ok==true)await FirebaseFirestore.instance
                                  .collection('sozlesme_sablonlari').doc(docs[i].id).delete();
                            }),
                      ]),
                      if((d['icerik']??'').isNotEmpty)...[
                        const SizedBox(height:8),
                        Text((d['icerik']??'').toString().substring(0,
                            ((d['icerik']??'').toString().length).clamp(0,150))+'...',
                            style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ],
                    ]));
              });
        })),
  ]);
}

class _TagChip extends StatelessWidget{
  final String tag;
  const _TagChip(this.tag);
  @override Widget build(BuildContext context)=>Container(
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
      decoration:BoxDecoration(color:const Color(0xFF1a3a6b).withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
      child:Text(tag,style:const TextStyle(fontSize:10,color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)));
}

// ─────────────────────────────────────────────────────────────────
//  EVRAK MERKEZI
// ─────────────────────────────────────────────────────────────────
class _EvrakMerkezi extends StatefulWidget{
  final String firmaId;
  const _EvrakMerkezi({required this.firmaId});
  @override State<_EvrakMerkezi> createState()=>_EvrakMerkeziState();
}
class _EvrakMerkeziState extends State<_EvrakMerkezi>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _altTab=0; // 0=Sofor, 1=Arac, 2=Ogrenci

  @override Widget build(BuildContext context)=>Column(children:[
    // Alt tab bar
    Container(color:Colors.white,padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
        child:Row(children:[
          for(final t in [(0,Icons.person_outlined,'Sofor Evraklari'),
            (1,Icons.directions_car_outlined,'Arac Evraklari'),
            (2,Icons.school_outlined,'Ogrenci Evraklari')])
            GestureDetector(onTap:()=>setState(()=>_altTab=t.$1),
                child:Container(margin:const EdgeInsets.only(right:8),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
                    decoration:BoxDecoration(
                        color:_altTab==t.$1?_navy:Colors.grey[100],
                        borderRadius:BorderRadius.circular(8)),
                    child:Row(children:[
                      Icon(t.$2,size:14,color:_altTab==t.$1?Colors.white:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_altTab==t.$1?Colors.white:Colors.grey)),
                    ]))),
        ])),
    Expanded(child:_altTab==0?_SoforEvraklari(firmaId:widget.firmaId):
    _altTab==1?_AracEvraklari(firmaId:widget.firmaId):
    _OgrenciEvraklari(firmaId:widget.firmaId)),
  ]);
}

// ─── SOFOR EVRAKLARI ─────────────────────────────────────────────
class _SoforEvraklari extends StatelessWidget{
  final String firmaId;
  const _SoforEvraklari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('drivers')
          .where('firmaId',isEqualTo:firmaId).orderBy('ad').snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Sofor bulunamadi','',Icons.person_outlined);
        return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;
              // Evrak durumu hesapla
              final evraklar=[
                ('Ehliyet',d['ehliyetNo']??'',d['ehliyetBitisTarihi']??''),
                ('SRC',d['srcBelge']??'',d['srcBitisTarihi']??''),
                ('Psikoteknik',d['psikoteknikBelge']??'',d['psikoteknikBitisTarihi']??''),
              ];
              final eksik=evraklar.where((e)=>e.$2.isEmpty).length;
              final uyari=_yaklasiyor(d['ehliyetBitisTarihi']??'')||
                  _yaklasiyor(d['srcBitisTarihi']??'')||
                  _yaklasiyor(d['psikoteknikBitisTarihi']??'');

              return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:uyari?Colors.orange.withValues(alpha:0.3):
                      eksik>0?Colors.red.withValues(alpha:0.2):Colors.green.withValues(alpha:0.15)),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                  child:ExpansionTile(
                      tilePadding:EdgeInsets.zero,
                      leading:CircleAvatar(radius:20,backgroundColor:_navy.withValues(alpha:0.1),
                          child:Text((d['ad']??'?')[0].toUpperCase(),
                              style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                      title:Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                      subtitle:Row(children:[
                        if(eksik>0)...[
                          const Icon(Icons.warning_outlined,size:12,color:Colors.red),
                          const SizedBox(width:4),
                          Text(eksik.toString()+' eksik evrak',style:const TextStyle(fontSize:11,color:Colors.red)),
                          const SizedBox(width:8),
                        ],
                        if(uyari)...[
                          const Icon(Icons.access_time_outlined,size:12,color:Colors.orange),
                          const SizedBox(width:4),
                          const Text('Bitis tarihi yaklasiyor',style:TextStyle(fontSize:11,color:Colors.orange)),
                        ],
                      ]),
                      children:[
                        Padding(padding:const EdgeInsets.all(12),
                            child:Column(children:evraklar.map((e)=>
                                _evrakSatir(e.$1,e.$2,e.$3)).toList())),
                      ]));
            });
      });

  static bool _yaklasiyor(String tarih){
    if(tarih.isEmpty)return false;
    try{
      final parts=tarih.split('.');
      if(parts.length<3)return false;
      final dt=DateTime(int.parse(parts[2]),int.parse(parts[1]),int.parse(parts[0]));
      return dt.difference(DateTime.now()).inDays<=30;
    }catch(_){return false;}
  }

  Widget _evrakSatir(String ad,String deger,String bitisTarihi)=>Padding(
      padding:const EdgeInsets.symmetric(vertical:4),
      child:Row(children:[
        SizedBox(width:120,child:Text(ad,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
        Expanded(child:Text(deger.isNotEmpty?deger:'Eksik',
            style:TextStyle(fontSize:12,color:deger.isNotEmpty?Colors.grey[700]:Colors.red))),
        if(bitisTarihi.isNotEmpty)Text(bitisTarihi,
            style:TextStyle(fontSize:11,color:_yaklasiyor(bitisTarihi)?Colors.orange:Colors.grey)),
        if(deger.isEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
            decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
            child:const Text('EKSIK',style:TextStyle(fontSize:9,color:Colors.red,fontWeight:FontWeight.bold))),
      ]));
}

// ─── ARAC EVRAKLARI ──────────────────────────────────────────────
class _AracEvraklari extends StatelessWidget{
  final String firmaId;
  const _AracEvraklari({required this.firmaId});

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('vehicles')
          .where('firmaId',isEqualTo:firmaId).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Arac bulunamadi','',Icons.directions_car_outlined);
        return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;
              final evraklar=[
                ('Ruhsat',d['ruhsat']??'',d['ruhsatBitisTarihi']??''),
                ('Sigorta',d['sigorta']??'',d['sigortaTarihi']??''),
                ('Muayene',d['muayene']??'',d['muayeneTarihi']??''),
                ('Tasima Belgesi',d['tasimaYetkiBelge']??'',d['tasimaYetkiBitisTarihi']??''),
              ];
              final eksik=evraklar.where((e)=>e.$2.isEmpty).length;
              return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:eksik>0?Colors.red.withValues(alpha:0.2):Colors.green.withValues(alpha:0.15))),
                  child:ExpansionTile(
                      tilePadding:EdgeInsets.zero,
                      leading:Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:const Color(0xFF1a3a6b).withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.directions_car_outlined,color:Color(0xFF1a3a6b),size:20)),
                      title:Text((d['plaka']??'').toString()+' – '+(d['marka']??'').toString(),
                          style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                      subtitle:eksik>0?Text(eksik.toString()+' eksik evrak',
                          style:const TextStyle(fontSize:11,color:Colors.red)):
                      const Text('Tum evraklar tamam',style:TextStyle(fontSize:11,color:Colors.green)),
                      children:[
                        Padding(padding:const EdgeInsets.all(12),
                            child:Column(children:evraklar.map((e)=>Padding(
                                padding:const EdgeInsets.symmetric(vertical:4),
                                child:Row(children:[
                                  SizedBox(width:130,child:Text(e.$1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                                  Expanded(child:Text(e.$2.isNotEmpty?e.$2:'Eksik',
                                      style:TextStyle(fontSize:12,color:e.$2.isNotEmpty?Colors.grey:Colors.red))),
                                  if(e.$3.isNotEmpty)Text(e.$3,style:const TextStyle(fontSize:11,color:Colors.grey)),
                                ]))).toList())),
                      ]));
            });
      });
}

// ─── OGRENCI EVRAKLARI ──────────────────────────────────────────
class _OgrenciEvraklari extends StatelessWidget{
  final String firmaId;
  const _OgrenciEvraklari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('students')
          .where('firmaId',isEqualTo:firmaId)
          .where('aktif',isEqualTo:true).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Ogrenci bulunamadi','',Icons.school_outlined);
        return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;
              final sozlesme=d['sozlesmeDurum']??'bekliyor';
              final durumRenk=sozlesme=='imzalandi'?Colors.green:
              sozlesme=='bekliyor'?Colors.orange:Colors.grey;
              return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:durumRenk.withValues(alpha:0.2))),
                  child:Row(children:[
                    CircleAvatar(radius:20,backgroundColor:_navy.withValues(alpha:0.1),
                        child:Text((d['ad']??'?')[0].toUpperCase(),
                            style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                    const SizedBox(width:12),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                      Text((d['okul']??'').toString()+' – '+(d['sinif']??'').toString(),
                          style:TextStyle(fontSize:12,color:Colors.grey[500])),
                    ])),
                    Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                          decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Text('Sozlesme: '+sozlesme,style:TextStyle(fontSize:10,
                              fontWeight:FontWeight.bold,color:durumRenk))),
                      const SizedBox(height:4),
                      if(d['pdfUrl']!=null)GestureDetector(
                          onTap:()=>launchUrl(Uri.parse(d['pdfUrl'])),
                          child:const Row(mainAxisSize:MainAxisSize.min,children:[
                            Icon(Icons.picture_as_pdf_outlined,size:14,color:Colors.red),
                            SizedBox(width:4),
                            Text('Goruntule',style:TextStyle(fontSize:11,color:Colors.red)),
                          ])),
                    ]),
                  ]));
            });
      });
}

// ─────────────────────────────────────────────────────────────────
//  EVRAK RAPORU
// ─────────────────────────────────────────────────────────────────
class _EvrakRaporu extends StatelessWidget{
  final String firmaId;
  const _EvrakRaporu({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data as Map<String,dynamic>;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Evrak Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          // Sozlesme ozeti
          const Text('Sozlesme Durumu',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:10),
          Row(children:[
            _rKarti('Toplam Sozlesme',(data['sozlesmeToplam']??0).toString(),_navy,Icons.description_outlined),
            const SizedBox(width:12),
            _rKarti('Imzalandi',(data['sozlesmeImzalandi']??0).toString(),Colors.green,Icons.check_circle_outline),
            const SizedBox(width:12),
            _rKarti('Bekliyor',(data['sozlesmeBekliyor']??0).toString(),Colors.orange,Icons.pending_outlined),
            const SizedBox(width:12),
            _rKarti('Suresi Doldu',(data['sozlesmeSuresiDoldu']??0).toString(),Colors.red,Icons.timer_off_outlined),
          ]),
          const SizedBox(height:24),
          // Sofor evrak ozeti
          const Text('Sofor Evrak Durumu',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:10),
          Row(children:[
            _rKarti('Toplam Sofor',(data['soforToplam']??0).toString(),_navy,Icons.person_outlined),
            const SizedBox(width:12),
            _rKarti('Eksik Evrak',(data['soforEksik']??0).toString(),Colors.red,Icons.warning_outlined),
            const SizedBox(width:12),
            _rKarti('Bitis Yaklasan',(data['soforYaklasan']??0).toString(),Colors.orange,Icons.access_time_outlined),
          ]),
          const SizedBox(height:24),
          // Arac evrak ozeti
          const Text('Arac Evrak Durumu',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:10),
          Row(children:[
            _rKarti('Toplam Arac',(data['aracToplam']??0).toString(),_navy,Icons.directions_car_outlined),
            const SizedBox(width:12),
            _rKarti('Muayene Yaklasan',(data['muayeneYaklasan']??0).toString(),Colors.orange,Icons.car_repair_outlined),
            const SizedBox(width:12),
            _rKarti('Sigorta Yaklasan',(data['sigortaYaklasan']??0).toString(),Colors.red,Icons.shield_outlined),
          ]),
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      final results=await Future.wait([
        FirebaseFirestore.instance.collection('sozlesmeler').where('firmaId',isEqualTo:firmaId).get(),
        FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:firmaId).get(),
        FirebaseFirestore.instance.collection('vehicles').where('firmaId',isEqualTo:firmaId).get(),
      ]);
      final soz=results[0].docs;
      final sof=results[1].docs;
      final arac=results[2].docs;

      int sozBekliyor=0,sozImzalandi=0,sozSuresiDoldu=0;
      for(final d in soz){final dd=d.data() as Map<String,dynamic>;
      final dur=dd['durum']??'bekliyor';
      if(dur=='bekliyor')sozBekliyor++;
      else if(dur=='imzalandi')sozImzalandi++;
      else if(dur=='suresi_doldu')sozSuresiDoldu++;
      }

      int soforEksik=0,soforYaklasan=0;
      for(final d in sof){final dd=d.data() as Map<String,dynamic>;
      if((dd['ehliyetNo']??'').isEmpty||(dd['srcBelge']??'').isEmpty)soforEksik++;
      if(_yaklasiyor(dd['ehliyetBitisTarihi']??'')||_yaklasiyor(dd['srcBitisTarihi']??''))soforYaklasan++;
      }

      int muayeneYaklasan=0,sigortaYaklasan=0;
      for(final d in arac){final dd=d.data() as Map<String,dynamic>;
      if(_yaklasiyor(dd['muayeneTarihi']??''))muayeneYaklasan++;
      if(_yaklasiyor(dd['sigortaTarihi']??''))sigortaYaklasan++;
      }

      return{
        'sozlesmeToplam':soz.length,'sozlesmeBekliyor':sozBekliyor,
        'sozlesmeImzalandi':sozImzalandi,'sozlesmeSuresiDoldu':sozSuresiDoldu,
        'soforToplam':sof.length,'soforEksik':soforEksik,'soforYaklasan':soforYaklasan,
        'aracToplam':arac.length,'muayeneYaklasan':muayeneYaklasan,'sigortaYaklasan':sigortaYaklasan,
      };
    }catch(_){return{};}
  }

  static bool _yaklasiyor(String tarih){
    if(tarih.isEmpty)return false;
    try{
      final parts=tarih.split('.');
      if(parts.length<3)return false;
      final dt=DateTime(int.parse(parts[2]),int.parse(parts[1]),int.parse(parts[0]));
      return dt.difference(DateTime.now()).inDays<=30;
    }catch(_){return false;}
  }

  Widget _rKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}


// ─────────────────────────────────────────────────────────────────
//  FIYATLANDIRMA SEKMESI – Bolum 8 Tam Surum
// ─────────────────────────────────────────────────────────────────
class _FiyatlandirmaSekme extends StatefulWidget{
  final String firmaId;
  const _FiyatlandirmaSekme({required this.firmaId});
  @override State<_FiyatlandirmaSekme> createState()=>_FiyatlandirmaSekmeState();
}
class _FiyatlandirmaSekmeState extends State<_FiyatlandirmaSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  final List<(int,IconData,String)> _tabs=[
    (0,Icons.location_city_outlined,'Bolge/Mahalle'),
    (1,Icons.straighten_outlined,'KM Bazli'),
    (2,Icons.family_restroom_outlined,'Kardes Indirimi'),
    (3,Icons.star_outline,'Ozel Fiyatlar'),
    (4,Icons.trending_up_outlined,'Toplu Guncelleme'),
    (5,Icons.bar_chart_outlined,'Ucret Raporu'),
  ];

  @override Widget build(BuildContext context)=>Column(children:[
    // Tab bar
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:_tabs.map((t)=>GestureDetector(
            onTap:()=>setState(()=>_tab=t.$1),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),
                decoration:BoxDecoration(border:Border(bottom:BorderSide(
                    color:_tab==t.$1?_t:Colors.transparent,width:2))),
                child:Row(children:[
                  Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                  const SizedBox(width:6),
                  Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                      color:_tab==t.$1?_navy:Colors.grey)),
                ])))).toList()))),
    Expanded(child:[
      _BolgeMahalleFiyat(firmaId:widget.firmaId),
      _KmFiyat(firmaId:widget.firmaId),
      _KardesIndirim(firmaId:widget.firmaId),
      _OzelFiyatlar(firmaId:widget.firmaId),
      _TopluGuncelleme(firmaId:widget.firmaId),
      _UcretRaporu(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── BOLGE/MAHALLE FIYATI ─────────────────────────────────────────
class _BolgeMahalleFiyat extends StatefulWidget{
  final String firmaId;
  const _BolgeMahalleFiyat({required this.firmaId});
  @override State<_BolgeMahalleFiyat> createState()=>_BolgeMahalleFiyatState();
}
class _BolgeMahalleFiyatState extends State<_BolgeMahalleFiyat>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _bolgeCtrl=TextEditingController();
  final _fiyatCtrl=TextEditingController();
  final _aciklamaCtrl=TextEditingController();
  String _tip='bolge';
  String _filtre='hepsi';

  @override void dispose(){_bolgeCtrl.dispose();_fiyatCtrl.dispose();_aciklamaCtrl.dispose();super.dispose();}

  Future<void> _ekle() async{
    if(_bolgeCtrl.text.trim().isEmpty||_fiyatCtrl.text.trim().isEmpty)return;
    await FirebaseFirestore.instance.collection('fiyatlar').add({
      'firmaId':widget.firmaId,
      'bolge':_bolgeCtrl.text.trim(),
      'mahalle':_tip=='mahalle'?_bolgeCtrl.text.trim():'',
      'fiyat':double.tryParse(_fiyatCtrl.text)??0,
      'tip':_tip,
      'aciklama':_aciklamaCtrl.text.trim(),
      'aktif':true,
      'olusturmaTarihi':FieldValue.serverTimestamp(),
    });
    _bolgeCtrl.clear();_fiyatCtrl.clear();_aciklamaCtrl.clear();
    if(mounted)setState((){});
  }

  @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    // Sol: Liste
    Expanded(flex:3,child:Column(children:[
      // Filtre bar
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
          child:Row(children:[
            const Text('Fiyat Listesi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
            const Spacer(),
            for(final f in [('hepsi','Tumu'),('bolge','Bolge'),('mahalle','Mahalle')])
              GestureDetector(onTap:()=>setState(()=>_filtre=f.$1),
                  child:Container(margin:const EdgeInsets.only(left:6),
                      padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                      decoration:BoxDecoration(
                          color:_filtre==f.$1?_navy:Colors.grey[100],
                          borderRadius:BorderRadius.circular(8)),
                      child:Text(f.$2,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,
                          color:_filtre==f.$1?Colors.white:Colors.grey)))),
          ])),
      Expanded(child:StreamBuilder<QuerySnapshot>(
          stream:(){
            var q=FirebaseFirestore.instance.collection('fiyatlar')
                .where('firmaId',isEqualTo:widget.firmaId);
            if(_filtre!='hepsi')q=q.where('tip',isEqualTo:_filtre);
            return q.where('tip',isNotEqualTo:'km').orderBy('tip').snapshots();
          }(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Fiyat tanimlanmamis','Sagdan fiyat ekleyin.',Icons.payments_outlined);
            return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final tip=d['tip']??'bolge';
                  final renkMap={'bolge':Colors.blue,'mahalle':Colors.purple,'manuel':Colors.orange};
                  final renk=renkMap[tip]??Colors.green;
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:renk.withValues(alpha:0.2)),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                      child:Row(children:[
                        Container(padding:const EdgeInsets.all(8),
                            decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                            child:Icon(Icons.location_on_outlined,color:renk,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['bolge']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                          Row(children:[
                            Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                                decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
                                child:Text(tip,style:TextStyle(fontSize:10,color:renk,fontWeight:FontWeight.bold))),
                            if((d['aciklama']??'').isNotEmpty)...[
                              const SizedBox(width:6),
                              Text(d['aciklama'],style:TextStyle(fontSize:11,color:Colors.grey[500])),
                            ],
                          ]),
                        ])),
                        Text((d['fiyat']??0).toString()+' TL/ay',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:Colors.green)),
                        const SizedBox(width:10),
                        IconButton(
                            icon:const Icon(Icons.delete_outline,color:Colors.red,size:18),
                            onPressed:()=>FirebaseFirestore.instance.collection('fiyatlar').doc(docs[i].id).delete()),
                      ]));
                });
          })),
    ])),
    const VerticalDivider(width:1),
    // Sag: Form
    Container(width:300,padding:const EdgeInsets.all(24),color:Colors.white,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Yeni Fiyat Ekle',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:12),
          // Tip secici
          Row(children:[for(final t in [('bolge','Bolge'),('mahalle','Mahalle'),('manuel','Manuel')])
            Expanded(child:GestureDetector(onTap:()=>setState(()=>_tip=t.$1),
                child:Container(margin:const EdgeInsets.only(right:4),padding:const EdgeInsets.symmetric(vertical:8),
                    decoration:BoxDecoration(
                        color:_tip==t.$1?_navy:Colors.grey[50],
                        borderRadius:BorderRadius.circular(7),
                        border:Border.all(color:_tip==t.$1?_navy:Colors.grey.shade300)),
                    child:Center(child:Text(t.$2,style:TextStyle(fontSize:10,
                        color:_tip==t.$1?Colors.white:Colors.grey,
                        fontWeight:_tip==t.$1?FontWeight.bold:FontWeight.normal))))))]),
          const SizedBox(height:12),
          TextField(controller:_bolgeCtrl,
              decoration:InputDecoration(
                  labelText:_tip=='mahalle'?'Mahalle Adi *':'Bolge Adi *',
                  prefixIcon:const Icon(Icons.location_on_outlined,color:_navy,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:10),
          TextField(controller:_fiyatCtrl,keyboardType:TextInputType.number,
              decoration:InputDecoration(labelText:'Aylik Fiyat (TL) *',
                  prefixIcon:const Icon(Icons.payments_outlined,color:_navy,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:10),
          TextField(controller:_aciklamaCtrl,
              decoration:InputDecoration(labelText:'Aciklama (opsiyonel)',
                  prefixIcon:const Icon(Icons.notes_outlined,color:_navy,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,child:ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
                  padding:const EdgeInsets.symmetric(vertical:12)),
              onPressed:_ekle,
              icon:const Icon(Icons.add,size:16),label:const Text('Ekle'))),
        ])),
  ]);
}

// ── KM BAZLI FIYAT ───────────────────────────────────────────────
class _KmFiyat extends StatefulWidget{
  final String firmaId;
  const _KmFiyat({required this.firmaId});
  @override State<_KmFiyat> createState()=>_KmFiyatState();
}
class _KmFiyatState extends State<_KmFiyat>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _kmBasCtrl=TextEditingController();
  final _kmBitCtrl=TextEditingController();
  final _fiyatCtrl=TextEditingController();
  final _aciklamaCtrl=TextEditingController();

  @override void dispose(){_kmBasCtrl.dispose();_kmBitCtrl.dispose();_fiyatCtrl.dispose();_aciklamaCtrl.dispose();super.dispose();}

  Future<void> _ekle() async{
    final kmBas=double.tryParse(_kmBasCtrl.text)??0;
    final kmBit=double.tryParse(_kmBitCtrl.text)??0;
    final fiyat=double.tryParse(_fiyatCtrl.text)??0;
    if(fiyat==0)return;
    await FirebaseFirestore.instance.collection('fiyatlar').add({
      'firmaId':widget.firmaId,
      'bolge':_kmBasCtrl.text.trim()+'-'+_kmBitCtrl.text.trim()+' km',
      'kmBaslangic':kmBas,'kmBitis':kmBit,
      'fiyat':fiyat,'tip':'km',
      'aciklama':_aciklamaCtrl.text.trim(),
      'aktif':true,
      'olusturmaTarihi':FieldValue.serverTimestamp(),
    });
    _kmBasCtrl.clear();_kmBitCtrl.clear();_fiyatCtrl.clear();_aciklamaCtrl.clear();
  }

  @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(flex:3,child:Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
          child:const Row(children:[
            Icon(Icons.straighten_outlined,color:_navy,size:18),SizedBox(width:8),
            Text('KM Bazli Fiyat Araliklari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          ])),
      Expanded(child:StreamBuilder<QuerySnapshot>(
          stream:FirebaseFirestore.instance.collection('fiyatlar')
              .where('firmaId',isEqualTo:widget.firmaId)
              .where('tip',isEqualTo:'km')
              .orderBy('kmBaslangic').snapshots(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('KM bazli fiyat tanimlanmamis','Sagdan aralik ekleyin.',Icons.straighten_outlined);
            return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final kmBas=(d['kmBaslangic']??0).toString();
                  final kmBit=(d['kmBitis']??0).toString();
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:Colors.blue.withValues(alpha:0.2))),
                      child:Row(children:[
                        Container(padding:const EdgeInsets.all(8),
                            decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                            child:const Icon(Icons.route_outlined,color:Colors.blue,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(kmBas+' - '+kmBit+' km',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                          if((d['aciklama']??'').isNotEmpty)
                            Text(d['aciklama'],style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        ])),
                        Text((d['fiyat']??0).toString()+' TL/ay',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:Colors.green)),
                        const SizedBox(width:8),
                        IconButton(icon:const Icon(Icons.delete_outline,color:Colors.red,size:18),
                            onPressed:()=>FirebaseFirestore.instance.collection('fiyatlar').doc(docs[i].id).delete()),
                      ]));
                });
          })),
    ])),
    const VerticalDivider(width:1),
    Container(width:300,padding:const EdgeInsets.all(24),color:Colors.white,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('KM Araligi Ekle',style:TextStyle(fontSize:15,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:TextField(controller:_kmBasCtrl,keyboardType:TextInputType.number,
                decoration:InputDecoration(labelText:'Baslangic KM',
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                    isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
            const SizedBox(width:8),
            Expanded(child:TextField(controller:_kmBitCtrl,keyboardType:TextInputType.number,
                decoration:InputDecoration(labelText:'Bitis KM',
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                    isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
          ]),
          const SizedBox(height:10),
          TextField(controller:_fiyatCtrl,keyboardType:TextInputType.number,
              decoration:InputDecoration(labelText:'Aylik Fiyat (TL) *',
                  prefixIcon:const Icon(Icons.payments_outlined,color:_navy,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:10),
          TextField(controller:_aciklamaCtrl,
              decoration:InputDecoration(labelText:'Aciklama',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:14),
          Container(padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.05),borderRadius:BorderRadius.circular(8)),
              child:const Column(children:[
                Row(children:[Icon(Icons.info_outline,color:Colors.blue,size:14),SizedBox(width:6),
                  Expanded(child:Text('Ornek: 0-5 km: 4000 TL',style:TextStyle(fontSize:11,color:Colors.blue)))]),
                Row(children:[SizedBox(width:20),Expanded(child:Text('5-10 km: 5000 TL',style:TextStyle(fontSize:11,color:Colors.blue)))]),
                Row(children:[SizedBox(width:20),Expanded(child:Text('10-999 km: 6000 TL',style:TextStyle(fontSize:11,color:Colors.blue)))]),
              ])),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,child:ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
                  padding:const EdgeInsets.symmetric(vertical:12)),
              onPressed:_ekle,
              icon:const Icon(Icons.add,size:16),label:const Text('Aralik Ekle'))),
        ])),
  ]);
}

// ── KARDES INDIRIMI ─────────────────────────────────────────────
class _KardesIndirim extends StatefulWidget{
  final String firmaId;
  const _KardesIndirim({required this.firmaId});
  @override State<_KardesIndirim> createState()=>_KardesIndirimState();
}
class _KardesIndirimState extends State<_KardesIndirim>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  // Kardes indirimi ayarlari
  bool _aktif=false;
  double _ikinci=10; // %
  double _ucuncu=15;
  double _dorduncu=20;
  bool _yuklendi=false;

  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async{
    try{
      final snap=await FirebaseFirestore.instance.collection('firma_ayarlari')
          .doc(widget.firmaId).get();
      if(snap.exists){
        final d=snap.data()!;
        setState((){
          _aktif=d['kardesIndirimAktif']??false;
          _ikinci=(d['kardesIndirim2']??10).toDouble();
          _ucuncu=(d['kardesIndirim3']??15).toDouble();
          _dorduncu=(d['kardesIndirim4']??20).toDouble();
          _yuklendi=true;
        });
      }else setState(()=>_yuklendi=true);
    }catch(_){setState(()=>_yuklendi=true);}
  }

  Future<void> _kaydet() async{
    await FirebaseFirestore.instance.collection('firma_ayarlari')
        .doc(widget.firmaId).set({
      'kardesIndirimAktif':_aktif,
      'kardesIndirim2':_ikinci,
      'kardesIndirim3':_ucuncu,
      'kardesIndirim4':_dorduncu,
    },SetOptions(merge:true));
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Kardes indirimleri kaydedildi'),backgroundColor:Colors.green,
        behavior:SnackBarBehavior.floating));
  }

  @override Widget build(BuildContext context){
    if(!_yuklendi)return const Center(child:CircularProgressIndicator());
    return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
      // Baslik
      Row(children:[
        const Icon(Icons.family_restroom_outlined,color:_navy,size:22),
        const SizedBox(width:10),
        const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Kardes Indirimi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          Text('Ayni aileden birden fazla ogrenci varsa indirim uygulayin.',
              style:TextStyle(fontSize:12,color:Colors.grey)),
        ])),
        Switch(value:_aktif,activeThumbColor:_t,onChanged:(v)=>setState(()=>_aktif=v)),
        Text(_aktif?'Aktif':'Pasif',style:TextStyle(fontWeight:FontWeight.bold,
            color:_aktif?Colors.green:Colors.grey)),
      ]),
      const SizedBox(height:24),
      // Indirim oranlari
      Container(padding:const EdgeInsets.all(20),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
          child:Column(children:[
            _indirimSatir('1. Ogrenci (Tam Ucret)',null,100,null),
            const Divider(),
            _indirimSatir('2. Ogrenci',Icons.child_care_outlined,_ikinci,(v)=>setState(()=>_ikinci=v)),
            const Divider(),
            _indirimSatir('3. Ogrenci',Icons.child_care_outlined,_ucuncu,(v)=>setState(()=>_ucuncu=v)),
            const Divider(),
            _indirimSatir('4. ve sonrasi',Icons.child_care_outlined,_dorduncu,(v)=>setState(()=>_dorduncu=v)),
          ])),
      const SizedBox(height:24),
      // Ornek hesap
      Container(padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:_navy.withValues(alpha:0.04),borderRadius:BorderRadius.circular(12),
              border:Border.all(color:_navy.withValues(alpha:0.1))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Ornek Hesap (Aylik Ucret: 5000 TL)',
                style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
            const SizedBox(height:10),
            _ornek('1. Cocuk',5000,0),
            _ornek('2. Cocuk',5000,_ikinci),
            _ornek('3. Cocuk',5000,_ucuncu),
            _ornek('4. Cocuk',5000,_dorduncu),
          ])),
      const SizedBox(height:24),
      ElevatedButton.icon(
          style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
              padding:const EdgeInsets.symmetric(horizontal:24,vertical:12)),
          onPressed:_kaydet,
          icon:const Icon(Icons.save_outlined,size:16),
          label:const Text('Ayarlari Kaydet')),
    ]));
  }

  Widget _indirimSatir(String baslik,IconData? ikon,double oran,ValueChanged<double>? onChange)=>
      Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[
        if(ikon!=null)Icon(ikon,size:18,color:Colors.purple)
        else const Icon(Icons.person_outlined,size:18,color:Colors.grey),
        const SizedBox(width:10),
        Expanded(child:Text(baslik,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14))),
        if(onChange==null)
          const Text('Tam Ucret',style:TextStyle(fontSize:13,color:Colors.grey))
        else Row(children:[
          Text('%'+oran.round().toString()+' indirim',
              style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14,color:Colors.purple)),
          const SizedBox(width:12),
          SizedBox(width:120,child:Slider(
              value:oran,min:0,max:50,divisions:50,activeColor:Colors.purple,
              onChanged:onChange??(_){})),
        ]),
      ]));

  Widget _ornek(String baslik,double ucret,double indirim)=>Padding(
      padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[
    Expanded(child:Text(baslik,style:const TextStyle(fontSize:12))),
    if(indirim>0)Text('%'+indirim.round().toString()+' indirim → ',
        style:const TextStyle(fontSize:11,color:Colors.purple)),
    Text((ucret*(1-indirim/100)).round().toString()+' TL',
        style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,
            color:indirim>0?Colors.green:Colors.grey[700])),
  ]));
}

// ── OZEL FIYATLAR ───────────────────────────────────────────────
class _OzelFiyatlar extends StatefulWidget{
  final String firmaId;
  const _OzelFiyatlar({required this.firmaId});
  @override State<_OzelFiyatlar> createState()=>_OzelFiyatlarState();
}
class _OzelFiyatlarState extends State<_OzelFiyatlar>{
  static const _navy=Color(0xFF1a3a6b);
  final _aramaCtrl=TextEditingController();
  String _arama='';

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.all(16),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(controller:_aramaCtrl,
              onChanged:(v)=>setState(()=>_arama=v.toLowerCase()),
              decoration:InputDecoration(
                  hintText:'Ogrenci ara...',
                  prefixIcon:const Icon(Icons.search,size:18,color:Colors.grey),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('students')
            .where('firmaId',isEqualTo:widget.firmaId)
            .orderBy('ad').snapshots(),
        builder:(_,snap){
          var docs=snap.data?.docs??[];
          if(_arama.isNotEmpty){
            docs=docs.where((d){
              final data=d.data() as Map<String,dynamic>;
              return (data['ad']??'').toString().toLowerCase().contains(_arama);
            }).toList();
          }
          if(docs.isEmpty)return _bos('Ogrenci bulunamadi','',Icons.school_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ogrenciFiyat=(d['fiyat']??d['ucret']??0) as num;
                return Container(margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      CircleAvatar(radius:20,backgroundColor:_navy.withValues(alpha:0.1),
                          child:Text((d['ad']??'?')[0].toUpperCase(),
                              style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Text((d['adres']??'').toString(),
                            style:TextStyle(fontSize:11,color:Colors.grey[500]),
                            maxLines:1,overflow:TextOverflow.ellipsis),
                      ])),
                      GestureDetector(
                        onTap:()=>_ozelFiyatDialog(context,docs[i].id,d['ad']??'',ogrenciFiyat.toDouble()),
                        child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                            decoration:BoxDecoration(
                                color:ogrenciFiyat>0?Colors.green.withValues(alpha:0.1):Colors.grey.withValues(alpha:0.08),
                                borderRadius:BorderRadius.circular(8),
                                border:Border.all(color:ogrenciFiyat>0?Colors.green.withValues(alpha:0.3):Colors.grey.withValues(alpha:0.2))),
                            child:Row(children:[
                              Text(ogrenciFiyat>0?ogrenciFiyat.toString()+' TL':'Fiyat Yok',
                                  style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,
                                      color:ogrenciFiyat>0?Colors.green:Colors.grey)),
                              const SizedBox(width:6),
                              Icon(Icons.edit_outlined,size:14,
                                  color:ogrenciFiyat>0?Colors.green:Colors.grey),
                            ])),
                      ),
                    ]));
              });
        })),
  ]);

  void _ozelFiyatDialog(BuildContext context,String ogrId,String ogrAd,double mevcutFiyat){
    final fCtrl=TextEditingController(text:mevcutFiyat>0?mevcutFiyat.toStringAsFixed(0):'');
    final sCtrl=TextEditingController();
    showDialog(context:context,builder:(_)=>AlertDialog(
        title:Text(ogrAd+' – Ozel Fiyat'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:fCtrl,keyboardType:TextInputType.number,
              decoration:InputDecoration(labelText:'Aylik Ucret (TL)',
                  prefixIcon:const Icon(Icons.payments_outlined,color:_navy,size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true)),
          const SizedBox(height:10),
          TextField(controller:sCtrl,
              decoration:InputDecoration(labelText:'Sebep (opsiyonel)',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true)),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(_),child:const Text('Iptal')),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                final fiyat=double.tryParse(fCtrl.text)??0;
                await FirebaseFirestore.instance.collection('students').doc(ogrId).update({
                  'fiyat':fiyat,'ucret':fiyat,
                  'ozelFiyatSebep':sCtrl.text.trim(),
                  'ozelFiyatTarihi':FieldValue.serverTimestamp(),
                });
                if(context.mounted)Navigator.pop(context);
              },
              icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ]));
  }
}

// ── TOPLU GUNCELLEME ─────────────────────────────────────────────
class _TopluGuncelleme extends StatefulWidget{
  final String firmaId;
  const _TopluGuncelleme({required this.firmaId});
  @override State<_TopluGuncelleme> createState()=>_TopluGuncellemeState();
}
class _TopluGuncellemeState extends State<_TopluGuncelleme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  double _zamOrani=10;
  String _islem='zam'; // 'zam' veya 'indirim'
  String _hedef='fiyatlar'; // 'fiyatlar' veya 'ogrenciler'
  bool _yukleniyor=false;

  Future<void> _uygula(BuildContext context) async{
    final onay=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(
        title:const Text('Toplu Guncelleme'),
        content:Text((_islem=='zam'?'%'+_zamOrani.round().toString()+' ZAM':'%'+_zamOrani.round().toString()+' INDIRIM')+
            ' uygulanacak.\n\nHedef: '+(_hedef=='fiyatlar'?'Fiyat listesi (yeni kayitlar etkilenir)':'Mevcut ogrenciler')+
            '\n\nOnaylananmis sozlesmelerdeki ucretler degismeyecek.\n\nDevam?'),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(_,false),child:const Text('Iptal')),
          ElevatedButton(style:ElevatedButton.styleFrom(backgroundColor:Colors.orange),
              onPressed:()=>Navigator.pop(_,true),
              child:const Text('Evet, Uygula',style:TextStyle(color:Colors.white))),
        ]));

    if(onay!=true)return;
    setState(()=>_yukleniyor=true);

    try{
      final carp=_islem=='zam'?(1+_zamOrani/100):(1-_zamOrani/100);
      final kolleksiyon=_hedef=='fiyatlar'?'fiyatlar':'students';
      final snap=await FirebaseFirestore.instance.collection(kolleksiyon)
          .where('firmaId',isEqualTo:widget.firmaId).get();

      // Batch write ile guncelle
      var batch=FirebaseFirestore.instance.batch();
      int count=0;
      for(final doc in snap.docs){
        final d=doc.data() as Map<String,dynamic>;
        // Kilitli sozlesmesi olanlari atla
        if(_hedef=='students'&&d['sozlesmeKilitli']==true)continue;
        final mevcutFiyat=(d['fiyat'] as num?)?.toDouble()??0;
        if(mevcutFiyat==0)continue;
        final yeniFiyat=(mevcutFiyat*carp).round().toDouble();
        batch.update(doc.reference,{
          'fiyat':yeniFiyat,
          if(_hedef=='students')'ucret':yeniFiyat,
          'topluGuncelleme':FieldValue.serverTimestamp(),
        });
        count++;
        if(count%500==0){await batch.commit();batch=FirebaseFirestore.instance.batch();}
      }
      await batch.commit();
      if(context.mounted){
        setState(()=>_yukleniyor=false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:Text(count.toString()+' kayit guncellendi.'),
            backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));
      }
    }catch(e){
      setState(()=>_yukleniyor=false);
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('Hata: '+e.toString()),backgroundColor:Colors.red));
    }
  }

  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Text('Toplu Fiyat Guncelleme',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
    const SizedBox(height:8),
    Container(padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8),
            border:Border.all(color:Colors.orange.withValues(alpha:0.3))),
        child:const Row(children:[
          Icon(Icons.warning_amber_outlined,color:Colors.orange,size:18),SizedBox(width:8),
          Expanded(child:Text('Toplu guncelleme onaylanmis sozlesmelerdeki ucretleri etkilemez. Sadece secilen hedefe uygulanir.',
              style:TextStyle(fontSize:12,color:Colors.orange))),
        ])),
    const SizedBox(height:24),
    // Islem tipi
    const Text('Islem Tipi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
    const SizedBox(height:10),
    Row(children:[
      Expanded(child:GestureDetector(onTap:()=>setState(()=>_islem='zam'),
          child:Container(padding:const EdgeInsets.symmetric(vertical:14),
              decoration:BoxDecoration(
                  color:_islem=='zam'?Colors.red.withValues(alpha:0.1):Colors.grey[50],
                  borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:_islem=='zam'?Colors.red:Colors.grey.shade300)),
              child:Column(children:[
                Icon(Icons.trending_up_outlined,color:_islem=='zam'?Colors.red:Colors.grey,size:24),
                const SizedBox(height:4),
                Text('ZAM',style:TextStyle(fontWeight:FontWeight.bold,
                    color:_islem=='zam'?Colors.red:Colors.grey)),
              ])))),
      const SizedBox(width:12),
      Expanded(child:GestureDetector(onTap:()=>setState(()=>_islem='indirim'),
          child:Container(padding:const EdgeInsets.symmetric(vertical:14),
              decoration:BoxDecoration(
                  color:_islem=='indirim'?Colors.green.withValues(alpha:0.1):Colors.grey[50],
                  borderRadius:BorderRadius.circular(10),
                  border:Border.all(color:_islem=='indirim'?Colors.green:Colors.grey.shade300)),
              child:Column(children:[
                Icon(Icons.trending_down_outlined,color:_islem=='indirim'?Colors.green:Colors.grey,size:24),
                const SizedBox(height:4),
                Text('INDIRIM',style:TextStyle(fontWeight:FontWeight.bold,
                    color:_islem=='indirim'?Colors.green:Colors.grey)),
              ])))),
    ]),
    const SizedBox(height:24),
    // Oran slider
    Row(children:[
      const Text('Oran:',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
      const SizedBox(width:10),
      Text('%'+_zamOrani.round().toString(),
          style:TextStyle(fontSize:24,fontWeight:FontWeight.bold,
              color:_islem=='zam'?Colors.red:Colors.green)),
    ]),
    Slider(value:_zamOrani,min:1,max:50,divisions:49,
        activeColor:_islem=='zam'?Colors.red:Colors.green,
        onChanged:(v)=>setState(()=>_zamOrani=v)),
    const SizedBox(height:24),
    // Hedef
    const Text('Guncelleme Hedefi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
    const SizedBox(height:10),
    ...[(('fiyatlar','Fiyat Listesi','Yeni kayitlara uygulanir, mevcut ogrenciler etkilenmez')),
      (('ogrenciler','Mevcut Ogrenciler','Sozlesmesi kilitlenmemis ogrencilerin ucreti guncellenir'))].map((h)=>
        GestureDetector(onTap:()=>setState(()=>_hedef=h.$1),
            child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(
                    color:_hedef==h.$1?_navy.withValues(alpha:0.05):Colors.white,
                    borderRadius:BorderRadius.circular(10),
                    border:Border.all(color:_hedef==h.$1?_navy:Colors.grey.shade200)),
                child:Row(children:[
                  Radio<String>(value:h.$1,groupValue:_hedef,activeColor:_t,
                      onChanged:(v)=>setState(()=>_hedef=v??h.$1)),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(h.$2,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:14)),
                    Text(h.$3,style:TextStyle(fontSize:11,color:Colors.grey[500])),
                  ])),
                ])))),
    const SizedBox(height:24),
    SizedBox(width:double.infinity,child:ElevatedButton.icon(
        style:ElevatedButton.styleFrom(
            backgroundColor:_islem=='zam'?Colors.red:Colors.green,
            foregroundColor:Colors.white,
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
            padding:const EdgeInsets.symmetric(vertical:14)),
        onPressed:_yukleniyor?null:()=>_uygula(context),
        icon:_yukleniyor?const SizedBox(width:16,height:16,
            child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):
        Icon(_islem=='zam'?Icons.trending_up_outlined:Icons.trending_down_outlined,size:18),
        label:Text(_yukleniyor?'Guncelleniyor...':
        '%'+_zamOrani.round().toString()+(_islem=='zam'?' ZAM UYGULA':' INDIRIM UYGULA')))),
  ]));
}

// ── UCRET RAPORU ─────────────────────────────────────────────────
class _UcretRaporu extends StatelessWidget{
  final String firmaId;
  const _UcretRaporu({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('students')
          .where('firmaId',isEqualTo:firmaId)
          .where('aktif',isEqualTo:true).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Ogrenci verisi yok','Ogrenci eklendiginde rapor olusur.',Icons.bar_chart_outlined);

        double toplam=0,enYuksek=0,enDusuk=double.infinity;
        final Map<String,List<double>> bolgeMap={};
        for(final doc in docs){
          final d=doc.data() as Map<String,dynamic>;
          final fiyat=(d['fiyat']??d['ucret']??0) as num;
          if(fiyat==0)continue;
          final f=fiyat.toDouble();
          toplam+=f;
          if(f>enYuksek)enYuksek=f;
          if(f<enDusuk)enDusuk=f;
          final bolge=(d['bolge']??d['mahalle']??'Belirsiz').toString();
          bolgeMap.putIfAbsent(bolge,()=>[]);
          bolgeMap[bolge]!.add(f);
        }
        final sayim=docs.where((d)=>(d.data() as Map)['fiyat']!=null&&(d.data() as Map)['fiyat']!=0).length;
        final ortalama=sayim>0?toplam/sayim:0;

        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Ucret Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          // Ozet kartlar
          Row(children:[
            _rKarti('Ortalama Ucret',ortalama.round().toString()+' TL',_navy,Icons.calculate_outlined),
            const SizedBox(width:12),
            _rKarti('En Yuksek',enYuksek.round().toString()+' TL',Colors.red,Icons.arrow_upward_outlined),
            const SizedBox(width:12),
            _rKarti('En Dusuk',(enDusuk==double.infinity?0:enDusuk).round().toString()+' TL',Colors.green,Icons.arrow_downward_outlined),
            const SizedBox(width:12),
            _rKarti('Toplam Gelir (Aylik)',toplam.round().toString()+' TL',Colors.teal,Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height:24),
          // Bolge dagilimi
          if(bolgeMap.isNotEmpty)...[
            const Text('Bolge/Mahalle Ucret Dagilimi',
                style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:bolgeMap.entries.map((e){
                  final ort=e.value.isEmpty?0:(e.value.reduce((a,b)=>a+b)/e.value.length);
                  return Padding(padding:const EdgeInsets.only(bottom:10),child:Row(children:[
                    SizedBox(width:150,child:Text(e.key,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600),
                        maxLines:1,overflow:TextOverflow.ellipsis)),
                    const SizedBox(width:10),
                    Text(e.value.length.toString()+' ogrenci',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                    const Spacer(),
                    Text(ort.round().toString()+' TL ort.',
                        style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold,color:_navy)),
                  ]));
                }).toList())),
          ],
        ]));
      });

  Widget _rKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:20),const SizedBox(height:8),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:17,color:r)),
        const SizedBox(height:2),
        Text(b,style:const TextStyle(fontSize:11,color:Colors.grey)),
      ])));
}


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
// ─────────────────────────────────────────────────────────────────
//  PLAKA / QR / KOLEJ GIRIS SISTEMI – Bolum 15
// ─────────────────────────────────────────────────────────────────
class _PlakaTanimaSekme extends StatefulWidget{
  final String firmaId;
  const _PlakaTanimaSekme({required this.firmaId});
  @override State<_PlakaTanimaSekme> createState()=>_PlakaTanimaSekmeState();
}
class _PlakaTanimaSekmeState extends State<_PlakaTanimaSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    // Tab bar
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.camera_alt_outlined,'Plaka Kayitlari'),
            (1,Icons.qr_code_outlined,'QR Kayitlari'),
            (2,Icons.school_outlined,'Kolej Yonetimi'),
            (3,Icons.check_circle_outline,'Gelen Servisler'),
            (4,Icons.cancel_outlined,'Gelmeyen'),
            (5,Icons.bar_chart_outlined,'Raporlar'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _PlakaKayitlari(firmaId:widget.firmaId),
      _QrKayitlari(firmaId:widget.firmaId),
      _KolejYonetimWeb(firmaId:widget.firmaId),
      _GelenServisler(firmaId:widget.firmaId),
      _GelmeyanServisler(firmaId:widget.firmaId),
      _GirisRaporlari(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── PLAKA KAYITLARI ──────────────────────────────────────────────
class _PlakaKayitlari extends StatelessWidget{
  final String firmaId;
  const _PlakaKayitlari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:Row(children:[
          const Text('Plaka Kayitlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
              child:const Row(children:[
                Icon(Icons.circle,size:8,color:Colors.green),SizedBox(width:6),
                Text('Sistem Aktif',style:TextStyle(fontSize:11,color:Colors.green,fontWeight:FontWeight.bold)),
              ])),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('plate_logs')
            .where('firmaId',isEqualTo:firmaId)
            .orderBy('tarih',descending:true).limit(100).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Plaka kaydi yok',
              'Araclar okul girisinde otomatik kayit olusturacak.',Icons.camera_alt_outlined);
          // Bugun kac giris
          final bugun=DateTime.now();
          final bugunSay=docs.where((d){
            final ts=d['tarih'];
            if(ts is!Timestamp)return false;
            final dt=ts.toDate();
            return dt.year==bugun.year&&dt.month==bugun.month&&dt.day==bugun.day;
          }).length;
          return Column(children:[
            Container(margin:const EdgeInsets.all(16),padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                child:Row(children:[
                  _ozKarti('Bugun',bugunSay.toString(),Colors.green),
                  _ozKarti('Toplam',docs.length.toString(),_navy),
                  _ozKarti('Eslesti',docs.where((d)=>(d.data() as Map)['eslesti']==true).length.toString(),Colors.teal),
                  _ozKarti('Uyari',docs.where((d)=>(d.data() as Map)['eslesti']!=true).length.toString(),Colors.red),
                ])),
            Expanded(child:ListView.builder(
                padding:const EdgeInsets.symmetric(horizontal:16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final esl=d['eslesti']==true;
                  final ts=d['tarih'];
                  String tarihStr='';
                  if(ts is Timestamp){final dt=ts.toDate();
                  tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                      dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:(esl?Colors.green:Colors.red).withValues(alpha:0.2)),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                      child:Row(children:[
                        Container(padding:const EdgeInsets.all(10),
                            decoration:BoxDecoration(
                                color:(esl?Colors.green:Colors.red).withValues(alpha:0.1),
                                borderRadius:BorderRadius.circular(10)),
                            child:Icon(Icons.directions_car_outlined,
                                color:esl?Colors.green:Colors.red,size:22)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['plaka']??'',style:const TextStyle(fontWeight:FontWeight.bold,
                              fontSize:16,letterSpacing:1.2)),
                          if((d['soforAd']??'').isNotEmpty)
                            Text(d['soforAd'],style:TextStyle(fontSize:12,color:Colors.grey[500])),
                          if((d['projeAd']??'').isNotEmpty)
                            Text(d['projeAd'],style:TextStyle(fontSize:11,color:Colors.grey[400])),
                        ])),
                        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                              decoration:BoxDecoration(
                                  color:(esl?Colors.green:Colors.red).withValues(alpha:0.1),
                                  borderRadius:BorderRadius.circular(6)),
                              child:Text(esl?'Eslesti':'Uyari',style:TextStyle(fontSize:10,
                                  fontWeight:FontWeight.bold,color:esl?Colors.green:Colors.red))),
                          const SizedBox(height:4),
                          Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                        ]),
                      ]));
                })),
          ]);
        })),
  ]);

  Widget _ozKarti(String b,String v,Color r)=>Expanded(child:Column(children:[
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
    Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));
}

// ── QR KAYITLARI ─────────────────────────────────────────────────
class _QrKayitlari extends StatelessWidget{
  final String firmaId;
  const _QrKayitlari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:Row(children:[
          const Text('QR Giris Kayitlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:()=>Navigator.pushNamed(context,'/qr_olustur'),
              icon:const Icon(Icons.qr_code_2_outlined,size:16),
              label:const Text('QR Olustur')),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('okul_girisler')
            .where('firmaId',isEqualTo:firmaId)
            .orderBy('girisSaati',descending:true).limit(100).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('QR kaydi yok',
              'Okul girisi QR okutma ile kayit olusacak.',Icons.qr_code_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ts=d['girisSaati'];
                String tarihStr=d['girisSaatiStr']??'';
                if(tarihStr.isEmpty&&ts is Timestamp){
                  final dt=ts.toDate();
                  tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                      dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');
                }
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:Colors.teal.withValues(alpha:0.2))),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:Colors.teal.withValues(alpha:0.1),
                              borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.qr_code_outlined,color:Colors.teal,size:20)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['plaka']??d['servisAd']??'QR Giris',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Text(d['soforAd']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        Text(d['projeAd']??'',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                      ])),
                      Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                        const Text('QR',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Colors.teal)),
                        Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                      ]),
                    ]));
              });
        })),
  ]);
}

// ── KOLEJ YONETIM WEB ────────────────────────────────────────────
class _KolejYonetimWeb extends StatelessWidget{
  final String firmaId;
  const _KolejYonetimWeb({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Kolej Yonetim Modulu',
            style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Kolej yonetimi icin ayri panel mevcuttur.',
            style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:20),
        // Hizli erisim kartlari
        Row(children:[
          _akcKarti(context,'Kolej Panelini Ac',Icons.open_in_new_outlined,Colors.blue,()=>Navigator.pushNamed(context,'/web_kolej')),
          const SizedBox(width:12),
          _akcKarti(context,'QR Olustur',Icons.qr_code_2_outlined,Colors.teal,()=>Navigator.pushNamed(context,'/qr_olustur')),
          const SizedBox(width:12),
          _akcKarti(context,'QR Afis',Icons.picture_as_pdf_outlined,Colors.orange,()=>Navigator.pushNamed(context,'/qr_afis')),
        ]),
        const SizedBox(height:24),
        // Bugunun ozeti
        const Text('Bugunun Ozeti',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
        const SizedBox(height:10),
        FutureBuilder<Map<String,int>>(
            future:_bugunOzet(),
            builder:(_,snap){
              final data=snap.data??{};
              return Row(children:[
                _ozKarti('Gelen Servis',(data['gelen']??0).toString(),Colors.green,Icons.check_circle_outline),
                const SizedBox(width:12),
                _ozKarti('Beklenen',(data['beklenen']??0).toString(),_navy,Icons.directions_bus_outlined),
                const SizedBox(width:12),
                _ozKarti('Gelmeyen',(data['gelmeyen']??0).toString(),Colors.red,Icons.cancel_outlined),
              ]);
            }),
        const SizedBox(height:24),
        // Son girisler
        const Text('Son Girisler',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
        const SizedBox(height:10),
        StreamBuilder<QuerySnapshot>(
            stream:FirebaseFirestore.instance.collection('plate_logs')
                .where('firmaId',isEqualTo:firmaId)
                .where('eslesti',isEqualTo:true)
                .orderBy('tarih',descending:true).limit(5).snapshots(),
            builder:(_,snap){
              final docs=snap.data?.docs??[];
              if(docs.isEmpty)return const Text('Giris kaydi yok',style:TextStyle(color:Colors.grey));
              return Column(children:docs.map((doc){
                final d=doc.data() as Map<String,dynamic>;
                final ts=d['tarih'];
                String saat='';
                if(ts is Timestamp){final dt=ts.toDate();
                saat=dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border.all(color:Colors.green.withValues(alpha:0.2))),
                    child:Row(children:[
                      const Icon(Icons.check_circle_outline,color:Colors.green,size:18),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['plaka']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(d['soforAd']??'',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ])),
                      Text(saat,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Colors.green)),
                    ]));
              }).toList());
            }),
      ]));

  Future<Map<String,int>> _bugunOzet() async{
    try{
      final bugun=DateTime.now();
      final bugunStart=Timestamp.fromDate(DateTime(bugun.year,bugun.month,bugun.day));
      final girisSnap=await FirebaseFirestore.instance.collection('plate_logs')
          .where('firmaId',isEqualTo:firmaId)
          .where('eslesti',isEqualTo:true)
          .where('tarih',isGreaterThanOrEqualTo:bugunStart).get();
      final beklenenSnap=await FirebaseFirestore.instance.collection('services')
          .where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).count().get();
      final gelen=girisSnap.docs.length;
      final beklenen=beklenenSnap.count??0;
      return{'gelen':gelen,'beklenen':beklenen,'gelmeyen':beklenen-gelen<0?0:beklenen-gelen};
    }catch(_){return{};}
  }

  Widget _akcKarti(BuildContext context,String b,IconData i,Color r,VoidCallback onTap)=>
      Expanded(child:GestureDetector(onTap:onTap,child:Container(
          padding:const EdgeInsets.all(16),
          decoration:BoxDecoration(color:r.withValues(alpha:0.08),borderRadius:BorderRadius.circular(14),
              border:Border.all(color:r.withValues(alpha:0.2))),
          child:Column(children:[
            Icon(i,color:r,size:28),const SizedBox(height:8),
            Text(b,style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:r),
                textAlign:TextAlign.center),
          ]))));

  Widget _ozKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:20,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}

// ── GELEN SERVISLER ──────────────────────────────────────────────
class _GelenServisler extends StatelessWidget{
  final String firmaId;
  const _GelenServisler({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    final bugun=DateTime.now();
    final bugunStart=Timestamp.fromDate(DateTime(bugun.year,bugun.month,bugun.day));
    return Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
          child:Row(children:[
            const Icon(Icons.check_circle_outline,color:Colors.green,size:18),const SizedBox(width:8),
            const Text('Bugun Gelen Servisler',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.green,fontSize:15)),
          ])),
      Expanded(child:StreamBuilder<QuerySnapshot>(
          stream:FirebaseFirestore.instance.collection('plate_logs')
              .where('firmaId',isEqualTo:firmaId)
              .where('eslesti',isEqualTo:true)
              .where('tarih',isGreaterThanOrEqualTo:bugunStart)
              .orderBy('tarih',descending:false).snapshots(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Henuz gelen servis yok','Araclar plaka ile dogrulandikca burada gorunur.',Icons.check_circle_outline);
            return ListView.builder(
                padding:const EdgeInsets.all(16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final ts=d['tarih'];
                  String saat='';
                  if(ts is Timestamp){final dt=ts.toDate();
                  saat=dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border(left:BorderSide(color:Colors.green,width:4)),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                      child:Row(children:[
                        Container(padding:const EdgeInsets.all(8),
                            decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                            child:const Icon(Icons.directions_car_outlined,color:Colors.green,size:20)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['plaka']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,letterSpacing:1)),
                          Text(d['soforAd']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                          Text(d['projeAd']??d['servisAd']??'',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                        ])),
                        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                          Text(saat,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:Colors.green)),
                          Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                              decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                              child:const Text('Geldi',style:TextStyle(fontSize:10,color:Colors.green,fontWeight:FontWeight.bold))),
                        ]),
                      ]));
                });
          })),
    ]);
  }
}

// ── GELMEYEN SERVISLER ───────────────────────────────────────────
class _GelmeyanServisler extends StatelessWidget{
  final String firmaId;
  const _GelmeyanServisler({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:const Row(children:[
          Icon(Icons.cancel_outlined,color:Colors.red,size:18),SizedBox(width:8),
          Text('Gelmeyen Servisler',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.red,fontSize:15)),
        ])),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(
        future:_gelmeyen(),
        builder:(_,snap){
          final docs=snap.data??[];
          if(docs.isEmpty)return _bos('Tum servisler geldi!','',Icons.check_circle_outline);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i];
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border(left:BorderSide(color:Colors.red,width:4)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.directions_bus_outlined,color:Colors.red,size:20)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Text(d['aracPlaka']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        Text(d['soforAd']??'',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                      ])),
                      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
                          decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:const Text('Gelmedi',style:TextStyle(fontSize:11,color:Colors.red,fontWeight:FontWeight.bold))),
                    ]));
              });
        })),
  ]);

  Future<List<Map<String,dynamic>>> _gelmeyen() async{
    try{
      final bugun=DateTime.now();
      final bugunStart=Timestamp.fromDate(DateTime(bugun.year,bugun.month,bugun.day));
      // Bugun gelen plakalar
      final girisSnap=await FirebaseFirestore.instance.collection('plate_logs')
          .where('firmaId',isEqualTo:firmaId).where('eslesti',isEqualTo:true)
          .where('tarih',isGreaterThanOrEqualTo:bugunStart).get();
      final gelenPlakalar=girisSnap.docs.map((d)=>(d.data() as Map)['plaka']??'').toSet();
      // Aktif servisler
      final servisSnap=await FirebaseFirestore.instance.collection('services')
          .where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).get();
      // Plakasi gelenlerden cikar
      return servisSnap.docs
          .map((d)=>{...d.data() as Map<String,dynamic>,'id':d.id})
          .where((s)=>!gelenPlakalar.contains(s['aracPlaka']??''))
          .toList();
    }catch(_){return[];}
  }
}

// ── GIRIS RAPORLARI ──────────────────────────────────────────────
class _GirisRaporlari extends StatelessWidget{
  final String firmaId;
  const _GirisRaporlari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data!;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Giris Raporlari',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _rKarti('Bugun Gelen',(data['bugunGelen']??0).toString(),Colors.green,Icons.today_outlined),
            const SizedBox(width:12),
            _rKarti('Bu Hafta',(data['haftaGelen']??0).toString(),_navy,Icons.date_range_outlined),
            const SizedBox(width:12),
            _rKarti('Toplam Giris',(data['toplamGiris']??0).toString(),Colors.teal,Icons.bar_chart_outlined),
            const SizedBox(width:12),
            _rKarti('Ort. Varis Saati',data['ortVaris']??'-',Colors.orange,Icons.access_time_outlined),
          ]),
          const SizedBox(height:24),
          // Gunluk dagilim
          if((data['gunlukDagilim'] as List).isNotEmpty)...[
            const Text('Son 7 Gun Giris Dagilimi',
                style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:(data['gunlukDagilim'] as List<Map<String,dynamic>>).map((g)=>
                    Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
                      SizedBox(width:80,child:Text(g['tarih'],
                          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                      const SizedBox(width:10),
                      Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                          child:LinearProgressIndicator(
                              value:(g['oran'] as double).clamp(0.0,1.0),minHeight:8,
                              backgroundColor:Colors.grey.withValues(alpha:0.1),
                              valueColor:const AlwaysStoppedAnimation<Color>(Colors.green)))),
                      const SizedBox(width:10),
                      Text((g['sayi']??0).toString()+' giris',
                          style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                    ]))).toList())),
          ],
          const SizedBox(height:20),
          // Dogrulama yontemi
          Row(children:[
            Expanded(child:Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                    border:Border.all(color:Colors.blue.withValues(alpha:0.2))),
                child:Column(children:[
                  const Icon(Icons.camera_alt_outlined,color:Colors.blue,size:28),
                  const SizedBox(height:8),
                  Text((data['plakaDogrulama']??0).toString(),
                      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:24,color:Colors.blue)),
                  const Text('Plaka Dogrulama',style:TextStyle(fontSize:11,color:Colors.grey)),
                ]))),
            const SizedBox(width:12),
            Expanded(child:Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                    border:Border.all(color:Colors.teal.withValues(alpha:0.2))),
                child:Column(children:[
                  const Icon(Icons.qr_code_outlined,color:Colors.teal,size:28),
                  const SizedBox(height:8),
                  Text((data['qrDogrulama']??0).toString(),
                      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:24,color:Colors.teal)),
                  const Text('QR Dogrulama',style:TextStyle(fontSize:11,color:Colors.grey)),
                ]))),
          ]),
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      final now=DateTime.now();
      final bugunStart=DateTime(now.year,now.month,now.day);
      final haftaStart=bugunStart.subtract(const Duration(days:7));

      final snap=await FirebaseFirestore.instance.collection('plate_logs')
          .where('firmaId',isEqualTo:firmaId).get();
      final docs=snap.docs;

      int bugunGelen=0,haftaGelen=0;
      int plakaDogrulama=0,qrDogrulama=0;
      final Map<String,int> gunMap={};
      int toplamSaat=0,saatSay=0;

      for(final doc in docs){
        final d=doc.data() as Map<String,dynamic>;
        if(d['eslesti']!=true)continue;
        final tip=(d['tip']??'plaka').toString();
        if(tip.contains('qr'))qrDogrulama++; else plakaDogrulama++;

        final ts=d['tarih'];
        if(ts is Timestamp){
          final dt=ts.toDate();
          if(dt.isAfter(bugunStart))bugunGelen++;
          if(dt.isAfter(haftaStart))haftaGelen++;
          final gunKey=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0');
          gunMap[gunKey]=(gunMap[gunKey]??0)+1;
          toplamSaat+=dt.hour*60+dt.minute;
          saatSay++;
        }
      }

      final ortSaat=saatSay>0?toplamSaat~/saatSay:0;
      final ortVaris=saatSay>0?(ortSaat~/60).toString().padLeft(2,'0')+':'+(ortSaat%60).toString().padLeft(2,'0'):'-';

      final maxGun=gunMap.values.isEmpty?1:gunMap.values.reduce((a,b)=>a>b?a:b);
      final gunluk=gunMap.entries.take(7).map((e)=>({
        'tarih':e.key,'sayi':e.value,
        'oran':maxGun>0?e.value/maxGun:0.0,
      } as Map<String,dynamic>)).toList();

      return{
        'bugunGelen':bugunGelen,'haftaGelen':haftaGelen,'toplamGiris':docs.length,
        'ortVaris':ortVaris,'gunlukDagilim':gunluk,
        'plakaDogrulama':plakaDogrulama,'qrDogrulama':qrDogrulama,
      };
    }catch(_){return{'gunlukDagilim':[]};}
  }

  Widget _rKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}


// ─────────────────────────────────────────────────────────────────
//  TANITIM MERKEZI – Bolum 23
// ─────────────────────────────────────────────────────────────────
class _KarekodQrSekme extends StatefulWidget{
  final String firmaId;
  const _KarekodQrSekme({required this.firmaId});
  @override State<_KarekodQrSekme> createState()=>_KarekodQrSekmeState();
}
class _KarekodQrSekmeState extends State<_KarekodQrSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.campaign_outlined,'Afis & Sablon'),
            (1,Icons.qr_code_2_outlined,'QR Olustur'),
            (2,Icons.link_outlined,'Kayit Linkleri'),
            (3,Icons.share_outlined,'Sosyal Medya'),
            (4,Icons.bar_chart_outlined,'Istatistikler'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _AfisSablonlar(firmaId:widget.firmaId),
      _QrOlusturSekme(firmaId:widget.firmaId),
      _KayitLinkleri(firmaId:widget.firmaId),
      _SosyalMedya(firmaId:widget.firmaId),
      _TanitimIstatistik(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── AFIS SABLONLARI ──────────────────────────────────────────────
class _AfisSablonlar extends StatelessWidget{
  final String firmaId;
  const _AfisSablonlar({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Afis ve Sablon Merkezi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Hazir sablon secin, 5 dakikada afis olusturun.',style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:20),
        // Hizli erisim
        Row(children:[
          _hizliBtn(context,'QR Afis Olustur',Icons.picture_as_pdf_outlined,Colors.red,'/qr_afis'),
          const SizedBox(width:12),
          _hizliBtn(context,'QR Olustur',Icons.qr_code_2_outlined,_navy,'/qr_olustur'),
          const SizedBox(width:12),
          _hizliBtn(context,'QR Okut',Icons.qr_code_scanner_outlined,Colors.teal,'/qr_okut'),
        ]),
        const SizedBox(height:24),
        // Sablon kartlari
        const Text('Hazir Afis Sablonlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
        const SizedBox(height:12),
        Wrap(spacing:16,runSpacing:16,children:[
          for(final s in [
            ('Okul Servisi',Icons.school_outlined,Colors.blue,'2026-2027 okul servisi kayitlarimiz baslamistir.'),
            ('Kolej Servisi',Icons.location_city_outlined,_navy,'Kolejiniz icin guvenli ve konforlu servis hizmeti.'),
            ('Personel Servisi',Icons.badge_outlined,Colors.teal,'Sirketiniz icin personel servisi cozumleri.'),
            ('Genel Servis',Icons.directions_bus_outlined,Colors.green,'Guvenli servis hizmetleri icin bize katilin.'),
          ])
            Container(width:240,padding:const EdgeInsets.all(20),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                    border:Border.all(color:(s.$3 as Color).withValues(alpha:0.2)),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Container(padding:const EdgeInsets.all(10),
                        decoration:BoxDecoration(color:(s.$3 as Color).withValues(alpha:0.1),
                            borderRadius:BorderRadius.circular(10)),
                        child:Icon(s.$2 as IconData,color:s.$3 as Color,size:24)),
                    const Spacer(),
                    Container(padding:const EdgeInsets.all(12),
                        decoration:BoxDecoration(color:Colors.grey[100],borderRadius:BorderRadius.circular(8)),
                        child:const Icon(Icons.qr_code_outlined,size:36,color:Colors.black87)),
                  ]),
                  const SizedBox(height:14),
                  Text(s.$1 as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                  const SizedBox(height:4),
                  Text(s.$4 as String,style:TextStyle(fontSize:11,color:Colors.grey[500]),maxLines:2),
                  const SizedBox(height:14),
                  Row(children:[
                    Expanded(child:OutlinedButton.icon(
                        style:OutlinedButton.styleFrom(foregroundColor:s.$3 as Color,
                            side:BorderSide(color:(s.$3 as Color).withValues(alpha:0.5)),
                            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),
                            padding:const EdgeInsets.symmetric(vertical:8)),
                        onPressed:()=>Navigator.pushNamed(context,'/qr_afis'),
                        icon:const Icon(Icons.open_in_new_outlined,size:14),
                        label:const Text('Ac',style:TextStyle(fontSize:12)))),
                    const SizedBox(width:8),
                    Expanded(child:ElevatedButton.icon(
                        style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),
                            padding:const EdgeInsets.symmetric(vertical:8)),
                        onPressed:()=>Navigator.pushNamed(context,'/qr_afis'),
                        icon:const Icon(Icons.download_outlined,size:14),
                        label:const Text('Indir',style:TextStyle(fontSize:12)))),
                  ]),
                ])),
        ]),
      ]));

  Widget _hizliBtn(BuildContext context,String l,IconData i,Color r,String route)=>
      Expanded(child:GestureDetector(onTap:()=>Navigator.pushNamed(context,route),
          child:Container(padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:r.withValues(alpha:0.08),borderRadius:BorderRadius.circular(12),
                  border:Border.all(color:r.withValues(alpha:0.2))),
              child:Column(children:[
                Icon(i,color:r,size:24),const SizedBox(height:6),
                Text(l,style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:r),textAlign:TextAlign.center),
              ]))));
}

// ── QR OLUSTUR SEKME ──────────────────────────────────────────────
class _QrOlusturSekme extends StatelessWidget{
  final String firmaId;
  const _QrOlusturSekme({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('projects')
          .where('firmaId',isEqualTo:firmaId)
          .where('aktif',isEqualTo:true).snapshots(),
      builder:(_,snap){
        final projeler=snap.data?.docs??[];
        if(projeler.isEmpty)return _bos('Aktif proje yok','Once proje olusturun.',Icons.folder_outlined);
        return ListView.builder(
            padding:const EdgeInsets.all(24),
            itemCount:projeler.length,
            itemBuilder:(_,i){
              final d=projeler[i].data() as Map<String,dynamic>;
              final projeAd=(d['projeAd']??d['ad']??'Proje').toString();
              final projeId=projeler[i].id;
              final kayitUrl='https://servis360-15b4a.web.app/veli_basvuru?proje='+projeId;
              return Container(margin:const EdgeInsets.only(bottom:12),
                  padding:const EdgeInsets.all(18),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                  child:Row(children:[
                    Container(padding:const EdgeInsets.all(14),
                        decoration:BoxDecoration(color:Colors.grey[100],borderRadius:BorderRadius.circular(10)),
                        child:const Icon(Icons.qr_code_outlined,size:44,color:Colors.black87)),
                    const SizedBox(width:16),
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(projeAd,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
                      const SizedBox(height:4),
                      Text(kayitUrl,style:TextStyle(fontSize:10,color:Colors.grey[400]),
                          maxLines:1,overflow:TextOverflow.ellipsis),
                    ])),
                    const SizedBox(width:12),
                    Column(children:[
                      ElevatedButton.icon(
                          style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                          onPressed:()=>Navigator.pushNamed(context,'/qr_olustur'),
                          icon:const Icon(Icons.qr_code_2_outlined,size:16),
                          label:const Text('QR Olustur')),
                      const SizedBox(height:6),
                      OutlinedButton.icon(
                          style:OutlinedButton.styleFrom(foregroundColor:Colors.teal,
                              side:const BorderSide(color:Colors.teal),
                              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                          onPressed:()=>Navigator.pushNamed(context,'/qr_afis'),
                          icon:const Icon(Icons.picture_as_pdf_outlined,size:14),
                          label:const Text('Afis',style:TextStyle(fontSize:12))),
                    ]),
                  ]));
            });
      });
}

// ── KAYIT LINKLERI ───────────────────────────────────────────────
class _KayitLinkleri extends StatelessWidget{
  final String firmaId;
  const _KayitLinkleri({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:Row(children:[
          const Text('Proje Bazli Kayit Linkleri',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:()=>Navigator.pushNamed(context,'/kayit_link'),
              icon:const Icon(Icons.add_link_outlined,size:16),label:const Text('Yeni Link')),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('kayit_linkleri')
            .where('firmaId',isEqualTo:firmaId)
            .orderBy('olusturmaTarihi',descending:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Kayit linki yok',
              'Yeni Link butonuna basin.',Icons.link_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final url=(d['link']??d['url']??'').toString();
                final projeAd=(d['projeAd']??'').toString();
                final aktif=d['aktif']!=false;
                return Container(margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:(aktif?_navy:Colors.grey).withValues(alpha:0.15)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      Icon(Icons.link_outlined,color:aktif?_navy:Colors.grey,size:20),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(projeAd.isNotEmpty?projeAd:'Genel Link',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(url,style:TextStyle(fontSize:10,color:Colors.grey[500]),
                            maxLines:1,overflow:TextOverflow.ellipsis),
                      ])),
                      const SizedBox(width:8),
                      GestureDetector(
                          onTap:()=>launchUrl(Uri.parse(url)),
                          child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                              decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8)),
                              child:const Row(children:[
                                Icon(Icons.open_in_new_outlined,size:14,color:_navy),
                                SizedBox(width:4),
                                Text('Ac',style:TextStyle(fontSize:11,color:_navy,fontWeight:FontWeight.bold)),
                              ]))),
                      const SizedBox(width:6),
                      GestureDetector(
                          onTap:()=>launchUrl(Uri.parse(
                              'https://wa.me/?text=Servis+kayit+icin+link:+'+Uri.encodeComponent(url))),
                          child:Container(padding:const EdgeInsets.all(6),
                              decoration:BoxDecoration(color:const Color(0xFF25D366).withValues(alpha:0.1),
                                  borderRadius:BorderRadius.circular(8)),
                              child:const Icon(Icons.chat_outlined,size:16,color:Color(0xFF25D366)))),
                    ]));
              });
        })),
  ]);
}

// ── SOSYAL MEDYA ─────────────────────────────────────────────────
class _SosyalMedya extends StatefulWidget{
  final String firmaId;
  const _SosyalMedya({required this.firmaId});
  @override State<_SosyalMedya> createState()=>_SosyalMedyaState();
}
class _SosyalMedyaState extends State<_SosyalMedya>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  String _firmaAd='Firma Adi';
  List<Map<String,dynamic>> _projeler=[];

  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async{
    final doc=await FirebaseFirestore.instance.collection('firms').doc(widget.firmaId).get();
    if(doc.exists){setState(()=>_firmaAd=(doc.data()?['firmaAdi']??doc.data()?['ad']??'Firma Adi').toString());}
    final pSnap=await FirebaseFirestore.instance.collection('projects')
        .where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true).get();
    if(mounted)setState(()=>_projeler=pSnap.docs.map((d)=>{'id':d.id,...d.data()}).toList());
  }

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Sosyal Medya Paylasimlari',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Hazir paylasim metinleri olusturun ve paylasin.',style:TextStyle(color:Colors.grey,fontSize:13)),
        const SizedBox(height:20),
        // Hazir mesajlar
        for(final sablon in [
          ('WhatsApp Duyurusu',Icons.chat_outlined,const Color(0xFF25D366),
          _firmaAd+' olarak 2026-2027 servis kayitlarimiz baslamistir.\n\nKayit icin QR kodu okutabilir veya asagidaki linkten basvurabilirsiniz.\n\nBilgi: '+_firmaAd),
          ('Acilis Duyurusu',Icons.campaign_outlined,_navy,
          _firmaAd+'\n\n2026-2027 servis kayitlari basladi!\nGuvenli ve konforlu ulasim icin hemen kayit olun.\n\n#servis #okul #kayit'),
          ('WhatsApp Veli Daveti',Icons.family_restroom_outlined,Colors.teal,
          'Sayin Velimiz,\n\n'+_firmaAd+' servis hizmetimizden haberdar etmek istiyoruz.\nCocugunuzun guvenligi bizim onceligimizdir.\n\nKayit icin: '),
        ])
          Container(margin:const EdgeInsets.only(bottom:16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                  border:Border.all(color:(sablon.$3 as Color).withValues(alpha:0.2)),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
              child:Column(children:[
                Container(padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:(sablon.$3 as Color).withValues(alpha:0.07),
                        borderRadius:const BorderRadius.vertical(top:Radius.circular(14))),
                    child:Row(children:[
                      Icon(sablon.$2 as IconData,color:sablon.$3 as Color,size:18),
                      const SizedBox(width:8),
                      Text(sablon.$1 as String,style:TextStyle(fontWeight:FontWeight.bold,
                          color:sablon.$3 as Color,fontSize:14)),
                    ])),
                Padding(padding:const EdgeInsets.all(14),
                    child:Container(padding:const EdgeInsets.all(12),
                        decoration:BoxDecoration(color:Colors.grey[50],borderRadius:BorderRadius.circular(8)),
                        child:Text(sablon.$4 as String,style:const TextStyle(fontSize:12)))),
                Padding(padding:const EdgeInsets.only(left:14,right:14,bottom:14),
                    child:Row(children:[
                      Expanded(child:ElevatedButton.icon(
                          style:ElevatedButton.styleFrom(backgroundColor:sablon.$3 as Color,
                              foregroundColor:Colors.white,
                              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                          onPressed:()=>launchUrl(Uri.parse(
                              'https://wa.me/?text='+Uri.encodeComponent(sablon.$4 as String))),
                          icon:const Icon(Icons.send_outlined,size:14),
                          label:const Text('WhatsApp ile Paylah'))),
                    ])),
              ])),
      ]));
}

// ── KAYIT ISTATISTIKLERI ─────────────────────────────────────────
class _TanitimIstatistik extends StatelessWidget{
  final String firmaId;
  const _TanitimIstatistik({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
      future:_veri(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final d=snap.data!;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Kayit Istatistikleri',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _k('Toplam Link',(d['toplamLink']??0).toString(),_navy,Icons.link_outlined),
            const SizedBox(width:12),
            _k('Basvuru',(d['basvuru']??0).toString(),Colors.orange,Icons.how_to_reg_outlined),
            const SizedBox(width:12),
            _k('Onaylanan',(d['onaylanan']??0).toString(),Colors.green,Icons.check_circle_outline),
            const SizedBox(width:12),
            _k('Reddedilen',(d['reddedilen']??0).toString(),Colors.red,Icons.cancel_outlined),
          ]),
          const SizedBox(height:24),
          // Donusum orani
          if((d['basvuru'] as int)>0)...[
            const Text('Donusum Orani',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(20),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:[
                  Row(children:[
                    Text(((d['onaylanan'] as int)/(d['basvuru'] as int)*100).round().toString()+'%',
                        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:36,color:Colors.green)),
                    const SizedBox(width:12),
                    const Text('kayda donustu',style:TextStyle(color:Colors.grey,fontSize:14)),
                  ]),
                  const SizedBox(height:12),
                  ClipRRect(borderRadius:BorderRadius.circular(6),
                      child:LinearProgressIndicator(
                          value:((d['onaylanan'] as int)/(d['basvuru'] as int)).clamp(0.0,1.0),
                          minHeight:14,
                          backgroundColor:Colors.grey.withValues(alpha:0.15),
                          valueColor:const AlwaysStoppedAnimation<Color>(Colors.green))),
                ])),
            const SizedBox(height:20),
          ],
          // Proje bazli
          if((d['projeler'] as List).isNotEmpty)...[
            const Text('Proje Bazli Basvurular',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:(d['projeler'] as List<Map<String,dynamic>>).map((p)=>
                    Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
                      SizedBox(width:160,child:Text(p['ad']??'',
                          style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600),
                          maxLines:1,overflow:TextOverflow.ellipsis)),
                      Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                          child:LinearProgressIndicator(
                              value:(p['oran'] as double).clamp(0.0,1.0),minHeight:8,
                              backgroundColor:Colors.grey.withValues(alpha:0.1),
                              valueColor:const AlwaysStoppedAnimation<Color>(_navy)))),
                      const SizedBox(width:10),
                      Text((p['sayi']??0).toString()+' basvuru',
                          style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                    ]))).toList())),
          ],
        ]));
      });

  Future<Map<String,dynamic>> _veri() async{
    try{
      final linkSnap=await FirebaseFirestore.instance.collection('kayit_linkleri').where('firmaId',isEqualTo:firmaId).count().get();
      final bSnap=await FirebaseFirestore.instance.collection('kayit_basvurulari').where('firmaId',isEqualTo:firmaId).get();
      final onaSnap=await FirebaseFirestore.instance.collection('kayit_basvurulari').where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'onaylandi').count().get();
      final redSnap=await FirebaseFirestore.instance.collection('kayit_basvurulari').where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'reddedildi').count().get();
      final Map<String,int> projeMap={};
      for(final doc in bSnap.docs){
        final d=doc.data();
        final pAd=(d['projeAd']??d['proje']??'Genel').toString();
        projeMap[pAd]=(projeMap[pAd]??0)+1;
      }
      final toplamB=bSnap.docs.length;
      final projeler=projeMap.entries.map((e)=>({
        'ad':e.key,'sayi':e.value,
        'oran':toplamB>0?e.value/toplamB:0.0,
      } as Map<String,dynamic>)).toList()
        ..sort((a,b)=>(b['sayi'] as int).compareTo(a['sayi'] as int));
      return{
        'toplamLink':linkSnap.count??0,'basvuru':toplamB,
        'onaylanan':onaSnap.count??0,'reddedilen':redSnap.count??0,'projeler':projeler,
      };
    }catch(_){return{'projeler':[]};}
  }

  Widget _k(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}



//  BILDIRIMLER
// ─────────────────────────────────────────────────────────────────
//  BILDIRIM VE AKILLI HABERLESME – Bolum 12
// ─────────────────────────────────────────────────────────────────
class _BildirimlerSekme extends StatefulWidget{
  final String firmaId;
  const _BildirimlerSekme({required this.firmaId});
  @override State<_BildirimlerSekme> createState()=>_BildirimlerSekmeState();
}
class _BildirimlerSekmeState extends State<_BildirimlerSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.auto_awesome_outlined,'Otomatik'),
            (1,Icons.send_outlined,'Toplu Mesaj'),
            (2,Icons.emergency_outlined,'Acil Durum'),
            (3,Icons.campaign_outlined,'Duyurular'),
            (4,Icons.history_outlined,'Gecmis'),
            (5,Icons.settings_outlined,'Ayarlar'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _OtomatikBildirimler(firmaId:widget.firmaId),
      _TopluMesajSekme(firmaId:widget.firmaId),
      _AcilDurumMerkezi(firmaId:widget.firmaId),
      _DuyurularSekme(firmaId:widget.firmaId),
      _BildirimGecmisi(firmaId:widget.firmaId),
      _BildirimAyarlari(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── OTOMATIK BILDIRIMLER ─────────────────────────────────────────
class _OtomatikBildirimler extends StatelessWidget{
  final String firmaId;
  const _OtomatikBildirimler({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  static const List<Map<String,dynamic>> _bildirimTipleri=[
    {'tip':'servis_basladi','baslik':'Servis Basladi','aciklama':'Sofor servisi baslattiginda gonderilir','ikon':Icons.play_circle_outline,'renk':Colors.green,'ornek':'Servisiniz hareket etmistir.'},
    {'tip':'servis_yaklasiyor','baslik':'Servis Yaklasiyor','aciklama':'Belirlenen mesafeye ulasildiginda gonderilir','ikon':Icons.directions_bus_outlined,'renk':Colors.orange,'ornek':'Servisiniz 5 dakika icinde duraginiza ulasacak.'},
    {'tip':'servis_geldi','baslik':'Servis Geldi','aciklama':'Servis duraga ulastiginda gonderilir','ikon':Icons.location_on_outlined,'renk':Colors.blue,'ornek':'Servis duraginiza ulasmistir.'},
    {'tip':'ogrenci_alindi','baslik':'Ogrenci Alindi','aciklama':'Sofor ogrenciyi onayladiginda gonderilir','ikon':Icons.person_add_outlined,'renk':Colors.purple,'ornek':'Cocugunuz servise binmistir.'},
    {'tip':'okul_ulasti','baslik':'Okula Ulasti','aciklama':'Servis okula ulastiginda gonderilir','ikon':Icons.school_outlined,'renk':Colors.teal,'ornek':'Servis okula ulasmistir.'},
    {'tip':'servis_bitti','baslik':'Servis Tamamlandi','aciklama':'Sofor servisi bitirdiginde gonderilir','ikon':Icons.check_circle_outline,'renk':Colors.grey,'ornek':'Bugunku servis tamamlanmistir.'},
    {'tip':'gecikme','baslik':'Gecikme Bildirimi','aciklama':'Servis gecikmesi durumunda gonderilir','ikon':Icons.timer_outlined,'renk':Colors.red,'ornek':'Servisinizde gecikme yasanmaktadir.'},
    {'tip':'bugun_gelmeyecek','baslik':'Bugun Gelmeyecek','aciklama':'Veli gelmeyecek bildirdiginde sofore gonderilir','ikon':Icons.event_busy_outlined,'renk':Colors.red,'ornek':'[OGRENCI] bugun servisi kullanmayacaktir.'},
    {'tip':'odeme_hatirlatma','baslik':'Odeme Hatirlatma','aciklama':'Tahsilat sistemiyle entegre','ikon':Icons.payments_outlined,'renk':Colors.orange,'ornek':'Bu ayki servis odemenizin son gunu yaklasmaktadir.'},
    {'tip':'evrak_uyari','baslik':'Evrak Uyarisi','aciklama':'Suresi dolacak evraklar icin','ikon':Icons.folder_outlined,'renk':Colors.amber,'ornek':'Soforunuzun SRC belgesi 30 gun icinde sona erecek.'},
  ];

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Otomatik Bildirim Sistemi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        Container(padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.06),borderRadius:BorderRadius.circular(10),
                border:Border.all(color:Colors.green.withValues(alpha:0.2))),
            child:const Row(children:[
              Icon(Icons.info_outline,color:Colors.green,size:16),SizedBox(width:8),
              Expanded(child:Text('Otomatik bildirimler sistem tarafindan gonderilir. Admin tek tek gondermek zorunda degildir.',
                  style:TextStyle(fontSize:12,color:Colors.green))),
            ])),
        const SizedBox(height:20),
        ..._bildirimTipleri.map((b){
          final renk=b['renk'] as Color;
          return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                  border:Border.all(color:renk.withValues(alpha:0.15)),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
              child:Row(children:[
                Container(padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
                    child:Icon(b['ikon'] as IconData,color:renk,size:22)),
                const SizedBox(width:14),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(b['baslik'] as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                  Text(b['aciklama'] as String,style:TextStyle(fontSize:12,color:Colors.grey[500])),
                  const SizedBox(height:4),
                  Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                      decoration:BoxDecoration(color:renk.withValues(alpha:0.06),borderRadius:BorderRadius.circular(6)),
                      child:Text('Ornek: '+(b['ornek'] as String),
                          style:TextStyle(fontSize:11,color:renk,fontStyle:FontStyle.italic))),
                ])),
                Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                    decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                    child:const Text('Aktif',style:TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:Colors.green))),
              ]));
        }),
      ]));
}

// ── TOPLU MESAJ ───────────────────────────────────────────────────
class _TopluMesajSekme extends StatefulWidget{
  final String firmaId;
  const _TopluMesajSekme({required this.firmaId});
  @override State<_TopluMesajSekme> createState()=>_TopluMesajSekmeState();
}
class _TopluMesajSekmeState extends State<_TopluMesajSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _baslikCtrl=TextEditingController();
  final _mesajCtrl=TextEditingController();
  String _hedef='hepsi';
  String _hedefProje='';
  bool _gonderiyor=false;
  List<Map<String,dynamic>> _projeler=[];

  @override void initState(){super.initState();_projeleYukle();}
  @override void dispose(){_baslikCtrl.dispose();_mesajCtrl.dispose();super.dispose();}

  Future<void> _projeleYukle() async{
    final snap=await FirebaseFirestore.instance.collection('projects')
        .where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true).get();
    if(mounted)setState(()=>_projeler=snap.docs.map((d)=>{'id':d.id,...d.data()}).toList());
  }

  Future<void> _gonder(BuildContext context) async{
    if(_mesajCtrl.text.trim().isEmpty)return;
    setState(()=>_gonderiyor=true);
    try{
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'firmaId':widget.firmaId,
        'baslik':_baslikCtrl.text.trim().isEmpty?'Duyuru':_baslikCtrl.text.trim(),
        'mesaj':_mesajCtrl.text.trim(),
        'hedef':_hedef,
        'projeId':_hedefProje,
        'tip':'toplu_mesaj',
        'tarih':FieldValue.serverTimestamp(),
        'gonderen':'admin',
        'okundu':false,
      });
      _baslikCtrl.clear();_mesajCtrl.clear();
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Mesaj gonderildi!'),backgroundColor:Colors.green,
          behavior:SnackBarBehavior.floating));
    }catch(e){
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:Text('Hata: '+e.toString()),backgroundColor:Colors.red));
    }finally{if(mounted)setState(()=>_gonderiyor=false);}
  }

  @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    // Form
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Toplu Mesaj Gonder',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
      const SizedBox(height:20),
      // Hedef kitle
      const Text('Hedef Kitle',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
      const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final h in [
          ('hepsi','Herkes',Icons.people_outlined),
          ('veliler','Tum Veliler',Icons.family_restroom_outlined),
          ('soforler','Tum Soforler',Icons.person_outlined),
        ])
          GestureDetector(onTap:()=>setState(()=>_hedef=h.$1),
              child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  decoration:BoxDecoration(
                      color:_hedef==h.$1?_navy:Colors.grey[50],
                      borderRadius:BorderRadius.circular(10),
                      border:Border.all(color:_hedef==h.$1?_navy:Colors.grey.shade300)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    Icon(h.$3,size:16,color:_hedef==h.$1?Colors.white:Colors.grey),
                    const SizedBox(width:6),
                    Text(h.$2,style:TextStyle(fontSize:12,color:_hedef==h.$1?Colors.white:Colors.grey,
                        fontWeight:_hedef==h.$1?FontWeight.bold:FontWeight.normal)),
                  ]))),
      ]),
      if(_projeler.isNotEmpty)...[
        const SizedBox(height:14),
        const Text('Proje Filtresi (Opsiyonel)',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
        const SizedBox(height:8),
        DropdownButtonFormField<String>(
            value:_hedefProje.isEmpty?null:_hedefProje,
            decoration:InputDecoration(labelText:'Proje Sec',
                prefixIcon:const Icon(Icons.folder_outlined,color:_navy,size:18),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true),
            items:[const DropdownMenuItem(value:'',child:Text('Tum Projeler')),
              ..._projeler.map((p)=>DropdownMenuItem(value:p['id'] as String,
                  child:Text(p['projeAd']??p['ad']??'')))],
            onChanged:(v)=>setState(()=>_hedefProje=v??'')),
      ],
      const SizedBox(height:16),
      TextField(controller:_baslikCtrl,
          decoration:InputDecoration(labelText:'Baslik (Opsiyonel)',
              prefixIcon:const Icon(Icons.title_outlined,color:_navy,size:18),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
              contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
      const SizedBox(height:10),
      TextField(controller:_mesajCtrl,maxLines:5,
          decoration:InputDecoration(labelText:'Mesaj *',
              prefixIcon:const Icon(Icons.message_outlined,color:_navy,size:18),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
              contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
      const SizedBox(height:16),
      // Hazir mesaj sablonlari
      const Text('Hazir Mesaj Sablonlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
      const SizedBox(height:8),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final s in [
          'Yarin okullar tatildir. Servis hizmeti olmayacaktir.',
          'Yeni donem kayitlari baslamistir.',
          'Servis ucretleri guncellenmistir.',
          'Bayram nedeniyle servis hizmeti verilmeyecektir.',
        ])
          GestureDetector(onTap:()=>_mesajCtrl.text=s,
              child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                  decoration:BoxDecoration(color:_t.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8),
                      border:Border.all(color:_t.withValues(alpha:0.2))),
                  child:Text(s.length>40?s.substring(0,40)+'...':s,
                      style:const TextStyle(fontSize:11,color:Colors.black87)))),
      ]),
      const SizedBox(height:20),
      SizedBox(width:double.infinity,child:ElevatedButton.icon(
          style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
              padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:_gonderiyor?null:()=>_gonder(context),
          icon:_gonderiyor?const SizedBox(width:16,height:16,
              child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):
          const Icon(Icons.send_outlined,size:16),
          label:Text(_gonderiyor?'Gonderiyor...':'Toplu Mesaj Gonder'))),
    ]))),
    // Son gonderilen mesajlar
    Container(width:280,color:Colors.white,padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Son Gonderilen',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
          const SizedBox(height:12),
          Expanded(child:StreamBuilder<QuerySnapshot>(
              stream:FirebaseFirestore.instance.collection('bildirimler')
                  .where('firmaId',isEqualTo:widget.firmaId)
                  .where('tip',isEqualTo:'toplu_mesaj')
                  .orderBy('tarih',descending:true).limit(20).snapshots(),
              builder:(_,snap){
                final docs=snap.data?.docs??[];
                if(docs.isEmpty)return const Center(child:Text('Henuz mesaj gonderilmedi',
                    style:TextStyle(color:Colors.grey,fontSize:12)));
                return ListView.builder(itemCount:docs.length,
                    itemBuilder:(_,i){
                      final d=docs[i].data() as Map<String,dynamic>;
                      final ts=d['tarih'];
                      String tarihStr='';
                      if(ts is Timestamp){final dt=ts.toDate();
                      tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                          dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                      return Container(margin:const EdgeInsets.only(bottom:6),
                          padding:const EdgeInsets.all(10),
                          decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.04),
                              borderRadius:BorderRadius.circular(8)),
                          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            if((d['baslik']??'').isNotEmpty)Text(d['baslik'],
                                style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                            Text(d['mesaj']??'',style:const TextStyle(fontSize:11),
                                maxLines:2,overflow:TextOverflow.ellipsis),
                            Row(children:[
                              Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                              const Spacer(),
                              Text(d['hedef']??'',style:TextStyle(fontSize:10,color:Colors.grey[400])),
                            ]),
                          ]));
                    });
              })),
        ])),
  ]);
}

// ── ACIL DURUM MERKEZI ───────────────────────────────────────────
class _AcilDurumMerkezi extends StatelessWidget{
  final String firmaId;
  const _AcilDurumMerkezi({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
        decoration:BoxDecoration(color:Colors.red.withValues(alpha:0.08),
            border:Border(bottom:BorderSide(color:Colors.red.withValues(alpha:0.2)))),
        child:const Row(children:[
          Icon(Icons.emergency_outlined,color:Colors.red,size:20),SizedBox(width:10),
          Text('Acil Durum Merkezi',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.red,fontSize:16)),
          Spacer(),
          Text('Soforler tarafindan bildirilen acil durumlar',style:TextStyle(fontSize:12,color:Colors.grey)),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('bildirimler')
            .where('firmaId',isEqualTo:firmaId)
            .where('tip',isEqualTo:'acil')
            .orderBy('tarih',descending:true).limit(50).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Container(padding:const EdgeInsets.all(20),
                decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.08),shape:BoxShape.circle),
                child:const Icon(Icons.check_circle_outline,size:56,color:Colors.green)),
            const SizedBox(height:16),
            const Text('Aktif Acil Durum Yok',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.green)),
            const SizedBox(height:8),
            const Text('Soforlerden gelen acil bildirimler burada gorunur.',style:TextStyle(color:Colors.grey)),
          ]));
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final tur=(d['tur']??d['acilTur']??'Diger').toString();
                final turRenk=tur=='Kaza'||tur=='Arac Arizasi'?Colors.red:Colors.orange;
                final okundu=d['okundu']==true;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                    dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                return Container(margin:const EdgeInsets.only(bottom:10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        border:Border.all(color:okundu?Colors.grey.withValues(alpha:0.15):Colors.red.withValues(alpha:0.3)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Column(children:[
                      Container(padding:const EdgeInsets.all(14),
                          decoration:BoxDecoration(
                              color:(okundu?Colors.grey:Colors.red).withValues(alpha:0.05),
                              borderRadius:const BorderRadius.vertical(top:Radius.circular(14))),
                          child:Row(children:[
                            Container(padding:const EdgeInsets.all(8),
                                decoration:BoxDecoration(color:turRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                                child:Icon(Icons.emergency_outlined,color:turRenk,size:20)),
                            const SizedBox(width:12),
                            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                              Text(tur,style:TextStyle(fontWeight:FontWeight.bold,fontSize:14,color:turRenk)),
                              Text((d['soforAd']??d['gonderen']??'Sofor').toString(),
                                  style:TextStyle(fontSize:12,color:Colors.grey[500])),
                              if((d['plaka']??'').isNotEmpty)Text(d['plaka'],
                                  style:TextStyle(fontSize:11,color:Colors.grey[400])),
                            ])),
                            Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                              Text(tarihStr,style:TextStyle(fontSize:11,color:Colors.grey[400])),
                              const SizedBox(height:4),
                              if(!okundu)GestureDetector(
                                  onTap:()=>FirebaseFirestore.instance.collection('bildirimler')
                                      .doc(docs[i].id).update({'okundu':true}),
                                  child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                      decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                      child:const Text('Okundu Isaretle',style:TextStyle(fontSize:10,color:Colors.blue,fontWeight:FontWeight.bold))))
                              else Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                  decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                  child:const Text('Okundu',style:TextStyle(fontSize:10,color:Colors.green,fontWeight:FontWeight.bold))),
                            ]),
                          ])),
                      if((d['mesaj']??'').isNotEmpty)Padding(
                          padding:const EdgeInsets.all(12),
                          child:Text(d['mesaj'],style:const TextStyle(fontSize:13))),
                    ]));
              });
        })),
  ]);
}

// ── DUYURULAR ────────────────────────────────────────────────────
class _DuyurularSekme extends StatefulWidget{
  final String firmaId;
  const _DuyurularSekme({required this.firmaId});
  @override State<_DuyurularSekme> createState()=>_DuyurularSekmeState();
}
class _DuyurularSekmeState extends State<_DuyurularSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _baslikCtrl=TextEditingController();
  final _icerikCtrl=TextEditingController();
  bool _gonderiyor=false;

  @override void dispose(){_baslikCtrl.dispose();_icerikCtrl.dispose();super.dispose();}

  Future<void> _duyuruYayinla(BuildContext context) async{
    if(_baslikCtrl.text.trim().isEmpty||_icerikCtrl.text.trim().isEmpty)return;
    setState(()=>_gonderiyor=true);
    try{
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'firmaId':widget.firmaId,
        'baslik':_baslikCtrl.text.trim(),
        'mesaj':_icerikCtrl.text.trim(),
        'hedef':'hepsi','tip':'duyuru',
        'tarih':FieldValue.serverTimestamp(),
        'gonderen':'admin','okundu':false,
      });
      _baslikCtrl.clear();_icerikCtrl.clear();
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:Text('Duyuru yayinlandi!'),backgroundColor:Colors.green,
          behavior:SnackBarBehavior.floating));
    }finally{if(mounted)setState(()=>_gonderiyor=false);}
  }

  @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    // Form
    Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Duyuru Olustur',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
      const SizedBox(height:8),
      const Text('Duyurular veli uygulamasinda "Duyurular" menusunde gorunur.',
          style:TextStyle(fontSize:12,color:Colors.grey)),
      const SizedBox(height:20),
      TextField(controller:_baslikCtrl,
          decoration:InputDecoration(labelText:'Duyuru Basligi *',
              prefixIcon:const Icon(Icons.campaign_outlined,color:_navy,size:18),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
              contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
      const SizedBox(height:10),
      TextField(controller:_icerikCtrl,maxLines:6,
          decoration:InputDecoration(labelText:'Duyuru Icerigi *',
              prefixIcon:const Icon(Icons.article_outlined,color:_navy,size:18),
              border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
              contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
      const SizedBox(height:14),
      // Ornek duyurular
      const Text('Ornek Duyurular',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
      const SizedBox(height:8),
      ...const[
        ('Yeni Donem Kayitlari','Yeni donem kayitlarimiz baslamistir. Detayli bilgi icin bizi arayabilirsiniz.'),
        ('Bayram Tatili','Bayram nedeniyle servis hizmetimiz 3 gun ara verecektir.'),
        ('Ucret Guncelleme','Servis ucretlerimiz bu ay guncellenmistir.'),
      ].map((e)=>GestureDetector(
          onTap:(){_baslikCtrl.text=e.$1;_icerikCtrl.text=e.$2;},
          child:Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.04),borderRadius:BorderRadius.circular(8),
                  border:Border.all(color:Colors.grey.withValues(alpha:0.15))),
              child:Row(children:[
                const Icon(Icons.campaign_outlined,size:16,color:Colors.grey),const SizedBox(width:8),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(e.$1,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),
                  Text(e.$2,style:const TextStyle(fontSize:11,color:Colors.grey),maxLines:1,overflow:TextOverflow.ellipsis),
                ])),
              ])))),
      const SizedBox(height:16),
      SizedBox(width:double.infinity,child:ElevatedButton.icon(
          style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
              padding:const EdgeInsets.symmetric(vertical:14)),
          onPressed:_gonderiyor?null:()=>_duyuruYayinla(context),
          icon:const Icon(Icons.campaign_outlined,size:16),
          label:Text(_gonderiyor?'Yayinlaniyor...':'Duyuruyu Yayinla'))),
    ]))),
    // Mevcut duyurular
    Container(width:300,color:Colors.white,padding:const EdgeInsets.all(16),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Yayinlanan Duyurular',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
          const SizedBox(height:12),
          Expanded(child:StreamBuilder<QuerySnapshot>(
              stream:FirebaseFirestore.instance.collection('bildirimler')
                  .where('firmaId',isEqualTo:widget.firmaId)
                  .where('tip',isEqualTo:'duyuru')
                  .orderBy('tarih',descending:true).limit(20).snapshots(),
              builder:(_,snap){
                final docs=snap.data?.docs??[];
                if(docs.isEmpty)return const Center(child:Text('Duyuru bulunamadi',
                    style:TextStyle(color:Colors.grey,fontSize:12)));
                return ListView.builder(itemCount:docs.length,
                    itemBuilder:(_,i){
                      final d=docs[i].data() as Map<String,dynamic>;
                      return Container(margin:const EdgeInsets.only(bottom:8),
                          padding:const EdgeInsets.all(12),
                          decoration:BoxDecoration(color:_t.withValues(alpha:0.04),borderRadius:BorderRadius.circular(10),
                              border:Border.all(color:_t.withValues(alpha:0.15))),
                          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Row(children:[
                              const Icon(Icons.campaign_outlined,size:14,color:Color(0xFFFF8C00)),
                              const SizedBox(width:6),
                              Expanded(child:Text(d['baslik']??'',
                                  style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:Color(0xFF1a3a6b)))),
                              IconButton(padding:EdgeInsets.zero,constraints:const BoxConstraints(),
                                  icon:const Icon(Icons.delete_outline,size:16,color:Colors.grey),
                                  onPressed:()=>FirebaseFirestore.instance.collection('bildirimler')
                                      .doc(docs[i].id).delete()),
                            ]),
                            Text(d['mesaj']??'',style:const TextStyle(fontSize:11),
                                maxLines:2,overflow:TextOverflow.ellipsis),
                          ]));
                    });
              })),
        ])),
  ]);
}

// ── BILDIRIM GECMISI ────────────────────────────────────────────
class _BildirimGecmisi extends StatefulWidget{
  final String firmaId;
  const _BildirimGecmisi({required this.firmaId});
  @override State<_BildirimGecmisi> createState()=>_BildirimGecmisiState();
}
class _BildirimGecmisiState extends State<_BildirimGecmisi>{
  static const _navy=Color(0xFF1a3a6b);
  String _tipFiltre='hepsi';

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          const Text('Bildirim Gecmisi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          for(final f in [('hepsi','Tumu'),('toplu_mesaj','Toplu'),('duyuru','Duyuru'),('acil','Acil')])
            GestureDetector(onTap:()=>setState(()=>_tipFiltre=f.$1),
                child:Container(margin:const EdgeInsets.only(left:6),
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                    decoration:BoxDecoration(
                        color:_tipFiltre==f.$1?_navy:Colors.grey[100],
                        borderRadius:BorderRadius.circular(8)),
                    child:Text(f.$2,style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,
                        color:_tipFiltre==f.$1?Colors.white:Colors.grey)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:(){
          var q=FirebaseFirestore.instance.collection('bildirimler')
              .where('firmaId',isEqualTo:widget.firmaId);
          if(_tipFiltre!='hepsi')q=q.where('tip',isEqualTo:_tipFiltre);
          return q.orderBy('tarih',descending:true).limit(100).snapshots();
        }(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Bildirim gecmisi bos','',Icons.notifications_none_outlined);
          return ListView.builder(padding:const EdgeInsets.all(16),itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final tip=(d['tip']??'').toString();
                final hedef=(d['hedef']??'').toString();
                final tipRenk={'toplu_mesaj':Colors.blue,'duyuru':const Color(0xFFFF8C00),
                  'acil':Colors.red,'servis_basladi':Colors.green}[tip]??Colors.grey;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString()+' '+
                    dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                return Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(12),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border(left:BorderSide(color:tipRenk,width:3)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(7),
                          decoration:BoxDecoration(color:tipRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Icon(Icons.notifications_outlined,color:tipRenk,size:16)),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        if((d['baslik']??'').isNotEmpty)Text(d['baslik'],
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                        Text(d['mesaj']??'',style:const TextStyle(fontSize:11),
                            maxLines:2,overflow:TextOverflow.ellipsis),
                        Row(children:[
                          if(tip.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
                              decoration:BoxDecoration(color:tipRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(4)),
                              child:Text(tip,style:TextStyle(fontSize:9,color:tipRenk,fontWeight:FontWeight.bold))),
                          const SizedBox(width:6),
                          if(hedef.isNotEmpty)Text(hedef,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                        ]),
                      ])),
                      Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                    ]));
              });
        })),
  ]);
}

// ── BILDIRIM AYARLARI ────────────────────────────────────────────
class _BildirimAyarlari extends StatefulWidget{
  final String firmaId;
  const _BildirimAyarlari({required this.firmaId});
  @override State<_BildirimAyarlari> createState()=>_BildirimAyarlariState();
}
class _BildirimAyarlariState extends State<_BildirimAyarlari>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  String _yaklasmaMesafe='500';
  bool _sessizSaatAktif=false;
  int _sessizBaslangic=22;
  int _sessizBitis=8;
  bool _yuklendi=false;

  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async{
    try{
      final snap=await FirebaseFirestore.instance.collection('firma_ayarlari')
          .doc(widget.firmaId).get();
      if(snap.exists){
        final d=snap.data()!;
        setState((){
          _yaklasmaMesafe=(d['yaklasmaMesafe']??'500').toString();
          _sessizSaatAktif=d['sessizSaatAktif']??false;
          _sessizBaslangic=d['sessizBaslangic']??22;
          _sessizBitis=d['sessizBitis']??8;
          _yuklendi=true;
        });
      }else setState(()=>_yuklendi=true);
    }catch(_){setState(()=>_yuklendi=true);}
  }

  Future<void> _kaydet(BuildContext context) async{
    await FirebaseFirestore.instance.collection('firma_ayarlari')
        .doc(widget.firmaId).set({
      'yaklasmaMesafe':_yaklasmaMesafe,
      'sessizSaatAktif':_sessizSaatAktif,
      'sessizBaslangic':_sessizBaslangic,
      'sessizBitis':_sessizBitis,
    },SetOptions(merge:true));
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Bildirim ayarlari kaydedildi'),backgroundColor:Colors.green,
        behavior:SnackBarBehavior.floating));
  }

  @override Widget build(BuildContext context){
    if(!_yuklendi)return const Center(child:CircularProgressIndicator());
    return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
        crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Bildirim Ayarlari',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
      const SizedBox(height:24),
      // Yaklasiyor mesafesi
      Container(padding:const EdgeInsets.all(20),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Row(children:[
              Icon(Icons.directions_bus_outlined,color:_navy,size:20),SizedBox(width:10),
              Text('Yaklasiyor Bildirimi Mesafesi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
            ]),
            const SizedBox(height:6),
            const Text('Servis ne kadar uzaktayken bildirim gonderilsin?',
                style:TextStyle(color:Colors.grey,fontSize:12)),
            const SizedBox(height:14),
            Wrap(spacing:10,children:[
              for(final m in [('500','500 Metre'),('700','700 Metre'),('1000','1 KM')])
                GestureDetector(onTap:()=>setState(()=>_yaklasmaMesafe=m.$1),
                    child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
                        decoration:BoxDecoration(
                            color:_yaklasmaMesafe==m.$1?_navy:Colors.grey[50],
                            borderRadius:BorderRadius.circular(10),
                            border:Border.all(color:_yaklasmaMesafe==m.$1?_navy:Colors.grey.shade300)),
                        child:Text(m.$2,style:TextStyle(
                            color:_yaklasmaMesafe==m.$1?Colors.white:Colors.grey,
                            fontWeight:_yaklasmaMesafe==m.$1?FontWeight.bold:FontWeight.normal)))),
            ]),
          ])),
      const SizedBox(height:16),
      // Sessiz saatler
      Container(padding:const EdgeInsets.all(20),
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Icon(Icons.nights_stay_outlined,color:_navy,size:20),const SizedBox(width:10),
              const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Sessiz Saatler',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
                Text('Bu saatler arasinda bildirim gonderilmez.',style:TextStyle(color:Colors.grey,fontSize:12)),
              ])),
              Switch(value:_sessizSaatAktif,activeThumbColor:_t,onChanged:(v)=>setState(()=>_sessizSaatAktif=v)),
            ]),
            if(_sessizSaatAktif)...[
              const SizedBox(height:14),
              Row(children:[
                Expanded(child:Column(children:[
                  const Text('Baslangic',style:TextStyle(fontWeight:FontWeight.w600,fontSize:12)),
                  const SizedBox(height:6),
                  DropdownButtonFormField<int>(
                      value:_sessizBaslangic,
                      decoration:InputDecoration(border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)),isDense:true),
                      items:[for(int h=0;h<24;h++)DropdownMenuItem(value:h,child:Text(h.toString().padLeft(2,'0')+':00'))],
                      onChanged:(v)=>setState(()=>_sessizBaslangic=v??22)),
                ])),
                const Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:12),
                    child:Text('–',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold))),
                Expanded(child:Column(children:[
                  const Text('Bitis',style:TextStyle(fontWeight:FontWeight.w600,fontSize:12)),
                  const SizedBox(height:6),
                  DropdownButtonFormField<int>(
                      value:_sessizBitis,
                      decoration:InputDecoration(border:OutlineInputBorder(borderRadius:BorderRadius.circular(8)),isDense:true),
                      items:[for(int h=0;h<24;h++)DropdownMenuItem(value:h,child:Text(h.toString().padLeft(2,'0')+':00'))],
                      onChanged:(v)=>setState(()=>_sessizBitis=v??8)),
                ])),
              ]),
            ],
          ])),
      const SizedBox(height:24),
      ElevatedButton.icon(
          style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
              padding:const EdgeInsets.symmetric(horizontal:24,vertical:12)),
          onPressed:()=>_kaydet(context),
          icon:const Icon(Icons.save_outlined,size:16),
          label:const Text('Ayarlari Kaydet')),
    ]));
  }
}


class _ArsivSekme extends StatefulWidget{
  final String firmaId;
  const _ArsivSekme({required this.firmaId});
  @override State<_ArsivSekme> createState()=>_ArsivSekmeState();
}
class _ArsivSekmeState extends State<_ArsivSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final item in[
            (0,Icons.school_outlined,'Ogrenciler'),
            (1,Icons.family_restroom_outlined,'Veliler'),
            (2,Icons.person_outlined,'Soforler'),
            (3,Icons.directions_bus_outlined,'Servisler'),
            (4,Icons.folder_outlined,'Projeler'),
            (5,Icons.description_outlined,'Sozlesmeler'),
            (6,Icons.receipt_outlined,'Tahsilatlar'),
            (7,Icons.history_outlined,'Islem Loglari'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=item.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==item.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(item.$2,size:13,color:_tab==item.$1?_navy:Colors.grey),
                      const SizedBox(width:5),
                      Text(item.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==item.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:_ArsivListesi(
      firmaId:widget.firmaId,
      tab:_tab,
    )),
  ]);
}

class _ArsivListesi extends StatelessWidget{
  final String firmaId;
  final int tab;
  const _ArsivListesi({required this.firmaId,required this.tab});
  static const _navy=Color(0xFF1a3a6b);

  Stream<QuerySnapshot> _stream(){
    final fb=FirebaseFirestore.instance;
    switch(tab){
      case 0: return fb.collection('students').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:false).snapshots();
      case 1: return fb.collection('parents').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:false).snapshots();
      case 2: return fb.collection('drivers').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:false).snapshots();
      case 3: return fb.collection('services').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:false).snapshots();
      case 4: return fb.collection('projects').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:false).snapshots();
      case 5: return fb.collection('sozlesmeler').where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'arsiv').orderBy('tarih',descending:true).snapshots();
      case 6: return fb.collection('tahsilat').where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'arsiv').snapshots();
      default: return fb.collection('islem_loglari').where('firmaId',isEqualTo:firmaId).orderBy('tarih',descending:true).limit(100).snapshots();
    }
  }

  String _koleksiyon(){
    switch(tab){
      case 0: return 'students';
      case 1: return 'parents';
      case 2: return 'drivers';
      case 3: return 'services';
      case 4: return 'projects';
      default: return '';
    }
  }

  String _adField(Map<String,dynamic> d){
    return d['ad']??d['ogrenciAd']??d['veliAd']??d['soforAd']??
        d['servisAd']??d['projeAd']??d['kisi']??'-';
  }

  Future<void> _geriGetir(BuildContext context,String docId) async{
    final kol=_koleksiyon();
    if(kol.isEmpty)return;
    await FirebaseFirestore.instance.collection(kol).doc(docId).update({'aktif':true});
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Kayit aktif listeye alindi'),backgroundColor:Colors.green,
        behavior:SnackBarBehavior.floating));
  }

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:_stream(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Bu kategori bos','Arsivlenen kayitlar burada gorunur.',Icons.archive_outlined);
        return Column(children:[
          // Ozet bar
          Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
              child:Row(children:[
                Icon(Icons.archive_outlined,color:Colors.grey[400],size:16),
                const SizedBox(width:8),
                Text(docs.length.toString()+' arsivlenmis kayit',
                    style:TextStyle(fontSize:13,color:Colors.grey[600],fontWeight:FontWeight.w600)),
              ])),
          Expanded(child:ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ad=_adField(d);
                final ts=d['tarih']??d['arsivTarihi']??d['olusturmaTarihi'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString();}
                return Container(margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.08),
                              borderRadius:BorderRadius.circular(8)),
                          child:Icon(Icons.archive_outlined,color:Colors.grey[400],size:18)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(ad,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        if(tarihStr.isNotEmpty)Text('Arsivlendi: '+tarihStr,
                            style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        if((d['sebep']??'').toString().isNotEmpty)Text(d['sebep'],
                            style:TextStyle(fontSize:11,color:Colors.grey[400])),
                      ])),
                      // Geri getir butonu (log haric)
                      if(tab<5)GestureDetector(
                          onTap:()=>_geriGetir(context,docs[i].id),
                          child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                              decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),
                                  borderRadius:BorderRadius.circular(8),
                                  border:Border.all(color:Colors.green.withValues(alpha:0.3))),
                              child:const Row(mainAxisSize:MainAxisSize.min,children:[
                                Icon(Icons.restore_outlined,size:14,color:Colors.green),
                                SizedBox(width:4),
                                Text('Geri Getir',style:TextStyle(fontSize:11,color:Colors.green,fontWeight:FontWeight.bold)),
                              ])))
                      else Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                          decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:const Text('Arsiv',style:TextStyle(fontSize:10,color:Colors.grey,fontWeight:FontWeight.bold))),
                    ]));
              })),
        ]);
      });
}



// ─────────────────────────────────────────────────────────────────
//  GUVENLIK VE YETKI MODULU – Bolum 18
// ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────
//  ACIL DURUM MERKEZI – Bolum 22
// ─────────────────────────────────────────────────────────────────
class _AcilDurumSekme extends StatefulWidget{
  final String firmaId;
  const _AcilDurumSekme({required this.firmaId});
  @override State<_AcilDurumSekme> createState()=>_AcilDurumSekmeState();
}
class _AcilDurumSekmeState extends State<_AcilDurumSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    // Kirmizi ust bar
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
        color:Colors.red.withValues(alpha:0.06),
        child:Row(children:[
          const Icon(Icons.emergency_outlined,color:Colors.red,size:18),
          const SizedBox(width:8),
          const Text('Acil Durum Merkezi',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.red,fontSize:15)),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
              stream:FirebaseFirestore.instance.collection('bildirimler')
                  .where('firmaId',isEqualTo:widget.firmaId)
                  .where('tip',isEqualTo:'acil')
                  .where('okundu',isEqualTo:false).snapshots(),
              builder:(_,snap){
                final count=snap.data?.docs.length??0;
                if(count==0)return const SizedBox();
                return Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                    decoration:BoxDecoration(color:Colors.red,borderRadius:BorderRadius.circular(20)),
                    child:Text(count.toString()+' yeni',
                        style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold)));
              }),
        ])),
    // Tab bar
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.warning_amber_outlined,'Aktif Olaylar'),
            (1,Icons.history_outlined,'Olay Gecmisi'),
            (2,Icons.contact_phone_outlined,'Acil Iletisim'),
            (3,Icons.shield_outlined,'Guvenlik Uyarilari'),
            (4,Icons.bar_chart_outlined,'Rapor'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?Colors.red:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?Colors.red:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?Colors.red:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _AktifOlaylar(firmaId:widget.firmaId),
      _OlayGecmisi(firmaId:widget.firmaId),
      _AcilIletisim(firmaId:widget.firmaId),
      _GuvenlikUyarilari(firmaId:widget.firmaId),
      _AcilRapor(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── AKTIF OLAYLAR ────────────────────────────────────────────────
class _AktifOlaylar extends StatelessWidget{
  final String firmaId;
  const _AktifOlaylar({required this.firmaId});

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('bildirimler')
          .where('firmaId',isEqualTo:firmaId)
          .where('tip',isEqualTo:'acil')
          .orderBy('tarih',descending:true).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        final aktif=docs.where((d)=>(d.data() as Map)['durum']!='cozuldu'&&(d.data() as Map)['durum']!='kapandi').toList();
        if(aktif.isEmpty)return Center(child:Column(
            mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(padding:const EdgeInsets.all(24),
              decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.08),shape:BoxShape.circle),
              child:const Icon(Icons.check_circle_outline,size:56,color:Colors.green)),
          const SizedBox(height:16),
          const Text('Aktif Acil Durum Yok',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:Colors.green)),
          const SizedBox(height:8),
          const Text('Tum servisler normal seyrinde devam ediyor.',style:TextStyle(color:Colors.grey)),
        ]));
        return ListView.builder(
            padding:const EdgeInsets.all(16),
            itemCount:aktif.length,
            itemBuilder:(_,i){
              final d=aktif[i].data() as Map<String,dynamic>;
              final tur=(d['tur']??d['acilTur']??'Diger').toString();
              final durumRenk=tur=='Kaza'||tur=='Arac Arizasi'?Colors.red:Colors.orange;
              final ts=d['tarih'];
              String tarihStr='';
              if(ts is Timestamp){final dt=ts.toDate();
              tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                  dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
              return Container(margin:const EdgeInsets.only(bottom:10),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                      border:Border.all(color:durumRenk.withValues(alpha:0.4)),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:8)]),
                  child:Column(children:[
                    Container(padding:const EdgeInsets.all(14),
                        decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.06),
                            borderRadius:const BorderRadius.vertical(top:Radius.circular(14))),
                        child:Row(children:[
                          Container(padding:const EdgeInsets.all(10),
                              decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.15),borderRadius:BorderRadius.circular(10)),
                              child:Icon(Icons.emergency_outlined,color:durumRenk,size:22)),
                          const SizedBox(width:12),
                          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Text(tur,style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:durumRenk)),
                            Text((d['soforAd']??d['gonderen']??'').toString(),
                                style:TextStyle(fontSize:12,color:Colors.grey[600])),
                            if((d['plaka']??'').isNotEmpty)Text(d['plaka'],
                                style:TextStyle(fontSize:11,color:Colors.grey[400])),
                          ])),
                          Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                            Text(tarihStr,style:TextStyle(fontSize:11,color:Colors.grey[400])),
                            const SizedBox(height:6),
                            Row(children:[
                              _durumBtn(aktif[i].id,'inceleniyor','Incele',Colors.orange),
                              const SizedBox(width:6),
                              _durumBtn(aktif[i].id,'cozuldu','Cozuldu',Colors.green),
                            ]),
                          ]),
                        ])),
                    if((d['mesaj']??'').isNotEmpty)Padding(
                        padding:const EdgeInsets.all(14),
                        child:Text(d['mesaj'],style:const TextStyle(fontSize:13))),
                  ]));
            });
      });

  Widget _durumBtn(String docId,String durum,String etiket,Color renk)=>GestureDetector(
      onTap:()=>FirebaseFirestore.instance.collection('bildirimler').doc(docId).update({'durum':durum,'okundu':true}),
      child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
          decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6),
              border:Border.all(color:renk.withValues(alpha:0.3))),
          child:Text(etiket,style:TextStyle(fontSize:10,color:renk,fontWeight:FontWeight.bold))));
}

// ── OLAY GECMISI ─────────────────────────────────────────────────
class _OlayGecmisi extends StatelessWidget{
  final String firmaId;
  const _OlayGecmisi({required this.firmaId});

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('bildirimler')
          .where('firmaId',isEqualTo:firmaId)
          .where('tip',isEqualTo:'acil')
          .orderBy('tarih',descending:true).limit(100).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        if(docs.isEmpty)return _bos('Olay gecmisi bos','',Icons.history_outlined);
        return ListView.builder(
            padding:const EdgeInsets.all(16),
            itemCount:docs.length,
            itemBuilder:(_,i){
              final d=docs[i].data() as Map<String,dynamic>;
              final tur=(d['tur']??d['acilTur']??'Diger').toString();
              final durum=(d['durum']??'acik').toString();
              final durumRenk=durum=='cozuldu'?Colors.green:durum=='inceleniyor'?Colors.orange:Colors.red;
              final ts=d['tarih'];
              String tarihStr='';
              if(ts is Timestamp){final dt=ts.toDate();
              tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString()+' '+
                  dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
              return Container(margin:const EdgeInsets.only(bottom:8),
                  padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                      border:Border(left:BorderSide(color:durumRenk,width:3))),
                  child:Row(children:[
                    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                      Text(tur,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                      Text((d['soforAd']??'').toString()+' – '+(d['plaka']??'').toString(),
                          style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                    ])),
                    Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                        decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                        child:Text(durum,style:TextStyle(fontSize:10,color:durumRenk,fontWeight:FontWeight.bold))),
                  ]));
            });
      });
}

// ── ACIL ILETISIM ────────────────────────────────────────────────
class _AcilIletisim extends StatefulWidget{
  final String firmaId;
  const _AcilIletisim({required this.firmaId});
  @override State<_AcilIletisim> createState()=>_AcilIletisimState();
}
class _AcilIletisimState extends State<_AcilIletisim>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _adCtrl=TextEditingController();
  final _telCtrl=TextEditingController();
  final _rolCtrl=TextEditingController();

  @override void dispose(){_adCtrl.dispose();_telCtrl.dispose();_rolCtrl.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    // Liste
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('acil_iletisim')
            .where('firmaId',isEqualTo:widget.firmaId).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Acil iletisim listesi bos','Sagdan kisi ekleyin.',Icons.contact_phone_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:_navy.withValues(alpha:0.1)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(10),
                          decoration:BoxDecoration(color:_navy.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
                          child:const Icon(Icons.person_outlined,color:_navy,size:20)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Text(d['rol']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        Text(d['telefon']??'',style:const TextStyle(fontSize:13,color:_navy,fontWeight:FontWeight.w600)),
                      ])),
                      Row(children:[
                        GestureDetector(
                            onTap:()=>launchUrl(Uri.parse('tel:'+d['telefon'])),
                            child:Container(padding:const EdgeInsets.all(8),
                                decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                                child:const Icon(Icons.call_outlined,color:Colors.green,size:18))),
                        const SizedBox(width:6),
                        GestureDetector(
                            onTap:()=>launchUrl(Uri.parse('https://wa.me/90'+d['telefon'].toString().replaceAll(' ','').replaceAll('-',''))),
                            child:Container(padding:const EdgeInsets.all(8),
                                decoration:BoxDecoration(color:Colors.teal.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                                child:const Icon(Icons.chat_outlined,color:Colors.teal,size:18))),
                        const SizedBox(width:6),
                        GestureDetector(
                            onTap:()=>FirebaseFirestore.instance.collection('acil_iletisim').doc(docs[i].id).delete(),
                            child:const Icon(Icons.delete_outline,color:Colors.red,size:18)),
                      ]),
                    ]));
              });
        })),
    // Form
    Container(width:260,padding:const EdgeInsets.all(20),color:Colors.white,
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Kisi Ekle',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const SizedBox(height:12),
          TextField(controller:_adCtrl,
              decoration:InputDecoration(labelText:'Ad Soyad *',
                  prefixIcon:const Icon(Icons.person_outlined,size:18,color:_navy),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
                  contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:8),
          TextField(controller:_rolCtrl,
              decoration:InputDecoration(labelText:'Gorevi',
                  prefixIcon:const Icon(Icons.badge_outlined,size:18,color:_navy),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
                  contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:8),
          TextField(controller:_telCtrl,keyboardType:TextInputType.phone,
              decoration:InputDecoration(labelText:'Telefon *',
                  prefixIcon:const Icon(Icons.call_outlined,size:18,color:_navy),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
                  contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:12),
          SizedBox(width:double.infinity,child:ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:() async{
                if(_adCtrl.text.trim().isEmpty||_telCtrl.text.trim().isEmpty)return;
                await FirebaseFirestore.instance.collection('acil_iletisim').add({
                  'firmaId':widget.firmaId,'ad':_adCtrl.text.trim(),
                  'rol':_rolCtrl.text.trim(),'telefon':_telCtrl.text.trim(),
                  'tarih':FieldValue.serverTimestamp(),
                });
                _adCtrl.clear();_rolCtrl.clear();_telCtrl.clear();
              },
              icon:const Icon(Icons.add,size:16),label:const Text('Ekle'))),
        ])),
  ]);
}

// ── GUVENLIK UYARILARI ──────────────────────────────────────────
class _GuvenlikUyarilari extends StatelessWidget{
  final String firmaId;
  const _GuvenlikUyarilari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.all(16),color:Colors.white,
        child:const Row(children:[
          Icon(Icons.shield_outlined,color:_navy,size:18),SizedBox(width:8),
          Text('Otomatik Guvenlik Uyarilari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('drivers')
            .where('firmaId',isEqualTo:firmaId)
            .where('servisAktif',isEqualTo:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          final List<Map<String,dynamic>> uyarilar=[];

          for(final doc in docs){
            final d=doc.data() as Map<String,dynamic>;
            final sonKonum=d['sonKonumZamani'];
            if(sonKonum is Timestamp){
              final fark=DateTime.now().difference(sonKonum.toDate()).inMinutes;
              if(fark>10){
                uyarilar.add({
                  'sofor':d['ad']??'',
                  'plaka':d['aracPlaka']??'',
                  'mesaj':fark.toString()+' dakikedir konum guncellenmiyor.',
                  'renk':Colors.orange,
                  'ikon':Icons.location_off_outlined,
                });
              }
            }
            if(d['hiz']!=null&&(d['hiz'] as num)>80){
              uyarilar.add({
                'sofor':d['ad']??'',
                'plaka':d['aracPlaka']??'',
                'mesaj':'Yuksek hiz: '+(d['hiz'] as num).toStringAsFixed(0)+' km/s',
                'renk':Colors.red,
                'ikon':Icons.speed_outlined,
              });
            }
          }

          if(uyarilar.isEmpty)return Center(child:Column(
              mainAxisAlignment:MainAxisAlignment.center,children:[
            const Icon(Icons.security_outlined,size:56,color:Colors.green),
            const SizedBox(height:12),
            const Text('Guvenlik Uyarisi Yok',style:TextStyle(fontSize:16,color:Colors.green)),
            const SizedBox(height:8),
            const Text('Tum aktif araclar normal durumda.',style:TextStyle(color:Colors.grey)),
          ]));

          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:uyarilar.length,
              itemBuilder:(_,i){
                final u=uyarilar[i];
                return Container(margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:(u['renk'] as Color).withValues(alpha:0.3))),
                    child:Row(children:[
                      Icon(u['ikon'] as IconData,color:u['renk'] as Color,size:22),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(u['sofor'] as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(u['plaka'] as String,style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        Text(u['mesaj'] as String,style:TextStyle(fontSize:12,color:u['renk'] as Color)),
                      ])),
                    ]));
              });
        })),
  ]);
}

// ── ACIL RAPOR ───────────────────────────────────────────────────
class _AcilRapor extends StatelessWidget{
  final String firmaId;
  const _AcilRapor({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('bildirimler')
          .where('firmaId',isEqualTo:firmaId)
          .where('tip',isEqualTo:'acil').snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        final Map<String,int> turMap={};
        int cozuldu=0,acik=0;
        for(final doc in docs){
          final d=doc.data() as Map<String,dynamic>;
          final tur=(d['tur']??d['acilTur']??'Diger').toString();
          turMap[tur]=(turMap[tur]??0)+1;
          if(d['durum']=='cozuldu')cozuldu++; else acik++;
        }
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Acil Durum Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _k('Toplam Olay',docs.length.toString(),_navy,Icons.emergency_outlined),
            const SizedBox(width:12),
            _k('Acik Olaylar',acik.toString(),Colors.red,Icons.warning_amber_outlined),
            const SizedBox(width:12),
            _k('Cozuldu',cozuldu.toString(),Colors.green,Icons.check_circle_outline),
          ]),
          const SizedBox(height:24),
          if(turMap.isNotEmpty)...[
            const Text('Olay Turu Dagilimi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:turMap.entries.map((e)=>Padding(
                    padding:const EdgeInsets.only(bottom:8),child:Row(children:[
                  SizedBox(width:120,child:Text(e.key,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                  Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                      child:LinearProgressIndicator(
                          value:docs.isEmpty?0:(e.value/docs.length).clamp(0.0,1.0),
                          minHeight:8,backgroundColor:Colors.grey.withValues(alpha:0.1),
                          valueColor:const AlwaysStoppedAnimation<Color>(Colors.red)))),
                  const SizedBox(width:10),
                  Text(e.value.toString(),style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                ]))).toList())),
          ],
        ]));
      });

  Widget _k(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}



// ─────────────────────────────────────────────────────────────────
//  YAPAY ZEKA MERKEZI – Bolum 24
// ─────────────────────────────────────────────────────────────────
class _YapayZekaSekme extends StatefulWidget{
  final String firmaId;
  const _YapayZekaSekme({required this.firmaId});
  @override State<_YapayZekaSekme> createState()=>_YapayZekaSekmeState();
}
class _YapayZekaSekmeState extends State<_YapayZekaSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.psychology_outlined,'AI Asistan'),
            (1,Icons.auto_graph_outlined,'Akilli Analiz'),
            (2,Icons.table_chart_outlined,'Kod360 / Rapor'),
            (3,Icons.alt_route_outlined,'Rota Motoru'),
            (4,Icons.videocam_outlined,'360 Kamera'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _YzAsistanWeb(firmaId:widget.firmaId),
      _AkilliAnaliz(firmaId:widget.firmaId),
      _Kod360Rapor(firmaId:widget.firmaId),
      _AkilliRotaMotoru(firmaId:widget.firmaId),
      _KameraSistemi(),
    ][_tab]),
  ]);
}

// ── YZ ASISTAN (WEB) ─────────────────────────────────────────────
class _YzAsistanWeb extends StatefulWidget{
  final String firmaId;
  const _YzAsistanWeb({required this.firmaId});
  @override State<_YzAsistanWeb> createState()=>_YzAsistanWebState();
}
class _YzAsistanWebState extends State<_YzAsistanWeb>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  static const _aiProxy='https://us-central1-servis360-15b4a.cloudfunctions.net/aiProxy';

  final _scrollCtrl=ScrollController();
  final _mesajCtrl=TextEditingController();
  final List<Map<String,String>> _mesajlar=[];
  bool _yukleniyor=false;

  @override void dispose(){_scrollCtrl.dispose();_mesajCtrl.dispose();super.dispose();}

  Future<void> _gonder() async{
    final text=_mesajCtrl.text.trim();
    if(text.isEmpty)return;
    setState((){
      _mesajlar.add({'rol':'kullanici','icerik':text});
      _yukleniyor=true;
    });
    _mesajCtrl.clear();
    _scroll();
    try{
      // Firma verisi context
      final firmaDoc=await FirebaseFirestore.instance.collection('firms').doc(widget.firmaId).get();
      final firmaAd=(firmaDoc.data()?['firmaAdi']??'').toString();
      final ogr=await FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:widget.firmaId).count().get();
      final sof=await FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:widget.firmaId).count().get();
      final svc=await FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:widget.firmaId).count().get();

      final sistem='''Servisim360 AI Asistanisin. Firma: $firmaAd. Sistem: ${ogr.count??0} ogrenci, ${sof.count??0} sofor, ${svc.count??0} servis. Turkce yanit ver.''';

      final gMesajlar=<Map<String,String>>[
        {'role':'user','content':sistem+'\n\n'+text},
      ];
      if(_mesajlar.length>1){
        for(final m in _mesajlar.sublist(0,_mesajlar.length-1)){
          gMesajlar.add({'role':m['rol']=='kullanici'?'user':'assistant','content':m['icerik']??''});
        }
      }

      final resp=await FirebaseFirestore.instance.collection('ai_istekler').add({
        'firmaId':widget.firmaId,'soru':text,'tarih':FieldValue.serverTimestamp(),
      });

      // HTTP istegi
      final httpResp=await http.post(Uri.parse(_aiProxy),
          headers:{'Content-Type':'application/json'},
          body:jsonEncode({'messages':[{'role':'user','content':sistem+'\n\n'+text}],'model':'claude-haiku-4-5-20251001','max_tokens':1000}));

      String cevap='AI yaniti alinamadi.';
      if(httpResp.statusCode==200){
        final data=jsonDecode(httpResp.body);
        cevap=data['content']?[0]?['text']??cevap;
        await resp.update({'yanit':cevap});
      }

      setState((){_mesajlar.add({'rol':'ai','icerik':cevap});_yukleniyor=false;});
      _scroll();
    }catch(e){
      setState((){_mesajlar.add({'rol':'ai','icerik':'Hata: '+e.toString()});_yukleniyor=false;});
    }
  }

  void _scroll(){WidgetsBinding.instance.addPostFrameCallback((_){
    if(_scrollCtrl.hasClients)_scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration:const Duration(milliseconds:300),curve:Curves.easeOut);
  });}

  @override Widget build(BuildContext context)=>Column(children:[
    // Header
    Container(padding:const EdgeInsets.all(16),color:Colors.white,
        child:Row(children:[
          Container(padding:const EdgeInsets.all(8),
              decoration:BoxDecoration(color:_navy.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
              child:const Icon(Icons.psychology_outlined,color:_navy,size:22)),
          const SizedBox(width:12),
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('Servisim360 AI Asistani',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
            Text('Firma verilerinizi analiz ederek yardimci olur.',style:TextStyle(color:Colors.grey,fontSize:11)),
          ])),
          // Hizli sorular
          PopupMenuButton<String>(
              icon:const Icon(Icons.lightbulb_outlined,color:_t),
              onSelected:(v){_mesajCtrl.text=v;_gonder();},
              itemBuilder:(_)=>[
                const PopupMenuItem(value:'Servis doluluk oranlarimi analiz et.',child:Text('Doluluk Analizi')),
                const PopupMenuItem(value:'Bu aydaki tahsilat durumumu degerlendir.',child:Text('Tahsilat Analizi')),
                const PopupMenuItem(value:'Hangi sofor en iyi performans gosteriyor?',child:Text('Sofor Performansi')),
                const PopupMenuItem(value:'Yeni servis acmam gerekiyor mu?',child:Text('Servis Onerisi')),
                const PopupMenuItem(value:'Bu ay yapabilecegim iyilestirmeleri onerr.',child:Text('Iyilestirme Onerisi')),
              ]),
        ])),
    // Mesajlar
    Expanded(child:_mesajlar.isEmpty
        ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Container(padding:const EdgeInsets.all(24),
          decoration:BoxDecoration(color:_navy.withValues(alpha:0.06),shape:BoxShape.circle),
          child:const Icon(Icons.psychology_outlined,size:48,color:_navy)),
      const SizedBox(height:16),
      const Text('Servisim360 AI Asistani',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:_navy)),
      const SizedBox(height:8),
      const Text('Firma verilerinizi analiz etmek icin soru sorun.',style:TextStyle(color:Colors.grey)),
    ]))
        : ListView.builder(
        controller:_scrollCtrl,
        padding:const EdgeInsets.all(16),
        itemCount:_mesajlar.length+(_yukleniyor?1:0),
        itemBuilder:(_,i){
          if(i==_mesajlar.length)return Padding(
              padding:const EdgeInsets.only(left:12),
              child:Row(children:[
                Container(padding:const EdgeInsets.all(6),
                    decoration:BoxDecoration(color:_navy.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                    child:const SizedBox(width:16,height:16,
                        child:CircularProgressIndicator(strokeWidth:2,color:_navy))),
                const SizedBox(width:8),
                const Text('Dusunuyor...',style:TextStyle(color:Colors.grey,fontStyle:FontStyle.italic)),
              ]));
          final m=_mesajlar[i];
          final isUser=m['rol']=='kullanici';
          return Align(
              alignment:isUser?Alignment.centerRight:Alignment.centerLeft,
              child:Container(
                  margin:const EdgeInsets.only(bottom:10),
                  constraints:BoxConstraints(maxWidth:MediaQuery.of(context).size.width*0.7),
                  padding:const EdgeInsets.all(14),
                  decoration:BoxDecoration(
                      color:isUser?_navy:Colors.white,
                      borderRadius:BorderRadius.only(
                          topLeft:const Radius.circular(14),topRight:const Radius.circular(14),
                          bottomLeft:Radius.circular(isUser?14:4),
                          bottomRight:Radius.circular(isUser?4:14)),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.06),blurRadius:6)]),
                  child:Text(m['icerik']??'',style:TextStyle(
                      color:isUser?Colors.white:Colors.black87,fontSize:13))));
        })),
    // Giris
    Container(padding:const EdgeInsets.all(12),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(
              controller:_mesajCtrl,
              onSubmitted:(_)=>_gonder(),
              decoration:InputDecoration(
                  hintText:'Soru sorun...',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(24)),
                  contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
                  isDense:true))),
          const SizedBox(width:8),
          GestureDetector(onTap:_gonder,
              child:Container(padding:const EdgeInsets.all(12),
                  decoration:BoxDecoration(color:_t,borderRadius:BorderRadius.circular(24)),
                  child:const Icon(Icons.send_outlined,color:Colors.white,size:20))),
        ])),
  ]);
}

// ── AKILLI ANALIZ ─────────────────────────────────────────────────
class _AkilliAnaliz extends StatelessWidget{
  final String firmaId;
  const _AkilliAnaliz({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(
      future:_oneriler(),
      builder:(_,snap){
        final oneriler=snap.data??[];
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Akilli Sistem Analizi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:8),
          const Text('Yapay zeka firma verilerinizi analiz ediyor.',style:TextStyle(color:Colors.grey)),
          const SizedBox(height:20),
          if(!snap.hasData)const Center(child:CircularProgressIndicator()),
          if(oneriler.isEmpty)Container(padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.07),borderRadius:BorderRadius.circular(12)),
              child:const Row(children:[Icon(Icons.check_circle_outline,color:Colors.green,size:20),SizedBox(width:10),
                Expanded(child:Text('Sistem normal. Onemli bir uyari bulunamadi.',
                    style:TextStyle(color:Colors.green)))])),
          ...oneriler.map((o)=>Container(
              margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                  border:Border.all(color:(o['renk'] as Color).withValues(alpha:0.25)),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
              child:Row(children:[
                Container(padding:const EdgeInsets.all(10),
                    decoration:BoxDecoration(color:(o['renk'] as Color).withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
                    child:Icon(o['ikon'] as IconData,color:o['renk'] as Color,size:22)),
                const SizedBox(width:14),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(o['baslik'] as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                  const SizedBox(height:4),
                  Text(o['mesaj'] as String,style:TextStyle(fontSize:12,color:Colors.grey[600])),
                ])),
              ]))),
        ]));
      });

  Future<List<Map<String,dynamic>>> _oneriler() async{
    final oneriler=<Map<String,dynamic>>[];
    try{
      final snapResults=await Future.wait<QuerySnapshot<Map<String,dynamic>>>([
        FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:firmaId).get(),
        FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).get(),
      ]);
      final countResults=await Future.wait<AggregateQuerySnapshot>([
        FirebaseFirestore.instance.collection('tahsilat').where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'gecikti').count().get(),
        FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).count().get(),
      ]);
      final servisler=snapResults[0].docs;
      final ogrenciler=snapResults[1].docs;
      final geciken=countResults[0].count??0;
      final soforler=countResults[1].count??0;

      // Kapasite analizi
      int topKap=0,topOgr=0;
      for(final s in servisler){
        final d=s.data() as Map<String,dynamic>;
        topKap+=(d['kapasite']??17) as int;
        topOgr+=(d['ogrenciSayisi']??0) as int;
      }
      if(topKap>0&&topOgr/topKap>0.85){
        oneriler.add({'baslik':'Kapasite Uyarisi','renk':Colors.red,'ikon':Icons.warning_amber_outlined,
          'mesaj':'Servisler %'+(topOgr/topKap*100).round().toString()+' dolulukta. Yeni servis acimaniz onerilir.'});
      }
      if(topKap>0&&topOgr/topKap<0.5&&servisler.length>1){
        oneriler.add({'baslik':'Dusuk Doluluk','renk':Colors.orange,'ikon':Icons.info_outline,
          'mesaj':'Servisler %'+(topOgr/topKap*100).round().toString()+' dolulukta. Bazi servisleri birlestirmeyi dusunun.'});
      }
      if(geciken>5){
        oneriler.add({'baslik':'Tahsilat Uyarisi','renk':Colors.red,'ikon':Icons.payments_outlined,
          'mesaj':geciken.toString()+' gecikti tahsilat var. Veli hatirlatmasi gondermelisiniz.'});
      }
      final atanmamis=ogrenciler.where((d)=>(d.data() as Map)['servisId']?.toString().isNotEmpty!=true).length;
      if(atanmamis>0){
        oneriler.add({'baslik':'Atanmamis Ogrenci','renk':Colors.purple,'ikon':Icons.person_off_outlined,
          'mesaj':atanmamis.toString()+' ogrenci henuz servise atanmamis.'});
      }
      if(soforler==0&&ogrenciler.isNotEmpty){
        oneriler.add({'baslik':'Sofor Eksik','renk':Colors.red,'ikon':Icons.person_outlined,
          'mesaj':'Aktif sofor bulunamadi. Sofor eklemeniz gerekiyor.'});
      }
      if(oneriler.isEmpty){
        oneriler.add({'baslik':'Sistem Saglikli','renk':Colors.green,'ikon':Icons.check_circle_outline,
          'mesaj':'Tum moduller normal calisiyor. Buyuk bir problem gozukmuyor.'});
      }
    }catch(_){}
    return oneriler;
  }
}

// ── KOD360 RAPOR ─────────────────────────────────────────────────
class _Kod360Rapor extends StatelessWidget{
  final String firmaId;
  const _Kod360Rapor({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Kod360 Rapor Merkezi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Tek tikla profesyonel raporlar olusturun.',style:TextStyle(color:Colors.grey)),
        const SizedBox(height:20),
        Wrap(spacing:16,runSpacing:16,children:[
          for(final r in [
            ('Ogrenci Listesi',Icons.school_outlined,Colors.blue,'Excel olarak indir'),
            ('Sofor Listesi',Icons.person_outlined,Colors.teal,'Excel olarak indir'),
            ('Tahsilat Raporu',Icons.payments_outlined,Colors.green,'Excel & PDF'),
            ('Servis Listesi',Icons.directions_bus_outlined,_navy,'Excel olarak indir'),
            ('Sozlesme Listesi',Icons.description_outlined,Colors.purple,'PDF olarak indir'),
            ('Devamsizlik Raporu',Icons.event_busy_outlined,Colors.red,'Excel olarak indir'),
          ])
            Container(width:260,padding:const EdgeInsets.all(18),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                    border:Border.all(color:(r.$3 as Color).withValues(alpha:0.2)),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Icon(r.$2 as IconData,color:r.$3 as Color,size:28),
                  const SizedBox(height:10),
                  Text(r.$1 as String,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                  const SizedBox(height:4),
                  Text(r.$4 as String,style:TextStyle(fontSize:11,color:Colors.grey[500])),
                  const SizedBox(height:14),
                  Row(children:[
                    Expanded(child:ElevatedButton.icon(
                        style:ElevatedButton.styleFrom(backgroundColor:r.$3 as Color,
                            foregroundColor:Colors.white,
                            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                        onPressed:()=>_raporOlustur(context,r.$1 as String,firmaId),
                        icon:const Icon(Icons.download_outlined,size:14),
                        label:const Text('Olustur',style:TextStyle(fontSize:12)))),
                  ]),
                ])),
        ]),
        const SizedBox(height:24),
        Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:_t.withValues(alpha:0.07),borderRadius:BorderRadius.circular(12),
                border:Border.all(color:_t.withValues(alpha:0.2))),
            child:const Row(children:[
              Icon(Icons.info_outline,color:Color(0xFFFF8C00),size:18),SizedBox(width:10),
              Expanded(child:Text('Raporlar panoya kopyalanir. Ileri surumlerde Excel/PDF direkt indirme desteklenecektir.',
                  style:TextStyle(fontSize:12,color:Color(0xFFFF8C00)))),
            ])),
      ]));

  void _raporOlustur(BuildContext context,String rapor,String firmaId) async{
    final snack=ScaffoldMessenger.of(context);
    snack.showSnackBar(SnackBar(
        content:Text(rapor+' olusturuluyor...'),
        behavior:SnackBarBehavior.floating,backgroundColor:_navy));
    // Veriyi cek ve panoya kopyala
    try{
      final kolMap={'Ogrenci Listesi':'students','Sofor Listesi':'drivers',
        'Servis Listesi':'services','Devamsizlik Raporu':'absence_requests',
        'Sozlesme Listesi':'sozlesmeler','Tahsilat Raporu':'tahsilat'};
      final kol=kolMap[rapor]??'students';
      final snap=await FirebaseFirestore.instance.collection(kol)
          .where('firmaId',isEqualTo:firmaId).get();
      final buf=StringBuffer();
      buf.writeln('=== '+rapor.toUpperCase()+' ===');
      buf.writeln('Tarih: '+DateTime.now().day.toString()+'.'+DateTime.now().month.toString()+'.'+DateTime.now().year.toString());
      buf.writeln('Kayit Sayisi: '+snap.docs.length.toString());
      buf.writeln('');
      for(final doc in snap.docs.take(50)){
        final d=doc.data() as Map<String,dynamic>;
        buf.writeln((d['ad']??d['ogrenciAd']??doc.id).toString());
      }
      await Clipboard.setData(ClipboardData(text:buf.toString()));
      snack.showSnackBar(SnackBar(
          content:Text(rapor+' panoya kopyalandi ('+snap.docs.length.toString()+' kayit)'),
          behavior:SnackBarBehavior.floating,backgroundColor:Colors.green));
    }catch(e){
      snack.showSnackBar(SnackBar(content:Text('Hata: '+e.toString()),
          backgroundColor:Colors.red,behavior:SnackBarBehavior.floating));
    }
  }
}

// ── AKILLI ROTA MOTORU ────────────────────────────────────────────
class _AkilliRotaMotoru extends StatelessWidget{
  final String firmaId;
  const _AkilliRotaMotoru({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Akilli Rota Motoru',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Yapay zeka destekli rota optimizasyonu.',style:TextStyle(color:Colors.grey)),
        const SizedBox(height:20),
        // Mevcut rota ozeti
        StreamBuilder<QuerySnapshot>(
            stream:FirebaseFirestore.instance.collection('services')
                .where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true).snapshots(),
            builder:(_,snap){
              final servisler=snap.data?.docs??[];
              return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('Mevcut: '+servisler.length.toString()+' aktif servis',
                    style:const TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
                const SizedBox(height:16),
                ...servisler.take(5).map((s){
                  final d=s.data() as Map<String,dynamic>;
                  final ogr=(d['ogrenciSayisi']??0) as int;
                  final kap=(d['kapasite']??17) as int;
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:_navy.withValues(alpha:0.1))),
                      child:Row(children:[
                        const Icon(Icons.alt_route_outlined,color:_navy,size:20),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                          Text(ogr.toString()+'/'+kap.toString()+' ogrenci',
                              style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        ])),
                        ElevatedButton.icon(
                            style:ElevatedButton.styleFrom(backgroundColor:_navy,foregroundColor:Colors.white,
                                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),
                                padding:const EdgeInsets.symmetric(horizontal:12,vertical:8)),
                            onPressed:()=>Navigator.pushNamed(context,'/harita'),
                            icon:const Icon(Icons.route_outlined,size:14),
                            label:const Text('Rota Goster',style:TextStyle(fontSize:11))),
                      ]));
                }),
              ]);
            }),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.06),borderRadius:BorderRadius.circular(12),
                border:Border.all(color:Colors.blue.withValues(alpha:0.2))),
            child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[Icon(Icons.psychology_outlined,color:Colors.blue,size:18),SizedBox(width:8),
                Text('AI Rota Analizi',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.blue,fontSize:14))]),
              SizedBox(height:10),
              Text('Akilli rota motoru;\n• Trafik yogunlugunu analiz eder\n• Yakit tasarrufu hesaplar\n• Ogrenci yakinligina gore gruplar\n\nDetayli rota yonetimi icin Harita & Rota menusu kullanin.',
                  style:TextStyle(fontSize:12,color:Colors.blue)),
            ])),
      ]));
}

// ── 360 KAMERA ───────────────────────────────────────────────────
class _KameraSistemi extends StatelessWidget{
  const _KameraSistemi();
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('360 Kamera Sistemi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Tesla mantigi ile kus bakisi arac goruntuleme.',style:TextStyle(color:Colors.grey)),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(20),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                border:Border.all(color:_navy.withValues(alpha:0.1))),
            child:Column(children:[
              // Kamera duzeni
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                _kamKarti('On Kamera',Icons.camera_front_outlined,Colors.blue),]),
              const SizedBox(height:8),
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                _kamKarti('Sol Kamera',Icons.camera_outlined,Colors.green),
                const SizedBox(width:24),
                Container(width:100,height:60,
                    decoration:BoxDecoration(color:_navy.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                    child:const Center(child:Icon(Icons.directions_bus_outlined,color:_navy,size:36))),
                const SizedBox(width:24),
                _kamKarti('Sag Kamera',Icons.camera_outlined,Colors.green),
              ]),
              const SizedBox(height:8),
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                _kamKarti('Ic Kamera',Icons.videocam_outlined,Colors.purple),
                const SizedBox(width:16),
                _kamKarti('Arka Kamera',Icons.camera_rear_outlined,Colors.orange),
              ]),
            ])),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.08),borderRadius:BorderRadius.circular(12),
                border:Border.all(color:Colors.orange.withValues(alpha:0.2))),
            child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[Icon(Icons.construction_outlined,color:Colors.orange,size:18),SizedBox(width:8),
                Text('Donanim Gerektiriyor',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.orange,fontSize:14))]),
              SizedBox(height:10),
              Text('360 kamera sistemi Ducato/Crafter/Sprinter araclara monte edilecek IP kamera altyapisi gerektirir.\n\nDesteklenen kameralar:\n• IP Kamera (RTSP)\n• ONVIF uyumlu guvenlik kameralari\n\nYakin donemde canliya alinacaktir.',
                  style:TextStyle(fontSize:12,color:Colors.orange)),
            ])),
      ]));

  Widget _kamKarti(String ad,IconData ikon,Color renk)=>Column(children:[
    Container(padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:renk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
        child:Icon(ikon,color:renk,size:20)),
    const SizedBox(height:4),
    Text(ad,style:const TextStyle(fontSize:9,color:Colors.grey)),
  ]);
}


class _GuvenlikSekme extends StatefulWidget{
  final String firmaId;
  const _GuvenlikSekme({required this.firmaId});
  @override State<_GuvenlikSekme> createState()=>_GuvenlikSekmeState();
}
class _GuvenlikSekmeState extends State<_GuvenlikSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:SingleChildScrollView(
        scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in [
            (0,Icons.admin_panel_settings_outlined,'Rol Matrisi'),
            (1,Icons.people_outline,'Kullanici Yetkileri'),
            (2,Icons.history_outlined,'Islem Loglari'),
            (3,Icons.login_outlined,'Giris Loglari'),
            (4,Icons.shield_outlined,'Guvenlik Raporu'),
          ])
            GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                    decoration:BoxDecoration(border:Border(bottom:BorderSide(
                        color:_tab==t.$1?_t:Colors.transparent,width:2))),
                    child:Row(children:[
                      Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                      const SizedBox(width:6),
                      Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                          color:_tab==t.$1?_navy:Colors.grey)),
                    ]))),
        ]))),
    Expanded(child:[
      _RolMatrisi(),
      _KullaniciYetkileri(firmaId:widget.firmaId),
      _IslemLoglari(firmaId:widget.firmaId),
      _GirisLoglari(firmaId:widget.firmaId),
      _GuvenlikRaporu(firmaId:widget.firmaId),
    ][_tab]),
  ]);
}

// ── ROL MATRISI ──────────────────────────────────────────────────
class _RolMatrisi extends StatelessWidget{
  const _RolMatrisi();
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Sistem Rol Matrisi',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Her kullanicinin ne gorebilecegini ve ne yapabilecegini tanimlar.',
            style:TextStyle(color:Colors.grey,fontSize:12)),
        const SizedBox(height:20),
        // Rol kartlari
        for(final rol in _roller)...[
          Container(margin:const EdgeInsets.only(bottom:16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                  border:Border.all(color:(rol['renk'] as Color).withValues(alpha:0.2)),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
              child:Column(children:[
                // Header
                Container(padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(
                        color:(rol['renk'] as Color).withValues(alpha:0.07),
                        borderRadius:const BorderRadius.vertical(top:Radius.circular(16))),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(10),
                          decoration:BoxDecoration(color:(rol['renk'] as Color).withValues(alpha:0.15),
                              borderRadius:BorderRadius.circular(10)),
                          child:Icon(rol['ikon'] as IconData,color:rol['renk'] as Color,size:22)),
                      const SizedBox(width:14),
                      Text(rol['ad'] as String,
                          style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:rol['renk'] as Color)),
                    ])),
                // Izinler
                Padding(padding:const EdgeInsets.all(16),child:Row(
                    crossAxisAlignment:CrossAxisAlignment.start,children:[
                  // Gorebilir
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Row(children:[Icon(Icons.check_circle_outline,color:Colors.green,size:14),
                      SizedBox(width:4),Text('Gorebilir',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.green,fontSize:12))]),
                    const SizedBox(height:6),
                    ...(rol['gorebilir'] as List<String>).map((s)=>Padding(
                        padding:const EdgeInsets.only(bottom:3),
                        child:Row(children:[
                          const Icon(Icons.arrow_right,size:14,color:Colors.green),
                          Expanded(child:Text(s,style:const TextStyle(fontSize:11))),
                        ]))),
                  ])),
                  const SizedBox(width:16),
                  // Goremez
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Row(children:[Icon(Icons.cancel_outlined,color:Colors.red,size:14),
                      SizedBox(width:4),Text('Goremez/Yapamaz',style:TextStyle(fontWeight:FontWeight.bold,color:Colors.red,fontSize:12))]),
                    const SizedBox(height:6),
                    ...(rol['goremez'] as List<String>).map((s)=>Padding(
                        padding:const EdgeInsets.only(bottom:3),
                        child:Row(children:[
                          const Icon(Icons.close,size:12,color:Colors.red),
                          const SizedBox(width:2),
                          Expanded(child:Text(s,style:const TextStyle(fontSize:11))),
                        ]))),
                  ])),
                ])),
              ])),
        ],
      ]));

  static const List<Map<String,dynamic>> _roller=[
    {
      'ad':'Super Admin','renk':Color(0xFF6200EA),'ikon':Icons.admin_panel_settings_outlined,
      'gorebilir':['Tum firmalar','Lisanslar','Sistem istatistikleri','Hata kayitlari','Destek talepleri'],
      'goremez':['Ogrenci duzenleme','Tahsilat duzenleme','Gunluk servis yonetimi'],
    },
    {
      'ad':'Firma Admini','renk':Color(0xFF1a3a6b),'ikon':Icons.business_outlined,
      'gorebilir':['Kendi projeleri','Kendi soforleri','Kendi ogrencileri','Kendi tahsilatlari','Raporlar'],
      'goremez':['Baska firma verileri','Baska firma ogrencileri','Sistem ayarlari'],
    },
    {
      'ad':'Sofor','renk':Colors.teal,'ikon':Icons.directions_bus_outlined,
      'gorebilir':['Atandigi servisler','Atandigi ogrenciler','Kendi gorevleri'],
      'goremez':['Tahsilat','Fiyatlandirma','Sozlesme duzenleme','Baska soforler'],
    },
    {
      'ad':'Veli','renk':Colors.orange,'ikon':Icons.family_restroom_outlined,
      'gorebilir':['Kendi ogrencisi','Kendi servisi','Kendi odemesi','Kendi bildirimleri'],
      'goremez':['Baska veliler','Baska ogrenciler','Firma bilgileri','Tahsilat detaylari'],
    },
  ];
}

// ── KULLANICI YETKILERI ───────────────────────────────────────────
class _KullaniciYetkileri extends StatelessWidget{
  final String firmaId;
  const _KullaniciYetkileri({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:const Row(children:[
          Icon(Icons.people_outline,color:_navy,size:18),SizedBox(width:8),
          Text('Kullanici Yetki Listesi',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('kullanicilar')
            .where('firmaId',isEqualTo:firmaId).orderBy('rol').snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Kullanici bulunamadi','',Icons.people_outline);
          // Rol bazli grupla
          final Map<String,List<Map<String,dynamic>>> rolMap={};
          for(final doc in docs){
            final d={...doc.data() as Map<String,dynamic>,'id':doc.id};
            final rol=(d['rol']??'diger').toString();
            rolMap.putIfAbsent(rol,()=>[]);
            rolMap[rol]!.add(d);
          }
          return ListView(padding:const EdgeInsets.all(16),children:[
            for(final entry in rolMap.entries)...[
              Padding(padding:const EdgeInsets.only(bottom:8,top:8),
                  child:Text(entry.key.toUpperCase(),
                      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:11,color:Colors.grey,letterSpacing:1))),
              ...entry.value.map((d){
                final rolRenk=_rolRenk(d['rol']??'');
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.all(12),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border.all(color:rolRenk.withValues(alpha:0.2)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                    child:Row(children:[
                      CircleAvatar(radius:18,backgroundColor:rolRenk.withValues(alpha:0.1),
                          child:Text((d['ad']??'?')[0].toUpperCase(),
                              style:TextStyle(color:rolRenk,fontWeight:FontWeight.bold,fontSize:12))),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??d['email']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(d['email']??'',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ])),
                      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                          decoration:BoxDecoration(color:rolRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Text(d['rol']??'',style:TextStyle(fontSize:10,color:rolRenk,fontWeight:FontWeight.bold))),
                    ]));
              }),
            ],
          ]);
        })),
  ]);

  Color _rolRenk(String rol){
    switch(rol){
      case 'superAdmin': return const Color(0xFF6200EA);
      case 'firmaAdmin': return const Color(0xFF1a3a6b);
      case 'sofor': return Colors.teal;
      case 'veli': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

// ── ISLEM LOGLARI ────────────────────────────────────────────────
class _IslemLoglari extends StatefulWidget{
  final String firmaId;
  const _IslemLoglari({required this.firmaId});
  @override State<_IslemLoglari> createState()=>_IslemLoglariState();
}
class _IslemLoglariState extends State<_IslemLoglari>{
  static const _navy=Color(0xFF1a3a6b);
  String _filtre='hepsi';

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          const Text('Islem Kayitlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          for(final f in [('hepsi','Tumu'),('ogrenci','Ogrenci'),('tahsilat','Tahsilat'),('giris','Giris')])
            GestureDetector(onTap:()=>setState(()=>_filtre=f.$1),
                child:Container(margin:const EdgeInsets.only(left:6),
                    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                    decoration:BoxDecoration(color:_filtre==f.$1?_navy:Colors.grey[100],
                        borderRadius:BorderRadius.circular(6)),
                    child:Text(f.$2,style:TextStyle(fontSize:10,fontWeight:FontWeight.w600,
                        color:_filtre==f.$1?Colors.white:Colors.grey)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:(){
          var q=FirebaseFirestore.instance.collection('islem_loglari')
              .where('firmaId',isEqualTo:widget.firmaId);
          if(_filtre!='hepsi')q=q.where('modul',isEqualTo:_filtre);
          return q.orderBy('tarih',descending:true).limit(100).snapshots();
        }(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Log kaydi yok','Islemler otomatik kaydedilir.',Icons.history_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                    dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                final islem=(d['islem']??d['aksiyon']??'').toString();
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border(left:BorderSide(color:_navy.withValues(alpha:0.3),width:2))),
                    child:Row(children:[
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Row(children:[
                          Text(d['kullaniciAd']??d['yapanId']??'',
                              style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                          const SizedBox(width:8),
                          if(islem.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:2),
                              decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(4)),
                              child:Text(islem,style:TextStyle(fontSize:10,color:_navy))),
                        ]),
                        if((d['detay']??d['aciklama']??'').isNotEmpty)
                          Text(d['detay']??d['aciklama']??'',
                              style:TextStyle(fontSize:11,color:Colors.grey[500]),
                              maxLines:1,overflow:TextOverflow.ellipsis),
                      ])),
                      Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                    ]));
              });
        })),
  ]);
}

// ── GIRIS LOGLARI ────────────────────────────────────────────────
class _GirisLoglari extends StatelessWidget{
  final String firmaId;
  const _GirisLoglari({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:const Row(children:[
          Icon(Icons.login_outlined,color:_navy,size:18),SizedBox(width:8),
          Text('Giris Kayitlari',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection('giris_loglari')
            .where('firmaId',isEqualTo:firmaId)
            .orderBy('tarih',descending:true).limit(100).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Giris kaydi yok','',Icons.login_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final basarili=d['basarili']??d['success']??true;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString()+' '+
                    dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border(left:BorderSide(
                            color:basarili?Colors.green:Colors.red,width:2))),
                    child:Row(children:[
                      Icon(basarili?Icons.check_circle_outline:Icons.error_outline,
                          color:basarili?Colors.green:Colors.red,size:16),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['email']??d['kullaniciAd']??'',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                        Text(d['rol']??'',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ])),
                      Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                    ]));
              });
        })),
  ]);
}

// ── GUVENLIK RAPORU ──────────────────────────────────────────────
class _GuvenlikRaporu extends StatelessWidget{
  final String firmaId;
  const _GuvenlikRaporu({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data!;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Guvenlik Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _k('Toplam Kullanici',(data['toplamKullanici']??0).toString(),_navy,Icons.people_outline),
            const SizedBox(width:12),
            _k('Basarisiz Giris',(data['basarisizGiris']??0).toString(),Colors.red,Icons.warning_outlined),
            const SizedBox(width:12),
            _k('Bugun Giris',(data['bugunGiris']??0).toString(),Colors.green,Icons.login_outlined),
            const SizedBox(width:12),
            _k('Islem Kaydi',(data['islemSayi']??0).toString(),Colors.teal,Icons.history_outlined),
          ]),
          const SizedBox(height:24),
          // Guvenlik kurallari ozeti
          Container(padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Aktif Guvenlik Kurallari',
                    style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
                const SizedBox(height:14),
                for(final kural in [
                  'firmaId izolasyonu aktif — firmalar birbirini goremiyor',
                  'Veli izolasyonu aktif — veliler sadece kendi cocugunu goruyor',
                  'Sofor izolasyonu aktif — soforler sadece atandiklari servisleri goruyor',
                  'Kulici istatistikleri aktif — tum islemler loglaniyor',
                  'Kalici silme devre disi — arsivleme sistemi aktif',
                  'Rol bazli erisim kontrolu aktif',
                ])Padding(padding:const EdgeInsets.only(bottom:8),
                    child:Row(children:[
                      const Icon(Icons.check_circle,color:Colors.green,size:16),
                      const SizedBox(width:10),
                      Expanded(child:Text(kural,style:const TextStyle(fontSize:12))),
                    ])),
              ])),
          const SizedBox(height:16),
          Container(padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.blue.withValues(alpha:0.05),
                  borderRadius:BorderRadius.circular(12),
                  border:Border.all(color:Colors.blue.withValues(alpha:0.2))),
              child:const Row(children:[
                Icon(Icons.info_outline,color:Colors.blue,size:18),SizedBox(width:10),
                Expanded(child:Text('Guvenlik kurallari Firestore Security Rules ile desteklenmektedir. '
                    'Sunucu tarafinda da firmaId kontrolu yapilmaktadir.',
                    style:TextStyle(fontSize:12,color:Colors.blue))),
              ])),
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      final bugun=DateTime.now();
      final bugunStart=Timestamp.fromDate(DateTime(bugun.year,bugun.month,bugun.day));
      final results=await Future.wait([
        FirebaseFirestore.instance.collection('kullanicilar').where('firmaId',isEqualTo:firmaId).count().get(),
        FirebaseFirestore.instance.collection('giris_loglari').where('firmaId',isEqualTo:firmaId)
            .where('basarili',isEqualTo:false).count().get(),
        FirebaseFirestore.instance.collection('giris_loglari').where('firmaId',isEqualTo:firmaId)
            .where('tarih',isGreaterThanOrEqualTo:bugunStart).count().get(),
        FirebaseFirestore.instance.collection('islem_loglari').where('firmaId',isEqualTo:firmaId).count().get(),
      ]);
      return{
        'toplamKullanici':results[0].count??0,'basarisizGiris':results[1].count??0,
        'bugunGiris':results[2].count??0,'islemSayi':results[3].count??0,
      };
    }catch(_){return{};}
  }

  Widget _k(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2))),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}



// ─── DASHBOARD TAHSILAT OZETI ────────────────────────────────
class _DashTahsilatOzeti extends StatelessWidget{
  final String firmaId;
  const _DashTahsilatOzeti({required this.firmaId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,dynamic>>(
      future:_veri(),
      builder:(_,snap){
        if(!snap.hasData)return const SizedBox();
        final d=snap.data!;
        return Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
            boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Padding(padding:const EdgeInsets.all(14),
                  child:Row(children:[
                    const Icon(Icons.account_balance_wallet_outlined,color:_navy,size:16),
                    const SizedBox(width:8),
                    const Text('Tahsilat Ozeti',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:13)),
                  ])),
              const Divider(height:1),
              Padding(padding:const EdgeInsets.all(14),child:Column(children:[
                _satir('Bu Ay Tahsil',(d['buAy']??0).toStringAsFixed(0)+' TL',Colors.green),
                const SizedBox(height:6),
                _satir('Bekleyen',(d['bekleyen']??0).toStringAsFixed(0)+' TL',Colors.orange),
                const SizedBox(height:6),
                _satir('Geciken',(d['geciken']??0).toStringAsFixed(0)+' TL',Colors.red),
              ])),
            ]));
      });

  Future<Map<String,dynamic>> _veri() async{
    try{
      final now=DateTime.now();
      final ayBas=Timestamp.fromDate(DateTime(now.year,now.month,1));
      final snap=await FirebaseFirestore.instance.collection('tahsilat')
          .where('firmaId',isEqualTo:firmaId).get();
      double buAy=0,bekleyen=0,geciken=0;
      for(final doc in snap.docs){
        final d=doc.data();
        final tutar=(d['tutar'] as num?)?.toDouble()??0;
        if(d['durum']=='odendi'){
          final ts=d['tarih'];
          if(ts is Timestamp&&ts.seconds>=ayBas.seconds)buAy+=tutar;
        }else if(d['durum']=='gecikti')geciken+=tutar;
        else bekleyen+=tutar;
      }
      return{'buAy':buAy,'bekleyen':bekleyen,'geciken':geciken};
    }catch(_){return{};}
  }

  Widget _satir(String b,String v,Color r)=>Row(children:[
    Expanded(child:Text(b,style:const TextStyle(fontSize:11,color:Colors.grey))),
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:r)),
  ]);
}


//  YAKLASAN SERVISLER
class _YaklasanServislerEski extends StatelessWidget{
  final String firmaId;final void Function(int) onNavigate;
  const _YaklasanServislerEski({required this.firmaId,required this.onNavigate});
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
class _AracUyarilar extends StatelessWidget{
  final String firmaId;final void Function(int) onNavigate;
  const _AracUyarilar({required this.firmaId,required this.onNavigate});
  @override Widget build(BuildContext context)=>StreamBuilder<QuerySnapshot>(
      stream:FirebaseFirestore.instance.collection('vehicles').where('firmaId',isEqualTo:firmaId).snapshots(),
      builder:(_,snap){
        final docs=snap.data?.docs??[];
        final otuz=DateTime.now().add(const Duration(days:30));
        final uyarilar=docs.where((d){
          final data=d.data() as Map<String,dynamic>;
          bool u=false;
          final muayene=data['muayeneTarihi'];
          final sigorta=data['sigortaTarihi'];
          if(muayene is Timestamp && muayene.toDate().isBefore(otuz)) u=true;
          if(sigorta is Timestamp && sigorta.toDate().isBefore(otuz)) u=true;
          return u;
        }).toList();
        if(uyarilar.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            const Icon(Icons.warning_amber_outlined,color:Colors.orange,size:16),
            const SizedBox(width:6),
            Text(uyarilar.length.toString()+' Arac Evrak Uyarisi',
                style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:Colors.orange)),
            const Spacer(),
            GestureDetector(onTap:()=>onNavigate(19),
                child:const Text('Arac Merkezi',style:TextStyle(color:Color(0xFF1a3a6b),fontSize:12,fontWeight:FontWeight.bold))),
          ]),
          const SizedBox(height:8),
          ...uyarilar.take(3).map((doc){
            final d=doc.data() as Map<String,dynamic>;
            final plaka=(d['plaka']??'-').toString();
            final muayene=d['muayeneTarihi'];
            final sigorta=d['sigortaTarihi'];
            final List<String> uyariMetin=[];
            if(muayene is Timestamp && muayene.toDate().isBefore(otuz)){
              final kalan=muayene.toDate().difference(DateTime.now()).inDays;
              uyariMetin.add('Muayene: '+kalan.toString()+'g');
            }
            if(sigorta is Timestamp && sigorta.toDate().isBefore(otuz)){
              final kalan=sigorta.toDate().difference(DateTime.now()).inDays;
              uyariMetin.add('Sigorta: '+kalan.toString()+'g');
            }
            return Container(
              margin:const EdgeInsets.only(bottom:6),
              padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
              decoration:BoxDecoration(
                  color:Colors.orange.withValues(alpha:0.06),
                  borderRadius:BorderRadius.circular(8),
                  border:Border.all(color:Colors.orange.withValues(alpha:0.2))),
              child:Row(children:[
                const Icon(Icons.directions_car_outlined,color:Colors.orange,size:16),
                const SizedBox(width:8),
                Text(plaka,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                const SizedBox(width:8),
                Expanded(child:Text(uyariMetin.join('  |  '),
                    style:const TextStyle(fontSize:11,color:Colors.orange))),
              ]),
            );
          }),
        ]);
      });
}

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




// ─── OGRENCILER SEKMESI (inline - import gerektirmez) ────────────
class _WebOgrencilerSekme extends StatefulWidget{
  final String firmaId;
  const _WebOgrencilerSekme({required this.firmaId});
  @override State<_WebOgrencilerSekme> createState()=>_WebOgrencilerSekmeState();
}
class _WebOgrencilerSekmeState extends State<_WebOgrencilerSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:Row(children:[
      for(final t in [(0,'Tum Ogrenciler'),(1,'Veliler'),(2,'Basvurular')])
        GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                decoration:BoxDecoration(border:Border(bottom:BorderSide(
                    color:_tab==t.$1?_t:Colors.transparent,width:2))),
                child:Text(t.$2,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                    color:_tab==t.$1?_navy:Colors.grey)))),
    ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:FirebaseFirestore.instance.collection(
            _tab==1?'parents':_tab==2?'kayit_basvurulari':'students')
            .where('firmaId',isEqualTo:widget.firmaId)
            .where('aktif',isEqualTo:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Kayit bulunamadi','',Icons.school_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ad=(d['ad']??d['ogrenciAd']??d['veliAd']??'').toString();
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.all(12),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:4)]),
                    child:Row(children:[
                      CircleAvatar(radius:18,backgroundColor:_navy.withValues(alpha:0.1),
                          child:Text(ad.isNotEmpty?ad[0]:'?',style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(ad,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                        Text(d['adres']??d['okul']??'',style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ])),
                      Text(d['fiyat']!=null?d['fiyat'].toString()+' TL':'',
                          style:const TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:12)),
                    ]));
              });
        })),
  ]);
}

// ─── RAPORLAR SEKMESI (inline) ────────────────────────────────────
class _WebRaporlarSekme extends StatefulWidget{
  final String firmaId;
  final String projeId;
  const _WebRaporlarSekme({required this.firmaId,required this.projeId});
  @override State<_WebRaporlarSekme> createState()=>_WebRaporlarSekmeState();
}
class _WebRaporlarSekmeState extends State<_WebRaporlarSekme>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;

  @override Widget build(BuildContext context)=>Column(children:[
    Container(color:Colors.white,child:Row(children:[
      for(final t in [(0,'Genel Durum'),(1,'Ogrenci'),(2,'Sofor'),(3,'Servis'),(4,'Tahsilat')])
        GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                decoration:BoxDecoration(border:Border(bottom:BorderSide(
                    color:_tab==t.$1?_t:Colors.transparent,width:2))),
                child:Text(t.$2,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                    color:_tab==t.$1?_navy:Colors.grey)))),
    ])),
    Expanded(child:FutureBuilder<Map<String,int>>(
        future:_istatistik(),
        builder:(_,snap){
          if(!snap.hasData)return const Center(child:CircularProgressIndicator());
          final d=snap.data!;
          return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('Genel Durum Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:20),
            Wrap(spacing:16,runSpacing:16,children:[
              for(final k in [
                ('Toplam Ogrenci',d['ogrenci']??0,Icons.school_outlined,_navy),
                ('Toplam Sofor',d['sofor']??0,Icons.person_outlined,Colors.teal),
                ('Toplam Servis',d['servis']??0,Icons.directions_bus_outlined,Colors.green),
                ('Bekleyen Tahsilat',d['tahsilat']??0,Icons.payments_outlined,Colors.orange),
              ])Container(width:180,padding:const EdgeInsets.all(16),
                  decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                      border:Border.all(color:(k.$4 as Color).withValues(alpha:0.2)),
                      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Icon(k.$3 as IconData,color:k.$4 as Color,size:20),
                    const SizedBox(height:8),
                    Text(k.$2.toString(),style:TextStyle(fontWeight:FontWeight.bold,fontSize:22,color:k.$4 as Color)),
                    Text(k.$1 as String,style:const TextStyle(fontSize:11,color:Colors.grey)),
                  ])),
            ]),
          ]));
        })),
  ]);

  Future<Map<String,int>> _istatistik() async{
    try{
      final r=await Future.wait<AggregateQuerySnapshot>([
        FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true).count().get(),
        FirebaseFirestore.instance.collection('drivers').where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true).count().get(),
        FirebaseFirestore.instance.collection('services').where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true).count().get(),
        FirebaseFirestore.instance.collection('tahsilat').where('firmaId',isEqualTo:widget.firmaId).where('durum',isEqualTo:'bekleyen').count().get(),
      ]);
      return{'ogrenci':r[0].count??0,'sofor':r[1].count??0,'servis':r[2].count??0,'tahsilat':r[3].count??0};
    }catch(_){return{};}
  }
}


Widget _bos(String b,String a,IconData i)=>Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
  Icon(i,size:64,color:Colors.grey[300]),const SizedBox(height:14),
  Text(b,style:const TextStyle(fontSize:16,color:Colors.grey,fontWeight:FontWeight.bold)),
  if(a.isNotEmpty)...[const SizedBox(height:8),Text(a,style:TextStyle(fontSize:13,color:Colors.grey[400]),textAlign:TextAlign.center)],
]));

// Web'de RotalarScreen'i AppBar olmadan goster
// ─────────────────────────────────────────────────────────────────
//  TAHSILAT SEKMESI
// ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────
//  TAHSILAT BOLUM 13 – YENI CLASS'LAR
// ─────────────────────────────────────────────────────────────────

// ── GENEL DURUM ──────────────────────────────────────────────────
class _TahsilatGenelDurum extends StatelessWidget{
  final String firmaId,projeId;
  const _TahsilatGenelDurum({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data as Map<String,dynamic>;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Tahsilat Genel Durumu',
              style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          // Ana kartlar
          Row(children:[
            _kart('Toplam Tahsilat',(data['toplamTahsilat']??0).toStringAsFixed(0)+' TL',_navy,Icons.account_balance_wallet_outlined),
            const SizedBox(width:12),
            _kart('Bu Ay Tahsil',(data['buAyTahsil']??0).toStringAsFixed(0)+' TL',Colors.green,Icons.trending_up_outlined),
            const SizedBox(width:12),
            _kart('Bekleyen',(data['bekleyen']??0).toStringAsFixed(0)+' TL',Colors.orange,Icons.pending_outlined),
            const SizedBox(width:12),
            _kart('Geciken',(data['geciken']??0).toStringAsFixed(0)+' TL',Colors.red,Icons.warning_amber_outlined),
          ]),
          const SizedBox(height:16),
          Row(children:[
            _kart('Toplam Ogrenci',(data['toplamOgrenci']??0).toString(),Colors.blue,Icons.school_outlined),
            const SizedBox(width:12),
            _kart('Odeme Yapan',(data['odemeYapan']??0).toString(),Colors.green,Icons.check_circle_outline),
            const SizedBox(width:12),
            _kart('Borclu',(data['borclu']??0).toString(),Colors.red,Icons.person_off_outlined),
            const SizedBox(width:12),
            _kart('Tahsilat Orani',(data['oran']??'0')+'%',Colors.teal,Icons.donut_small_outlined),
          ]),
          const SizedBox(height:24),
          // Tahsilat orani progress
          Container(padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('Tahsilat Orani',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
                const SizedBox(height:14),
                Row(children:[
                  Text((data['oran']??'0')+'%',
                      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:32,color:_navy)),
                  const SizedBox(width:12),
                  const Text('tahsil edildi',style:TextStyle(color:Colors.grey,fontSize:14)),
                ]),
                const SizedBox(height:12),
                ClipRRect(borderRadius:BorderRadius.circular(8),
                    child:LinearProgressIndicator(
                        value:(double.tryParse((data['oran']??'0').toString().replaceAll('%',''))??0)/100,
                        minHeight:16,
                        backgroundColor:Colors.grey.withValues(alpha:0.15),
                        valueColor:const AlwaysStoppedAnimation<Color>(Colors.green))),
              ])),
          const SizedBox(height:20),
          // Aylik ozet
          if((data['aylikOzet'] as List).isNotEmpty)...[
            const Text('Aylik Ozet',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:14)),
            const SizedBox(height:10),
            Container(padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                child:Column(children:(data['aylikOzet'] as List<Map<String,dynamic>>).map((a)=>
                    Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
                      SizedBox(width:80,child:Text(a['ay'],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                      Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                          child:LinearProgressIndicator(
                              value:(a['oran'] as double).clamp(0.0,1.0),minHeight:8,
                              backgroundColor:Colors.grey.withValues(alpha:0.1),
                              valueColor:const AlwaysStoppedAnimation<Color>(Colors.green)))),
                      const SizedBox(width:10),
                      Text((a['tutar'] as num).toStringAsFixed(0)+' TL',
                          style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                    ]))).toList())),
          ],
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      var q=FirebaseFirestore.instance.collection('tahsilat').where('firmaId',isEqualTo:firmaId);
      if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
      final snap=await q.get();
      final docs=snap.docs;

      double toplam=0,bekleyen=0,geciken=0,buAy=0;
      final Map<String,double> aylik={};
      final now=DateTime.now();

      for(final doc in docs){
        final d=doc.data() as Map<String,dynamic>;
        final tutar=(d['tutar'] as num?)?.toDouble()??0;
        final durum=d['durum']??'bekliyor';
        final ts=d['tarih'];
        if(durum=='odendi'){
          toplam+=tutar;
          if(ts is Timestamp){
            final dt=ts.toDate();
            if(dt.year==now.year&&dt.month==now.month)buAy+=tutar;
            final ayKey=['Oca','Sub','Mar','Nis','May','Haz','Tem','Agu','Eyl','Eki','Kas','Ara'][dt.month-1];
            aylik[ayKey]=(aylik[ayKey]??0)+tutar;
          }
        }
        else if(durum=='gecikti')geciken+=tutar;
        else bekleyen+=tutar;
      }

      // Ogrenci sayilari
      var ogrQ=FirebaseFirestore.instance.collection('students').where('firmaId',isEqualTo:firmaId);
      if(projeId.isNotEmpty)ogrQ=ogrQ.where('projeId',isEqualTo:projeId);
      final ogrSnap=await ogrQ.count().get();
      final toplamOgr=ogrSnap.count??0;

      // Odeme yapan ogrenci sayisi
      final odeyenQuery=await FirebaseFirestore.instance.collection('tahsilat')
          .where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'odendi').get();
      final odeyenOgrSet=odeyenQuery.docs.map((d)=>(d.data() as Map)['ogrenciId']).toSet();
      final odemeYapan=odeyenOgrSet.length;

      final totalBorc=toplam+bekleyen+geciken;
      final oran=totalBorc>0?((toplam/totalBorc)*100).round().toString():'0';

      final aylikOzet=aylik.entries.take(6).map((e)=>({
        'ay':e.key,'tutar':e.value,
        'oran':aylik.values.isEmpty?0.0:(e.value/aylik.values.reduce((a,b)=>a>b?a:b)).clamp(0.0,1.0),
      } as Map<String,dynamic>)).toList();

      return{
        'toplamTahsilat':toplam,'buAyTahsil':buAy,
        'bekleyen':bekleyen,'geciken':geciken,
        'toplamOgrenci':toplamOgr,'odemeYapan':odemeYapan,
        'borclu':toplamOgr-odemeYapan,'oran':oran,'aylikOzet':aylikOzet,
      };
    }catch(_){return{'aylikOzet':[]};}
  }

  Widget _kart(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}

// ── OGRENCI KARTLARI ─────────────────────────────────────────────
class _OgrenciKartlari extends StatefulWidget{
  final String firmaId,projeId;
  const _OgrenciKartlari({required this.firmaId,required this.projeId});
  @override State<_OgrenciKartlari> createState()=>_OgrenciKartlariState();
}
class _OgrenciKartlariState extends State<_OgrenciKartlari>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  final _aramaCtrl=TextEditingController();
  String _arama='';

  @override void dispose(){_aramaCtrl.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(
              controller:_aramaCtrl,
              onChanged:(v)=>setState(()=>_arama=v.toLowerCase()),
              decoration:InputDecoration(hintText:'Ogrenci ara...',
                  prefixIcon:const Icon(Icons.search,size:18,color:Colors.grey),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
        ])),
    Expanded(child:StreamBuilder<QuerySnapshot>(
        stream:(){
          var q=FirebaseFirestore.instance.collection('students')
              .where('firmaId',isEqualTo:widget.firmaId)
              .where('aktif',isEqualTo:true);
          if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
          return q.orderBy('ad').snapshots();
        }(),
        builder:(_,snap){
          var docs=snap.data?.docs??[];
          if(_arama.isNotEmpty){
            docs=docs.where((d){
              final dd=d.data() as Map<String,dynamic>;
              return (dd['ad']??'').toString().toLowerCase().contains(_arama);
            }).toList();
          }
          if(docs.isEmpty)return _bos('Ogrenci bulunamadi','',Icons.school_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ogrId=docs[i].id;
                final aylikUcret=(d['fiyat']??d['ucret']??0) as num;
                return FutureBuilder<Map<String,dynamic>>(
                    future:_ogrenciTahsilat(ogrId),
                    builder:(ctx,tahSnap){
                      final tah=tahSnap.data??{};
                      final odendi=(tah['odendi']??0.0) as double;
                      final kalan=(aylikUcret.toDouble()*((tah['kayitSayisi']??1) as int))-odendi;
                      return Container(margin:const EdgeInsets.only(bottom:10),
                          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                              boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                          child:Column(children:[
                            // Header
                            Padding(padding:const EdgeInsets.all(14),child:Row(children:[
                              CircleAvatar(radius:22,backgroundColor:_navy.withValues(alpha:0.1),
                                  child:Text((d['ad']??'?')[0].toUpperCase(),
                                      style:const TextStyle(color:_navy,fontWeight:FontWeight.bold))),
                              const SizedBox(width:12),
                              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                                Text((d['servisAd']??d['adres']??'').toString(),
                                    style:TextStyle(fontSize:11,color:Colors.grey[500]),
                                    maxLines:1,overflow:TextOverflow.ellipsis),
                              ])),
                              // Odeme durumu
                              Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                                Text(aylikUcret.toString()+' TL/ay',
                                    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:_navy)),
                                Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                                    decoration:BoxDecoration(
                                        color:(kalan>0?Colors.orange:Colors.green).withValues(alpha:0.1),
                                        borderRadius:BorderRadius.circular(6)),
                                    child:Text(kalan>0?'Kalan: '+kalan.toStringAsFixed(0)+' TL':'Odendi',
                                        style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,
                                            color:kalan>0?Colors.orange:Colors.green))),
                              ]),
                            ])),
                            // Istatistik cubugu
                            Padding(padding:const EdgeInsets.only(left:14,right:14,bottom:12),
                                child:Row(children:[
                                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                    Row(children:[
                                      Text('Odendi: '+odendi.toStringAsFixed(0)+' TL',
                                          style:const TextStyle(fontSize:11,color:Colors.green)),
                                      const Spacer(),
                                      Text('Borclu: '+(kalan>0?kalan.toStringAsFixed(0):0.toStringAsFixed(0))+' TL',
                                          style:TextStyle(fontSize:11,color:kalan>0?Colors.red:Colors.grey)),
                                    ]),
                                    const SizedBox(height:4),
                                    ClipRRect(borderRadius:BorderRadius.circular(4),
                                        child:LinearProgressIndicator(
                                            value:aylikUcret>0?(odendi/(aylikUcret.toDouble()*
                                                ((tah['kayitSayisi']??1) as int))).clamp(0.0,1.0):0,
                                            minHeight:6,
                                            backgroundColor:Colors.grey.withValues(alpha:0.1),
                                            valueColor:const AlwaysStoppedAnimation<Color>(Colors.green))),
                                  ])),
                                  const SizedBox(width:10),
                                  // Odeme ekle butonu
                                  GestureDetector(
                                    onTap:()=>_odemeEkleDialog(context,ogrId,d['ad']??'',widget.firmaId,widget.projeId),
                                    child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                                        decoration:BoxDecoration(color:_t.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8),
                                            border:Border.all(color:_t.withValues(alpha:0.3))),
                                        child:const Row(mainAxisSize:MainAxisSize.min,children:[
                                          Icon(Icons.add,size:14,color:Color(0xFFFF8C00)),
                                          SizedBox(width:4),
                                          Text('Odeme Ekle',style:TextStyle(fontSize:11,color:Color(0xFFFF8C00),fontWeight:FontWeight.bold)),
                                        ])),
                                  ),
                                ])),
                          ]));
                    });
              });
        })),
  ]);

  Future<Map<String,dynamic>> _ogrenciTahsilat(String ogrId) async{
    try{
      final snap=await FirebaseFirestore.instance.collection('tahsilat')
          .where('firmaId',isEqualTo:widget.firmaId)
          .where('ogrenciId',isEqualTo:ogrId).get();
      double odendi=0;
      for(final doc in snap.docs){
        final d=doc.data() as Map<String,dynamic>;
        if(d['durum']=='odendi')odendi+=(d['tutar'] as num?)?.toDouble()??0;
      }
      return{'odendi':odendi,'kayitSayisi':snap.docs.length};
    }catch(_){return{};}
  }

  static void _odemeEkleDialog(BuildContext context,String ogrId,String ogrAd,String firmaId,String projeId){
    final tutarCtrl=TextEditingController();
    final aciklamaCtrl=TextEditingController();
    String ay=['Ocak','Subat','Mart','Nisan','Mayis','Haziran',
      'Temmuz','Agustos','Eylul','Ekim','Kasim','Aralik'][DateTime.now().month-1];
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:Text(ogrAd+' – Odeme Ekle',style:const TextStyle(color:Color(0xFF1a3a6b),fontWeight:FontWeight.bold)),
        content:SizedBox(width:360,child:Column(mainAxisSize:MainAxisSize.min,children:[
          TextField(controller:tutarCtrl,keyboardType:TextInputType.number,
              decoration:InputDecoration(labelText:'Tutar (TL) *',
                  prefixIcon:const Icon(Icons.payments_outlined,color:Color(0xFF1a3a6b),size:18),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
                  contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
              value:ay,
              decoration:InputDecoration(labelText:'Ay',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true),
              items:['Ocak','Subat','Mart','Nisan','Mayis','Haziran',
                'Temmuz','Agustos','Eylul','Ekim','Kasim','Aralik']
                  .map((a)=>DropdownMenuItem(value:a,child:Text(a))).toList(),
              onChanged:(v)=>setS(()=>ay=v??ay)),
          const SizedBox(height:10),
          TextField(controller:aciklamaCtrl,
              decoration:InputDecoration(labelText:'Aciklama / Not',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true,
                  contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10))),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFFFF8C00),
                  foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                final tutar=double.tryParse(tutarCtrl.text)??0;
                if(tutar==0)return;
                await FirebaseFirestore.instance.collection('tahsilat').add({
                  'firmaId':firmaId,'projeId':projeId,'ogrenciId':ogrId,
                  'ogrenciAd':ogrAd,'tutar':tutar,'ay':ay,'durum':'odendi',
                  'aciklama':aciklamaCtrl.text.trim(),
                  'tarih':FieldValue.serverTimestamp(),
                });
                if(ctx.mounted)Navigator.pop(ctx);
              },
              icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ])));
  }
}

// ── TOPLU TAHSILAT ISLEMI ────────────────────────────────────────
class _TopluTahsilatIslem extends StatefulWidget{
  final String firmaId,projeId;
  const _TopluTahsilatIslem({required this.firmaId,required this.projeId});
  @override State<_TopluTahsilatIslem> createState()=>_TopluTahsilatIslemState();
}
class _TopluTahsilatIslemState extends State<_TopluTahsilatIslem>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  List<String> _seciliOgrenciler=[];
  String _ay=['Ocak','Subat','Mart','Nisan','Mayis','Haziran',
    'Temmuz','Agustos','Eylul','Ekim','Kasim','Aralik'][DateTime.now().month-1];
  bool _gonderiyor=false;
  List<Map<String,dynamic>> _ogrenciler=[];

  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async{
    var q=FirebaseFirestore.instance.collection('students')
        .where('firmaId',isEqualTo:widget.firmaId).where('aktif',isEqualTo:true);
    if(widget.projeId.isNotEmpty)q=q.where('projeId',isEqualTo:widget.projeId);
    final snap=await q.get();
    if(mounted)setState(()=>_ogrenciler=snap.docs.map((d)=>{'id':d.id,...d.data()}).toList());
  }

  Future<void> _topluOde(BuildContext context) async{
    if(_seciliOgrenciler.isEmpty)return;
    setState(()=>_gonderiyor=true);
    try{
      final batch=FirebaseFirestore.instance.batch();
      for(final ogrId in _seciliOgrenciler){
        final ogr=_ogrenciler.firstWhere((o)=>o['id']==ogrId,orElse:()=>{});
        final tutar=(ogr['fiyat']??ogr['ucret']??0) as num;
        final ref=FirebaseFirestore.instance.collection('tahsilat').doc();
        batch.set(ref,{
          'firmaId':widget.firmaId,'projeId':widget.projeId,
          'ogrenciId':ogrId,'ogrenciAd':ogr['ad']??'',
          'tutar':tutar.toDouble(),'ay':_ay,'durum':'odendi',
          'aciklama':'Toplu islem','tarih':FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if(context.mounted){
        setState(()=>_seciliOgrenciler=[]);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:Text(_seciliOgrenciler.length.toString()+' ogrenci icin odeme islendi.'),
            backgroundColor:Colors.green,behavior:SnackBarBehavior.floating));
      }
    }finally{if(mounted)setState(()=>_gonderiyor=false);}
  }

  @override Widget build(BuildContext context)=>Column(children:[
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
        child:Row(children:[
          const Text('Toplu Tahsilat',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          const Spacer(),
          // Ay secici
          DropdownButton<String>(
              value:_ay,underline:const SizedBox(),
              items:['Ocak','Subat','Mart','Nisan','Mayis','Haziran',
                'Temmuz','Agustos','Eylul','Ekim','Kasim','Aralik']
                  .map((a)=>DropdownMenuItem(value:a,child:Text(a))).toList(),
              onChanged:(v)=>setState(()=>_ay=v??_ay)),
          const SizedBox(width:12),
          if(_seciliOgrenciler.isNotEmpty)ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:Colors.green,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:_gonderiyor?null:()=>_topluOde(context),
              icon:_gonderiyor?const SizedBox(width:14,height:14,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):
              const Icon(Icons.check_circle_outline,size:16),
              label:Text(_seciliOgrenciler.length.toString()+' Ogrenci Ode')),
          const SizedBox(width:8),
          TextButton(onPressed:()=>setState((){
            if(_seciliOgrenciler.length==_ogrenciler.length) _seciliOgrenciler=[];
            else _seciliOgrenciler=_ogrenciler.map((o)=>o['id'] as String).toList();
          }),child:Text(_seciliOgrenciler.length==_ogrenciler.length?'Tum Secimi Kaldir':'Tumunu Sec')),
        ])),
    Expanded(child:_ogrenciler.isEmpty
        ? _bos('Ogrenci bulunamadi','',Icons.school_outlined)
        : ListView.builder(
        padding:const EdgeInsets.all(16),
        itemCount:_ogrenciler.length,
        itemBuilder:(_,i){
          final ogr=_ogrenciler[i];
          final ogrId=ogr['id'] as String;
          final sec=_seciliOgrenciler.contains(ogrId);
          final ucret=(ogr['fiyat']??ogr['ucret']??0) as num;
          return GestureDetector(
            onTap:(){
              setState((){
                if(sec)_seciliOgrenciler.remove(ogrId);
                else _seciliOgrenciler.add(ogrId);
              });
            },
            child:Container(margin:const EdgeInsets.only(bottom:8),
                padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(
                    color:sec?_navy.withValues(alpha:0.04):Colors.white,
                    borderRadius:BorderRadius.circular(12),
                    border:Border.all(color:sec?_navy:Colors.grey.withValues(alpha:0.15)),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                child:Row(children:[
                  Checkbox(value:sec,activeColor:_navy,
                      onChanged:(_){
                        setState((){
                          if(sec)_seciliOgrenciler.remove(ogrId);
                          else _seciliOgrenciler.add(ogrId);
                        });
                      }),
                  const SizedBox(width:8),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(ogr['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                    Text((ogr['servisAd']??'').toString(),
                        style:TextStyle(fontSize:11,color:Colors.grey[500])),
                  ])),
                  Text(ucret.toString()+' TL',
                      style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,
                          color:sec?_navy:Colors.grey)),
                ])),
          );
        })),
  ]);
}

// ── TAHSILAT ARSIVI ──────────────────────────────────────────────
class _TahsilatArsiv extends StatelessWidget{
  final String firmaId,projeId;
  const _TahsilatArsiv({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('tahsilat')
        .where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'arsiv');
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
    return Column(children:[
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),color:Colors.white,
          child:const Row(children:[
            Icon(Icons.archive_outlined,color:_navy,size:18),SizedBox(width:8),
            Text('Arsivlenmis Tahsilatlar',style:TextStyle(fontWeight:FontWeight.bold,color:_navy,fontSize:15)),
          ])),
      Expanded(child:StreamBuilder<QuerySnapshot>(
          stream:q.orderBy('tarih',descending:true).snapshots(),
          builder:(_,snap){
            final docs=snap.data?.docs??[];
            if(docs.isEmpty)return _bos('Arsivlenmis kayit yok','',Icons.archive_outlined);
            return ListView.builder(
                padding:const EdgeInsets.all(16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final ts=d['tarih'];
                  String tarihStr='';
                  if(ts is Timestamp){final dt=ts.toDate();
                  tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString();}
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:Colors.grey.withValues(alpha:0.15))),
                      child:Row(children:[
                        const Icon(Icons.archive_outlined,color:Colors.grey,size:20),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(d['ogrenciAd']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                          Text((d['ay']??'')+' – '+tarihStr,
                              style:TextStyle(fontSize:11,color:Colors.grey[500])),
                        ])),
                        Text((d['tutar']??0).toString()+' TL',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14,color:Colors.grey)),
                        const SizedBox(width:10),
                        GestureDetector(
                            onTap:()=>FirebaseFirestore.instance.collection('tahsilat')
                                .doc(docs[i].id).update({'durum':'odendi'}),
                            child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                                child:const Text('Geri Al',style:TextStyle(fontSize:10,color:Colors.green,fontWeight:FontWeight.bold)))),
                      ]));
                });
          })),
    ]);
  }
}


class _TahsilatSekme extends StatefulWidget{
  final String firmaId,projeId;
  const _TahsilatSekme({required this.firmaId,required this.projeId});
  @override State<_TahsilatSekme> createState()=>_TahsilatSekmeState();
}
class _TahsilatSekmeState extends State<_TahsilatSekme>
    with SingleTickerProviderStateMixin{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  late TabController _tab;
  String _aramaMetni='';
  final _aramaCtrl=TextEditingController();

  @override void initState(){super.initState();_tab=TabController(length:8,vsync:this);}
  @override void dispose(){_tab.dispose();_aramaCtrl.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Column(children:[
    // Tab Bar
    Container(color:Colors.white,child:TabBar(
        controller:_tab,labelColor:_navy,unselectedLabelColor:Colors.grey,
        indicatorColor:_t,isScrollable:true,tabAlignment:TabAlignment.start,
        tabs:const[
          Tab(icon:Icon(Icons.dashboard_outlined,size:16),text:'Genel Durum'),
          Tab(icon:Icon(Icons.school_outlined,size:16),text:'Ogrenci Kartlari'),
          Tab(icon:Icon(Icons.list_alt_outlined,size:16),text:'Tum Odemeler'),
          Tab(icon:Icon(Icons.warning_amber_outlined,size:16),text:'Gecikenler'),
          Tab(icon:Icon(Icons.receipt_outlined,size:16),text:'Makbuzlar'),
          Tab(icon:Icon(Icons.group_work_outlined,size:16),text:'Toplu Islem'),
          Tab(icon:Icon(Icons.bar_chart_outlined,size:16),text:'Rapor'),
          Tab(icon:Icon(Icons.archive_outlined,size:16),text:'Arsiv'),
        ])),
    // Arama + Yeni Odeme
    Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:Colors.white,
        child:Row(children:[
          Expanded(child:TextField(
              controller:_aramaCtrl,
              onChanged:(v)=>setState(()=>_aramaMetni=v.toLowerCase()),
              decoration:InputDecoration(
                  hintText:'Ogrenci ara...',
                  prefixIcon:const Icon(Icons.search,size:18,color:Colors.grey),
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                  isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)))),
          const SizedBox(width:10),
          ElevatedButton.icon(
            style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
            onPressed:()=>_odemeEkleDialog(context),
            icon:const Icon(Icons.add,size:16),label:const Text('Yeni Odeme'),
          ),
        ])),
    Expanded(child:TabBarView(controller:_tab,children:[
      _TahsilatGenelDurum(firmaId:widget.firmaId,projeId:widget.projeId),
      _OgrenciKartlari(firmaId:widget.firmaId,projeId:widget.projeId),
      _OdemeListesi(firmaId:widget.firmaId,projeId:widget.projeId,filtre:'tumu',arama:_aramaMetni),
      _OdemeListesi(firmaId:widget.firmaId,projeId:widget.projeId,filtre:'gecikti',arama:_aramaMetni),
      _MakbuzListesi(firmaId:widget.firmaId,projeId:widget.projeId),
      _TopluTahsilatIslem(firmaId:widget.firmaId,projeId:widget.projeId),
      _TahsilatRaporu(firmaId:widget.firmaId,projeId:widget.projeId),
      _TahsilatArsiv(firmaId:widget.firmaId,projeId:widget.projeId),
    ])),
  ]);

  void _odemeEkleDialog(BuildContext context){
    final ogrCtrl=TextEditingController();
    final tutarCtrl=TextEditingController();
    final aciklamaCtrl=TextEditingController();
    String ay=_ayStr(DateTime.now().month);
    String durum='bekliyor';
    showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(ctx,setS)=>AlertDialog(
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
        title:const Text('Yeni Odeme Kaydi',style:TextStyle(color:_navy,fontWeight:FontWeight.bold)),
        content:SizedBox(width:400,child:Column(mainAxisSize:MainAxisSize.min,children:[
          _tahField(ogrCtrl,'Ogrenci Adi *',Icons.school_outlined),const SizedBox(height:10),
          _tahField(tutarCtrl,'Tutar (TL) *',Icons.payments_outlined),const SizedBox(height:10),
          Row(children:[
            Expanded(child:DropdownButtonFormField<String>(
                value:ay,
                decoration:InputDecoration(labelText:'Ay',
                    prefixIcon:const Icon(Icons.calendar_month_outlined,size:18,color:_navy),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true),
                items:[for(int i=1;i<=12;i++) DropdownMenuItem(value:_ayStr(i),child:Text(_ayStr(i)))],
                onChanged:(v)=>setS(()=>ay=v??ay))),
            const SizedBox(width:10),
            Expanded(child:DropdownButtonFormField<String>(
                value:durum,
                decoration:InputDecoration(labelText:'Durum',
                    prefixIcon:const Icon(Icons.info_outline,size:18,color:_navy),
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),isDense:true),
                items:const[
                  DropdownMenuItem(value:'bekliyor',child:Text('Bekliyor')),
                  DropdownMenuItem(value:'odendi',child:Text('Odendi')),
                  DropdownMenuItem(value:'gecikti',child:Text('Gecikti')),
                ],
                onChanged:(v)=>setS(()=>durum=v??durum))),
          ]),
          const SizedBox(height:10),
          _tahField(aciklamaCtrl,'Aciklama',Icons.notes_outlined),
        ])),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Iptal')),
          ElevatedButton.icon(
              style:ElevatedButton.styleFrom(backgroundColor:_t,foregroundColor:Colors.white,
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
              onPressed:() async{
                if(ogrCtrl.text.trim().isEmpty||tutarCtrl.text.trim().isEmpty)return;
                await FirebaseFirestore.instance.collection('tahsilat').add({
                  'firmaId':widget.firmaId,'projeId':widget.projeId,
                  'ogrenciAd':ogrCtrl.text.trim(),
                  'tutar':double.tryParse(tutarCtrl.text.trim())??0,
                  'ay':ay,'durum':durum,
                  'aciklama':aciklamaCtrl.text.trim(),
                  'tarih':FieldValue.serverTimestamp(),
                });
                if(ctx.mounted)Navigator.pop(ctx);
              },
              icon:const Icon(Icons.save_outlined,size:16),label:const Text('Kaydet')),
        ])));
  }

  String _ayStr(int m)=>[
    'Ocak','Subat','Mart','Nisan','Mayis','Haziran',
    'Temmuz','Agustos','Eylul','Ekim','Kasim','Aralik'
  ][m-1];

  static TextField _tahField(TextEditingController c,String l,IconData i)=>TextField(controller:c,
      decoration:InputDecoration(labelText:l,prefixIcon:Icon(i,color:_navy,size:18),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
          isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10)));
}

// ─────────────────────────────────────────────────────────────────
class _OdemeListesi extends StatelessWidget{
  final String firmaId,projeId,filtre,arama;
  const _OdemeListesi({required this.firmaId,required this.projeId,
    required this.filtre,required this.arama});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('tahsilat')
        .where('firmaId',isEqualTo:firmaId);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
    if(filtre=='gecikti')q=q.where('durum',isEqualTo:'gecikti');
    return StreamBuilder<QuerySnapshot>(
        stream:q.orderBy('tarih',descending:true).snapshots(),
        builder:(_,snap){
          var docs=snap.data?.docs??[];
          if(arama.isNotEmpty){
            docs=docs.where((d){
              final data=d.data() as Map<String,dynamic>;
              return (data['ogrenciAd']??'').toString().toLowerCase().contains(arama);
            }).toList();
          }
          if(docs.isEmpty)return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.account_balance_wallet_outlined,size:56,color:Colors.grey[300]),
            const SizedBox(height:12),
            Text(filtre=='gecikti'?'Geciken odeme yok':'Odeme kaydi yok',
                style:const TextStyle(color:Colors.grey,fontSize:16)),
          ]));
          // Ozet
          final toplam=docs.fold<double>(0,(s,d)=>s+(((d.data() as Map<String,dynamic>)['tutar'] as num?)?.toDouble()??0));
          final odendi=docs.where((d)=>(d.data() as Map<String,dynamic>)['durum']=='odendi')
              .fold<double>(0,(s,d)=>s+(((d.data() as Map<String,dynamic>)['tutar'] as num?)?.toDouble()??0));
          return Column(children:[
            // Ozet banner
            Container(
              margin:const EdgeInsets.all(16),
              padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                  boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
              child:Row(children:[
                _ozetKarti('Toplam',toplam.toStringAsFixed(0)+' TL',_navy),
                _ozetKarti('Odendi',odendi.toStringAsFixed(0)+' TL',Colors.green),
                _ozetKarti('Bekleyen',(toplam-odendi).toStringAsFixed(0)+' TL',Colors.orange),
                _ozetKarti('Kayit Sayisi',docs.length.toString(),Colors.blue),
              ]),
            ),
            Expanded(child:ListView.builder(
                padding:const EdgeInsets.symmetric(horizontal:16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final durum=d['durum']??'bekliyor';
                  final durumRenk=durum=='odendi'?Colors.green:durum=='gecikti'?Colors.red:Colors.orange;
                  final ts=d['tarih'];
                  String tarihStr='';
                  if(ts is Timestamp){
                    final dt=ts.toDate();
                    tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString();
                  }
                  return Container(
                    margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:durumRenk.withValues(alpha:0.2)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:4)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:Icon(Icons.account_balance_wallet_outlined,color:durumRenk,size:18)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ogrenciAd']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Row(children:[
                          Text(d['ay']??'',style:TextStyle(fontSize:12,color:Colors.grey[500])),
                          if(tarihStr.isNotEmpty)...[
                            const Text(' • ',style:TextStyle(color:Colors.grey)),
                            Text(tarihStr,style:TextStyle(fontSize:11,color:Colors.grey[400])),
                          ],
                          if((d['aciklama']??'').isNotEmpty)...[
                            const Text(' • ',style:TextStyle(color:Colors.grey)),
                            Text(d['aciklama'],style:TextStyle(fontSize:11,color:Colors.grey[400]),
                                maxLines:1,overflow:TextOverflow.ellipsis),
                          ],
                        ]),
                      ])),
                      Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                        Text((d['tutar']??0).toString()+' TL',
                            style:TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:_navy)),
                        const SizedBox(height:4),
                        GestureDetector(
                          onTap:()=>_durumDegistir(context,docs[i].id,durum),
                          child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                              decoration:BoxDecoration(color:durumRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                              child:Text(durum,style:TextStyle(fontSize:10,color:durumRenk,fontWeight:FontWeight.bold))),
                        ),
                      ]),
                    ]),
                  );
                })),
          ]);
        });
  }

  void _durumDegistir(BuildContext context,String docId,String mevcutDurum){
    showDialog(context:context,builder:(_)=>AlertDialog(
        title:const Text('Durum Degistir'),
        content:Column(mainAxisSize:MainAxisSize.min,children:[
          for(final d in ['bekliyor','odendi','gecikti'])
            ListTile(dense:true,
                leading:Radio<String>(value:d,groupValue:mevcutDurum,activeColor:const Color(0xFFFF8C00),onChanged:(_){}),
                title:Text(d),
                onTap:() async{
                  await FirebaseFirestore.instance.collection('tahsilat').doc(docId)
                      .update({'durum':d,'guncelleme':FieldValue.serverTimestamp()});
                  if(context.mounted)Navigator.pop(context);
                }),
        ])));
  }

  Widget _ozetKarti(String b,String v,Color r)=>Expanded(child:Column(children:[
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:r)),
    const SizedBox(height:2),
    Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));
}

// ─────────────────────────────────────────────────────────────────
class _MakbuzListesi extends StatelessWidget{
  final String firmaId,projeId;
  const _MakbuzListesi({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('tahsilat')
        .where('firmaId',isEqualTo:firmaId).where('durum',isEqualTo:'odendi');
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
    return StreamBuilder<QuerySnapshot>(
        stream:q.orderBy('tarih',descending:true).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.receipt_outlined,size:56,color:Colors.grey[300]),
            const SizedBox(height:12),
            const Text('Odenen makbuz yok',style:TextStyle(color:Colors.grey,fontSize:16)),
          ]));
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+'.'+dt.year.toString();}
                return Container(
                    margin:const EdgeInsets.only(bottom:8),
                    padding:const EdgeInsets.all(14),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                        border:Border.all(color:Colors.green.withValues(alpha:0.2))),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(8),
                          decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
                          child:const Icon(Icons.receipt_outlined,color:Colors.green,size:18)),
                      const SizedBox(width:12),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ogrenciAd']??'',style:const TextStyle(fontWeight:FontWeight.bold)),
                        Text((d['ay']??'')+' – '+tarihStr,style:TextStyle(fontSize:12,color:Colors.grey[500])),
                      ])),
                      Text((d['tutar']??0).toString()+' TL',
                          style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:Colors.green)),
                    ]));
              });
        });
  }
}

// ─────────────────────────────────────────────────────────────────
class _TahsilatRaporu extends StatelessWidget{
  final String firmaId,projeId;
  const _TahsilatRaporu({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('tahsilat').where('firmaId',isEqualTo:firmaId);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
    return StreamBuilder<QuerySnapshot>(
        stream:q.snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          double toplam=0,odendi=0,gecikti=0,bekliyor=0;
          final Map<String,double> aylikOdeme={};
          for(final doc in docs){
            final d=doc.data() as Map<String,dynamic>;
            final tutar=(d['tutar'] as num?)?.toDouble()??0;
            toplam+=tutar;
            final durum=d['durum']??'bekliyor';
            if(durum=='odendi')odendi+=tutar;
            else if(durum=='gecikti')gecikti+=tutar;
            else bekliyor+=tutar;
            final ay=d['ay']??'';
            if(ay.isNotEmpty)aylikOdeme[ay]=(aylikOdeme[ay]??0)+tutar;
          }
          return SingleChildScrollView(
              padding:const EdgeInsets.all(24),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                // Genel ozet
                const Text('Genel Ozet',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:_navy)),
                const SizedBox(height:14),
                Row(children:[
                  _raporKarti('Toplam Beklenen',toplam.toStringAsFixed(0)+' TL',_navy,Icons.account_balance_wallet_outlined),
                  const SizedBox(width:12),
                  _raporKarti('Tahsil Edilen',odendi.toStringAsFixed(0)+' TL',Colors.green,Icons.check_circle_outlined),
                  const SizedBox(width:12),
                  _raporKarti('Geciken',gecikti.toStringAsFixed(0)+' TL',Colors.red,Icons.warning_amber_outlined),
                  const SizedBox(width:12),
                  _raporKarti('Bekleyen',bekliyor.toStringAsFixed(0)+' TL',Colors.orange,Icons.pending_outlined),
                ]),
                const SizedBox(height:24),
                // Tahsilat orani
                const Text('Tahsilat Orani',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
                const SizedBox(height:10),
                Container(padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                    child:Column(children:[
                      Row(children:[
                        Text(toplam>0?((odendi/toplam)*100).toStringAsFixed(1)+'%':'0%',
                            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:28,color:_navy)),
                        const SizedBox(width:10),
                        const Text('tahsil edildi',style:TextStyle(color:Colors.grey)),
                      ]),
                      const SizedBox(height:10),
                      ClipRRect(borderRadius:BorderRadius.circular(6),
                          child:LinearProgressIndicator(
                              value:toplam>0?(odendi/toplam).clamp(0.0,1.0):0,
                              minHeight:12,
                              backgroundColor:Colors.grey.withValues(alpha:0.15),
                              valueColor:const AlwaysStoppedAnimation<Color>(Colors.green))),
                    ])),
                const SizedBox(height:24),
                // Aylik dagilim
                if(aylikOdeme.isNotEmpty)...[
                  const Text('Aylik Dagilim',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
                  const SizedBox(height:10),
                  Container(padding:const EdgeInsets.all(16),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
                      child:Column(children:aylikOdeme.entries.map((e)=>
                          Padding(padding:const EdgeInsets.only(bottom:8),
                              child:Row(children:[
                                SizedBox(width:80,child:Text(e.key,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13))),
                                Expanded(child:ClipRRect(
                                    borderRadius:BorderRadius.circular(4),
                                    child:LinearProgressIndicator(
                                        value:toplam>0?(e.value/toplam).clamp(0.0,1.0):0,
                                        minHeight:8,
                                        backgroundColor:Colors.grey.withValues(alpha:0.1),
                                        valueColor:AlwaysStoppedAnimation<Color>(_t)))),
                                const SizedBox(width:10),
                                Text(e.value.toStringAsFixed(0)+' TL',
                                    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)),
                              ]))).toList())),
                ],
              ]));
        });
  }

  Widget _raporKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:20),
        const SizedBox(height:8),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:17,color:r)),
        const SizedBox(height:2),
        Text(b,style:const TextStyle(fontSize:11,color:Colors.grey)),
      ])));
}


// ─────────────────────────────────────────────────────────────────
//  CANLI TAKIP WEB MODULU – Bolum 11
// ─────────────────────────────────────────────────────────────────
class _CanliTakipEkrani extends StatefulWidget{
  const _CanliTakipEkrani();
  @override State<_CanliTakipEkrani> createState()=>_CanliTakipEkraniState();
}
class _CanliTakipEkraniState extends State<_CanliTakipEkrani>{
  static const _navy=Color(0xFF1a3a6b);
  static const _t=Color(0xFFFF8C00);
  int _tab=0;
  String _firmaId='';
  String _projeId='';

  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async{
    final fid=await SessionService.instance.firmaIdAl();
    final pid=SessionService.instance.aktifProjeId??'';
    if(mounted)setState((){_firmaId=fid??'';_projeId=pid;});
  }

  @override Widget build(BuildContext context){
    if(_firmaId.isEmpty)return const Center(child:CircularProgressIndicator());
    return Column(children:[
      // Tab bar
      Container(color:Colors.white,child:SingleChildScrollView(
          scrollDirection:Axis.horizontal,
          child:Row(children:[
            for(final t in [
              (0,Icons.gps_fixed_outlined,'Aktif Servisler'),
              (1,Icons.schedule_outlined,'Yaklasan'),
              (2,Icons.check_circle_outline,'Tamamlanan'),
              (3,Icons.history_outlined,'Durum Gecmisi'),
              (4,Icons.bar_chart_outlined,'Takip Raporu'),
            ])
              GestureDetector(onTap:()=>setState(()=>_tab=t.$1),
                  child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
                      decoration:BoxDecoration(border:Border(bottom:BorderSide(
                          color:_tab==t.$1?_t:Colors.transparent,width:2))),
                      child:Row(children:[
                        Icon(t.$2,size:15,color:_tab==t.$1?_navy:Colors.grey),
                        const SizedBox(width:6),
                        Text(t.$3,style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,
                            color:_tab==t.$1?_navy:Colors.grey)),
                      ]))),
          ]))),
      // Canli yenileme gostergesi
      Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),color:Colors.white,
          child:Row(children:[
            Container(width:8,height:8,decoration:const BoxDecoration(
                color:Colors.green,shape:BoxShape.circle)),
            const SizedBox(width:6),
            const Text('Canli – Her 30 saniyede guncelleniyor',
                style:TextStyle(fontSize:11,color:Colors.grey)),
            const Spacer(),
            GestureDetector(
                onTap:()=>Navigator.pushNamed(context,'/admin_takip'),
                child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                    decoration:BoxDecoration(color:_navy.withValues(alpha:0.08),borderRadius:BorderRadius.circular(8)),
                    child:const Row(children:[
                      Icon(Icons.map_outlined,size:14,color:_navy),SizedBox(width:4),
                      Text('Harita Gorunumu',style:TextStyle(fontSize:11,color:_navy,fontWeight:FontWeight.w600)),
                    ]))),
          ])),
      Expanded(child:[
        _AktifServisler(firmaId:_firmaId,projeId:_projeId),
        _YaklasanServisler(firmaId:_firmaId,projeId:_projeId),
        _TamamlananServisler(firmaId:_firmaId,projeId:_projeId),
        _DurumGecmisi(firmaId:_firmaId,projeId:_projeId),
        _TakipRaporu(firmaId:_firmaId,projeId:_projeId),
      ][_tab]),
    ]);
  }
}

// ── AKTIF SERVISLER ─────────────────────────────────────────────
class _AktifServisler extends StatelessWidget{
  final String firmaId,projeId;
  const _AktifServisler({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('drivers')
        .where('firmaId',isEqualTo:firmaId)
        .where('servisAktif',isEqualTo:true);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);

    return StreamBuilder<QuerySnapshot>(
        stream:q.snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return Center(child:Column(
              mainAxisAlignment:MainAxisAlignment.center,children:[
            Container(padding:const EdgeInsets.all(20),
                decoration:BoxDecoration(color:Colors.grey.withValues(alpha:0.08),shape:BoxShape.circle),
                child:const Icon(Icons.gps_not_fixed_outlined,size:56,color:Colors.grey)),
            const SizedBox(height:16),
            const Text('Aktif Servis Yok',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
            const SizedBox(height:8),
            const Text('Soforler servisi baslattiginda burada gorunur.',style:TextStyle(color:Colors.grey)),
          ]));

          return Column(children:[
            // Ozet banner
            Container(margin:const EdgeInsets.all(16),padding:const EdgeInsets.all(16),
                decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.08),borderRadius:BorderRadius.circular(14),
                    border:Border.all(color:Colors.green.withValues(alpha:0.2))),
                child:Row(children:[
                  const Icon(Icons.play_circle_outline,color:Colors.green,size:24),
                  const SizedBox(width:12),
                  Text(docs.length.toString()+' servis aktif olarak calisiyor',
                      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14,color:Colors.green)),
                  const Spacer(),
                  Text(TimeOfDay.now().format(context),
                      style:const TextStyle(color:Colors.green,fontWeight:FontWeight.w600)),
                ])),
            // Aktif soforler
            Expanded(child:ListView.builder(
                padding:const EdgeInsets.symmetric(horizontal:16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final hiz=(d['hiz'] as num?)?.toStringAsFixed(0)??'0';
                  final ogrSay=(d['ogrenciSayi'] as int?)??0;
                  final sonGorulme=d['sonKonumZamani'];
                  String sonGorStr='';
                  if(sonGorulme is Timestamp){
                    final fark=DateTime.now().difference(sonGorulme.toDate());
                    if(fark.inMinutes<1)sonGorStr='Az once';
                    else if(fark.inMinutes<60)sonGorStr=fark.inMinutes.toString()+' dk once';
                    else sonGorStr=fark.inHours.toString()+' saat once';
                  }
                  return Container(margin:const EdgeInsets.only(bottom:12),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
                          border:Border.all(color:Colors.green.withValues(alpha:0.2)),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:8)]),
                      child:Column(children:[
                        // Header
                        Container(padding:const EdgeInsets.all(14),
                            decoration:BoxDecoration(
                                color:Colors.green.withValues(alpha:0.05),
                                borderRadius:const BorderRadius.vertical(top:Radius.circular(16))),
                            child:Row(children:[
                              Container(width:8,height:8,decoration:const BoxDecoration(
                                  color:Colors.green,shape:BoxShape.circle)),
                              const SizedBox(width:8),
                              CircleAvatar(radius:18,backgroundColor:_navy.withValues(alpha:0.1),
                                  child:Text((d['ad']??'?')[0].toUpperCase(),
                                      style:const TextStyle(color:_navy,fontWeight:FontWeight.bold,fontSize:13))),
                              const SizedBox(width:10),
                              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                                Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                                Text((d['aracPlaka']??d['plaka']??'').toString(),
                                    style:TextStyle(fontSize:11,color:Colors.grey[500])),
                              ])),
                              Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                                Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                                    decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.1),
                                        borderRadius:BorderRadius.circular(8)),
                                    child:const Text('AKTIF',style:TextStyle(fontSize:10,
                                        fontWeight:FontWeight.bold,color:Colors.green))),
                                if(sonGorStr.isNotEmpty)Text(sonGorStr,
                                    style:TextStyle(fontSize:10,color:Colors.grey[400])),
                              ]),
                            ])),
                        // Istatistikler
                        Padding(padding:const EdgeInsets.all(14),child:Row(children:[
                          _statKarti(ogrSay.toString(),'Ogrenci',Icons.school_outlined,Colors.blue),
                          _statKarti(hiz+' km/s','Hiz',Icons.speed_outlined,Colors.teal),
                          _statKarti((d['servisBaslangic']!=null
                              ?(d['servisBaslangic'] as Timestamp).toDate().hour.toString().padLeft(2,'0')+':'
                              +(d['servisBaslangic'] as Timestamp).toDate().minute.toString().padLeft(2,'0')
                              :'-'),'Baslangic',Icons.schedule_outlined,Colors.orange),
                          _statKarti((d['lat']!=null&&d['lng']!=null)?'GPS Var':'GPS Yok',
                              'Konum',Icons.gps_fixed_outlined,
                              d['lat']!=null?Colors.green:Colors.red),
                        ])),
                      ]));
                })),
          ]);
        });
  }

  Widget _statKarti(String v,String b,IconData i,Color r)=>Expanded(child:Column(children:[
    Icon(i,color:r,size:16),const SizedBox(height:2),
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:r)),
    Text(b,style:const TextStyle(fontSize:9,color:Colors.grey)),
  ]));
}

// ── YAKLASAN SERVISLER ──────────────────────────────────────────
class _YaklasanServisler extends StatelessWidget{
  final String firmaId,projeId;
  const _YaklasanServisler({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    final now=TimeOfDay.now();
    final nowStr=(now.hour*60+now.minute).toString();

    // 60 dk icinde baslayacak servisler
    var q=FirebaseFirestore.instance.collection('services')
        .where('firmaId',isEqualTo:firmaId).where('aktif',isEqualTo:true);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);

    return StreamBuilder<QuerySnapshot>(
        stream:q.snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          // Saatine gore filtrele (60 dk icinde)
          final yaklasan=docs.where((doc){
            final d=doc.data() as Map<String,dynamic>;
            for(final saatField in ['sabahSaati','aksamSaati']){
              final saatStr=(d[saatField]??'') as String;
              if(saatStr.isEmpty)continue;
              final parts=saatStr.split(':');
              if(parts.length<2)continue;
              final servisMin=(int.tryParse(parts[0])??0)*60+(int.tryParse(parts[1])??0);
              final nowMin=now.hour*60+now.minute;
              if(servisMin>nowMin&&servisMin-nowMin<=60)return true;
            }
            return false;
          }).toList();

          if(yaklasan.isEmpty)return Center(child:Column(
              mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.schedule_outlined,size:56,color:Colors.grey[300]),
            const SizedBox(height:12),
            const Text('60 Dakika Icinde Yaklasan Servis Yok',
                style:TextStyle(fontSize:16,color:Colors.grey)),
          ]));

          return ListView.builder(padding:const EdgeInsets.all(16),
              itemCount:yaklasan.length,
              itemBuilder:(_,i){
                final d=yaklasan[i].data() as Map<String,dynamic>;
                // En yakin saat
                String yakSaat='';
                int minKalan=9999;
                for(final sf in ['sabahSaati','aksamSaati']){
                  final s=(d[sf]??'') as String;
                  if(s.isEmpty)continue;
                  final parts=s.split(':');
                  if(parts.length<2)continue;
                  final sm=(int.tryParse(parts[0])??0)*60+(int.tryParse(parts[1])??0);
                  final nowMin=now.hour*60+now.minute;
                  if(sm>nowMin&&sm-nowMin<minKalan){minKalan=sm-nowMin;yakSaat=s;}
                }
                return Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        border:Border.all(color:Colors.orange.withValues(alpha:0.25)),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                    child:Row(children:[
                      Container(padding:const EdgeInsets.all(10),
                          decoration:BoxDecoration(color:Colors.orange.withValues(alpha:0.1),borderRadius:BorderRadius.circular(10)),
                          child:const Icon(Icons.schedule_outlined,color:Colors.orange,size:22)),
                      const SizedBox(width:14),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['ad']??'',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
                        Text((d['soforAd']??'Sofor Atanmamis').toString(),
                            style:TextStyle(fontSize:12,color:Colors.grey[500])),
                        Text(d['aracPlaka']??'',style:TextStyle(fontSize:11,color:Colors.grey[400])),
                      ])),
                      Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
                        Text(yakSaat,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:Colors.orange)),
                        Text(minKalan.toString()+' dakika kaldi',
                            style:const TextStyle(fontSize:11,color:Colors.orange)),
                        Text((d['ogrenciSayisi']??0).toString()+' ogrenci',
                            style:TextStyle(fontSize:11,color:Colors.grey[500])),
                      ]),
                    ]));
              });
        });
  }
}

// ── TAMAMLANAN SERVISLER ─────────────────────────────────────────
class _TamamlananServisler extends StatelessWidget{
  final String firmaId,projeId;
  const _TamamlananServisler({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('servis_raporlari')
        .where('firmaId',isEqualTo:firmaId);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);

    return StreamBuilder<QuerySnapshot>(
        stream:q.orderBy('tarih',descending:true).limit(50).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Tamamlanan rapor yok','Servisler tamamlandiginda burada gorunur.',Icons.check_circle_outline);

          // Bugunku raporlar
          final bugun=DateTime.now();
          final bugunRapor=docs.where((d){
            final ts=d['tarih'];
            if(ts is!Timestamp)return false;
            final dt=ts.toDate();
            return dt.year==bugun.year&&dt.month==bugun.month&&dt.day==bugun.day;
          }).toList();

          return Column(children:[
            // Ozet
            Container(margin:const EdgeInsets.all(16),padding:const EdgeInsets.all(14),
                decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
                child:Row(children:[
                  _ozKarti('Bugun',bugunRapor.length.toString(),Colors.green),
                  _ozKarti('Toplam',docs.length.toString(),_navy),
                  _ozKarti('Toplam Ogr',docs.fold<int>(0,(s,d)=>s+(((d.data() as Map)['toplamOgrenci'] as num?)?.toInt()??0)).toString(),Colors.blue),
                ])),
            Expanded(child:ListView.builder(
                padding:const EdgeInsets.symmetric(horizontal:16),
                itemCount:docs.length,
                itemBuilder:(_,i){
                  final d=docs[i].data() as Map<String,dynamic>;
                  final ts=d['tarih'];
                  String tarihStr='';
                  if(ts is Timestamp){final dt=ts.toDate();
                  tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                      dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                  return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
                          border:Border.all(color:Colors.green.withValues(alpha:0.15))),
                      child:Row(children:[
                        const Icon(Icons.check_circle_outline,color:Colors.green,size:20),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(tarihStr,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13)),
                          Wrap(spacing:8,children:[
                            _chip((d['toplamOgrenci']??0).toString()+' ogr',Colors.blue),
                            _chip((d['bindiler']??0).toString()+' bindi',Colors.green),
                            _chip((d['gelmediler']??0).toString()+' gelmedi',Colors.red),
                          ]),
                        ])),
                        if(d['tamamlandi']==true)
                          const Icon(Icons.verified_outlined,color:Colors.green,size:18),
                      ]));
                })),
          ]);
        });
  }

  Widget _ozKarti(String b,String v,Color r)=>Expanded(child:Column(children:[
    Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:20,color:r)),
    Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
  ]));

  Widget _chip(String t,Color c)=>Container(
      padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
      decoration:BoxDecoration(color:c.withValues(alpha:0.1),borderRadius:BorderRadius.circular(5)),
      child:Text(t,style:TextStyle(fontSize:10,color:c,fontWeight:FontWeight.bold)));
}

// ── DURUM GECMISI ────────────────────────────────────────────────
class _DurumGecmisi extends StatelessWidget{
  final String firmaId,projeId;
  const _DurumGecmisi({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context){
    var q=FirebaseFirestore.instance.collection('bildirimler')
        .where('firmaId',isEqualTo:firmaId);
    if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);

    return StreamBuilder<QuerySnapshot>(
        stream:q.orderBy('tarih',descending:true).limit(100).snapshots(),
        builder:(_,snap){
          final docs=snap.data?.docs??[];
          if(docs.isEmpty)return _bos('Durum gecmisi yok','',Icons.history_outlined);
          return ListView.builder(
              padding:const EdgeInsets.all(16),
              itemCount:docs.length,
              itemBuilder:(_,i){
                final d=docs[i].data() as Map<String,dynamic>;
                final tip=(d['tip']??'').toString();
                final tipRenk={
                  'servis_basladi':Colors.green,'yaklasisyor':Colors.orange,
                  'servis_geldi':Colors.blue,'okul_ulasti':Colors.purple,
                  'servis_bitti':Colors.grey,'acil':Colors.red,
                }[tip]??Colors.grey;
                final ts=d['tarih'];
                String tarihStr='';
                if(ts is Timestamp){final dt=ts.toDate();
                tarihStr=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0')+' '+
                    dt.hour.toString().padLeft(2,'0')+':'+dt.minute.toString().padLeft(2,'0');}
                return Container(margin:const EdgeInsets.only(bottom:6),
                    padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),
                        border:Border(left:BorderSide(color:tipRenk,width:3))),
                    child:Row(children:[
                      Container(width:28,height:28,decoration:BoxDecoration(
                          color:tipRenk.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
                          child:Icon(_tipIkon(tip),color:tipRenk,size:14)),
                      const SizedBox(width:10),
                      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                        Text(d['baslik']??d['mesaj']??tip,
                            style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),
                        if((d['mesaj']??'').isNotEmpty&&d['mesaj']!=d['baslik'])
                          Text(d['mesaj'],style:TextStyle(fontSize:11,color:Colors.grey[500]),
                              maxLines:1,overflow:TextOverflow.ellipsis),
                      ])),
                      Text(tarihStr,style:TextStyle(fontSize:10,color:Colors.grey[400])),
                    ]));
              });
        });
  }

  IconData _tipIkon(String tip){
    switch(tip){
      case 'servis_basladi':return Icons.play_circle_outline;
      case 'yaklasisyor':return Icons.directions_bus_outlined;
      case 'servis_geldi':return Icons.location_on_outlined;
      case 'okul_ulasti':return Icons.school_outlined;
      case 'servis_bitti':return Icons.check_circle_outline;
      case 'acil':return Icons.emergency_outlined;
      default:return Icons.notifications_outlined;
    }
  }
}

// ── TAKIP RAPORU ─────────────────────────────────────────────────
class _TakipRaporu extends StatelessWidget{
  final String firmaId,projeId;
  const _TakipRaporu({required this.firmaId,required this.projeId});
  static const _navy=Color(0xFF1a3a6b);

  @override Widget build(BuildContext context)=>FutureBuilder(
      future:_veriCek(),
      builder:(_,snap){
        if(!snap.hasData)return const Center(child:CircularProgressIndicator());
        final data=snap.data as Map<String,dynamic>;
        return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Canli Takip Raporu',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:20),
          Row(children:[
            _rKarti('Bugunku Servisler',(data['bugunServis']??0).toString(),Colors.green,Icons.today_outlined),
            const SizedBox(width:12),
            _rKarti('Toplam Servis',(data['toplamServis']??0).toString(),_navy,Icons.bar_chart_outlined),
            const SizedBox(width:12),
            _rKarti('Toplam Ogrenci',(data['toplamOgrenci']??0).toString(),Colors.blue,Icons.school_outlined),
            const SizedBox(width:12),
            _rKarti('Gelmeyen',(data['gelmeyen']??0).toString(),Colors.red,Icons.person_off_outlined),
          ]),
          const SizedBox(height:24),
          // Son 7 gun
          const Text('Son 7 Gun Ozeti',style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,color:_navy)),
          const SizedBox(height:10),
          Container(padding:const EdgeInsets.all(16),
              decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14)),
              child:(data['gunlukOzet'] as List<Map<String,dynamic>>).isEmpty
                  ? const Text('Veri yok',style:TextStyle(color:Colors.grey))
                  : Column(children:(data['gunlukOzet'] as List<Map<String,dynamic>>).map((g)=>
                  Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[
                    SizedBox(width:80,child:Text(g['tarih'],style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
                    const SizedBox(width:10),
                    Expanded(child:ClipRRect(borderRadius:BorderRadius.circular(4),
                        child:LinearProgressIndicator(
                            value:(g['oran'] as double).clamp(0.0,1.0),minHeight:8,
                            backgroundColor:Colors.grey.withValues(alpha:0.1),
                            valueColor:const AlwaysStoppedAnimation<Color>(Colors.green)))),
                    const SizedBox(width:10),
                    Text((g['servis']??0).toString()+' servis',
                        style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
                  ]))).toList())),
        ]));
      });

  Future<Map<String,dynamic>> _veriCek() async{
    try{
      final bugun=DateTime.now();
      var q=FirebaseFirestore.instance.collection('servis_raporlari')
          .where('firmaId',isEqualTo:firmaId);
      if(projeId.isNotEmpty)q=q.where('projeId',isEqualTo:projeId);
      final snap=await q.orderBy('tarih',descending:true).limit(100).get();
      final docs=snap.docs;

      int bugunServis=0,toplamOgr=0,gelmeyen=0;
      final Map<String,int> gunMap={};
      final Map<String,int> gunToplamOgr={};

      for(final doc in docs){
        final d=doc.data() as Map<String,dynamic>;
        toplamOgr+=(((d['toplamOgrenci'] as num?)?.toInt()??0));
        gelmeyen+=(((d['gelmediler'] as num?)?.toInt()??0));
        final ts=d['tarih'];
        if(ts is Timestamp){
          final dt=ts.toDate();
          final tarihKey=dt.day.toString().padLeft(2,'0')+'.'+dt.month.toString().padLeft(2,'0');
          gunMap[tarihKey]=(gunMap[tarihKey]??0)+1;
          gunToplamOgr[tarihKey]=(gunToplamOgr[tarihKey]??0)+(((d['toplamOgrenci'] as num?)?.toInt()??0));
          if(dt.year==bugun.year&&dt.month==bugun.month&&dt.day==bugun.day)bugunServis++;
        }
      }

      final maxServis=gunMap.values.isEmpty?1:gunMap.values.reduce((a,b)=>a>b?a:b);
      final gunlukOzet=gunMap.entries.take(7).map((e)=>({
        'tarih':e.key,'servis':e.value,
        'oran':maxServis>0?e.value/maxServis:0.0,
      } as Map<String,dynamic>)).toList();

      return{
        'bugunServis':bugunServis,'toplamServis':docs.length,
        'toplamOgrenci':toplamOgr,'gelmeyen':gelmeyen,'gunlukOzet':gunlukOzet,
      };
    }catch(_){return{'gunlukOzet':[]};}
  }

  Widget _rKarti(String b,String v,Color r,IconData i)=>Expanded(child:Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:r.withValues(alpha:0.2)),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:6)]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(i,color:r,size:18),const SizedBox(height:6),
        Text(v,style:TextStyle(fontWeight:FontWeight.bold,fontSize:18,color:r)),
        Text(b,style:const TextStyle(fontSize:10,color:Colors.grey)),
      ])));
}



class _WebRotalarWrapper extends StatelessWidget {
  const _WebRotalarWrapper();
  @override
  Widget build(BuildContext context) {
    return const RotalarScreen();
  }
}

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
