import 'location_point.dart';

/// Welche Punkte in die Heatmap einfließen.
class HeatFilter {
  const HeatFilter({this.from, this.to, this.kinds = const {...PointKind.values}});

  /// Inklusive Grenzen (lokale Kalendertage); null = offen.
  final DateTime? from;
  final DateTime? to;
  final Set<PointKind> kinds;

  bool get hasDateRange => from != null || to != null;

  HeatFilter copyWith({DateTime? from, DateTime? to, bool clearDates = false, Set<PointKind>? kinds}) =>
      HeatFilter(
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        kinds: kinds ?? this.kinds,
      );

  /// Prüft, ob Punkt [i] aus [s] den Filter erfüllt. Punkte ohne Zeit fallen
  /// bei aktivem Zeitraum heraus.
  bool Function(PointSet s, int i) compile() {
    final kindMask = kinds.fold(0, (m, k) => m | (1 << k.index));
    final fromSec = from == null ? null : from!.millisecondsSinceEpoch ~/ 1000;
    final toSec = to == null
        ? null
        : DateTime(to!.year, to!.month, to!.day + 1).millisecondsSinceEpoch ~/ 1000;
    return (s, i) {
      if (kindMask & (1 << s.kind[i]) == 0) return false;
      if (fromSec == null && toSec == null) return true;
      final t = s.time[i];
      if (t == 0) return false;
      if (fromSec != null && t < fromSec) return false;
      if (toSec != null && t >= toSec) return false;
      return true;
    };
  }
}

/// Darstellungs-Einstellungen, werden als JSON gespeichert.
class HeatSettings {
  const HeatSettings({this.radius = 18, this.intensity = 1.0, this.weightByDuration = true});

  /// Radius eines Punkts in Pixeln.
  final double radius;

  /// > 1 = Heatmap wird schneller „heiß“.
  final double intensity;

  /// Besuche nach Aufenthaltsdauer gewichten.
  final bool weightByDuration;

  HeatSettings copyWith({double? radius, double? intensity, bool? weightByDuration}) => HeatSettings(
        radius: radius ?? this.radius,
        intensity: intensity ?? this.intensity,
        weightByDuration: weightByDuration ?? this.weightByDuration,
      );

  Map<String, dynamic> toJson() =>
      {'radius': radius, 'intensity': intensity, 'weightByDuration': weightByDuration};

  factory HeatSettings.fromJson(Map<String, dynamic> j) => HeatSettings(
        radius: (j['radius'] as num?)?.toDouble() ?? 18,
        intensity: (j['intensity'] as num?)?.toDouble() ?? 1.0,
        weightByDuration: j['weightByDuration'] as bool? ?? true,
      );
}
