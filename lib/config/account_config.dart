import 'package:flutter/material.dart';

class AccountConfig {
  static const Map<String, String> accounts = {
    'cash': 'Cash',
    'cimb': 'CIMB NIAGA',
    'neo': 'Neo Bank',
    'sea': 'Sea Bank',
    'bri': 'BRI',
    'mdr': 'Mandiri',
  };

  /// short names for the chart labels.
  static const Map<String, String> shortNames = {
    'cash': 'Cash',
    'cimb': 'CIMB',
    'neo': 'Neo',
    'sea': 'Sea',
    'bri': 'BRI',
    'mdr': 'Mandiri',
  };

  /// the same collors as the chart on your website.
  static const Map<String, Color> colors = {
    'cash': Color(0xFFDA70D6), // orchid
    'cimb': Color(0xFFDC2626),
    'neo': Color(0xFFFFD700), // gold
    'sea': Color(0xFFEDE738),
    'bri': Color(0xFF2258EB),
    'mdr': Color.fromARGB(255, 25, 4, 211),
  };

  /// "cimb" -> "CIMB Niaga". Unknown keys are shown as they are.
  static String nameOf(String key) => accounts[key] ?? key;

  static String shortNameOf(String key) => shortNames[key] ?? key;

  static Color colorOf(String key) => colors[key] ?? Colors.grey;
}
