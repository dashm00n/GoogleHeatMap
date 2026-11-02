/// Kleine, tolerante Helfer zum Lesen der verschiedenen Google-Exportformate.
library;

final _number = RegExp(r'-?\d+(?:\.\d+)?');

Map<String, dynamic>? asMap(Object? o) => o is Map<String, dynamic> ? o : null;

List<dynamic> asList(Object? o) => o is List ? o : const [];

/// Liest Koordinaten aus Texten wie `"48.137°, 11.575°"` (Android) oder
/// `"geo:48.137,11.575"` (iOS).
(double, double)? parseLatLngString(String? s) {
  if (s == null) return null;
  final matches = _number.allMatches(s).take(2).toList();
  if (matches.length < 2) return null;
  final lat = double.parse(matches[0].group(0)!);
  final lng = double.parse(matches[1].group(0)!);
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat, lng);
}

/// Koordinate aus einem String oder aus einem Objekt mit `latLng`/`LatLng`/`point`.
(double, double)? latLngOf(Object? o) {
  if (o is String) return parseLatLngString(o);
  final m = asMap(o);
  if (m == null) return null;
  final s = m['latLng'] ?? m['LatLng'] ?? m['point'];
  return s is String ? parseLatLngString(s) : null;
}

/// Koordinate im alten Takeout-Format (Grad × 10^7 als Ganzzahl).
double? fromE7(Object? v) {
  final n = switch (v) {
    num n => n.toInt(),
    String s => int.tryParse(s),
    _ => null,
  };
  if (n == null) return null;
  // Bekannter Takeout-Fehler: Werte jenseits von int32 sind übergelaufen.
  final fixed = n > 1800000000 ? n - 4294967296 : n;
  return fixed / 1e7;
}

/// Sekunden seit 1970 aus ISO-8601-Zeit oder Millisekunden-String, 0 = unbekannt.
int parseTimeSec(Object? v) {
  if (v is String) {
    final dt = DateTime.tryParse(v);
    if (dt != null) return dt.millisecondsSinceEpoch ~/ 1000;
    final ms = int.tryParse(v);
    if (ms != null) return ms ~/ 1000;
  }
  if (v is num) return v.toInt() ~/ 1000;
  return 0;
}

double parseNum(Object? v) => switch (v) {
      num n => n.toDouble(),
      String s => double.tryParse(s) ?? 0,
      _ => 0,
    };
