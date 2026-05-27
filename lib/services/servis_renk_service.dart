import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Araçlara renk atar — harita marker ve liste için
class ServisRenkService {
  static const _renkler = [
    Color(0xFF1a3a6b), // navy
    Color(0xFF0e7490), // teal
    Color(0xFF065F46), // green
    Color(0xFF7C3AED), // purple
    Color(0xFFB45309), // amber
    Color(0xFF991B1B), // red
    Color(0xFF1D4ED8), // blue
    Color(0xFF047857), // emerald
    Color(0xFF6D28D9), // violet
    Color(0xFF9D174D), // pink
  ];

  static const _hueler = [
    BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueGreen,
    BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueOrange,
    BitmapDescriptor.hueRed,
    BitmapDescriptor.hueAzure,
    BitmapDescriptor.hueMagenta,
    BitmapDescriptor.hueYellow,
    BitmapDescriptor.hueRose,
  ];

  /// Araç index'ine göre renk döner
  static Color renkAl(int index) => _renkler[index % _renkler.length];

  /// Araç index'ine göre harita marker hue döner
  static double hueAl(int index) => _hueler[index % _hueler.length];

  /// Rengi hex string'e çevirir
  static String hexAl(int index) {
    final renk = renkAl(index);
    return '#${renk.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
