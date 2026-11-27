class AccountConfig {
  static const Map<String, String> accounts = {
    'cash': 'Cash',
    'cimb': 'CIMB NIAGA',
    'neo': 'Neo Bank',
    'sea': 'Sea Bank',
    'bri': 'BRI',
    'mdr': 'Mandiri',
  };

  /// "cimb" -> "CIMB Niaga". Unknown keys are shown as they are.
  static String nameOf(String key) => accounts[key] ?? key;
}
