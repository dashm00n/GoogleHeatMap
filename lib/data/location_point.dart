import 'dart:typed_data';

/// Art eines Standortpunkts.
enum PointKind {
  /// Aufenthalt an einem Ort (Besuch).
  visit,

  /// Punkt auf einer Wegstrecke zwischen zwei Orten.
  path,

  /// Rohes GPS-Signal.
  raw,
}

/// Spaltenorientierte, kompakte Ablage vieler Standortpunkte.
///
/// Zeitachsen-Exporte enthalten oft Hunderttausende Punkte; einzelne Objekte
/// pro Punkt wären zu speicherhungrig.
class PointSet {
  PointSet({
    required this.lat,
    required this.lng,
    required this.time,
    required this.durationMin,
    required this.kind,
  });

  PointSet.empty()
      : lat = Float32List(0),
        lng = Float32List(0),
        time = Uint32List(0),
        durationMin = Uint16List(0),
        kind = Uint8List(0);

  final Float32List lat;
  final Float32List lng;

  /// Sekunden seit 1970 (UTC), 0 = unbekannt.
  final Uint32List time;

  /// Aufenthaltsdauer in Minuten (nur bei Besuchen, sonst 0).
  final Uint16List durationMin;

  /// Index in [PointKind.values].
  final Uint8List kind;

  int get length => lat.length;
  bool get isEmpty => length == 0;

  PointKind kindAt(int i) => PointKind.values[kind[i]];

  /// Alle Jahre, in denen Punkte mit bekannter Zeit liegen, aufsteigend.
  List<int> years() {
    final years = <int>{};
    for (var i = 0; i < length; i++) {
      if (time[i] != 0) {
        years.add(DateTime.fromMillisecondsSinceEpoch(time[i] * 1000, isUtc: true).year);
      }
    }
    return years.toList()..sort();
  }

  /// Fügt [other] hinzu und entfernt doppelte Punkte (gleicher Ort ~1 m, gleiche Zeit, gleiche Art).
  PointSet merge(PointSet other) {
    final b = PointSetBuilder();
    final seen = <(int, int, int, int)>{};
    void addAll(PointSet s) {
      for (var i = 0; i < s.length; i++) {
        final key = ((s.lat[i] * 1e5).round(), (s.lng[i] * 1e5).round(), s.time[i], s.kind[i]);
        if (seen.add(key)) {
          b.add(s.lat[i], s.lng[i], s.time[i], s.kindAt(i), s.durationMin[i]);
        }
      }
    }

    addAll(this);
    addAll(other);
    return b.build();
  }
}

/// Sammelt Punkte beim Parsen und erzeugt daraus ein [PointSet].
class PointSetBuilder {
  final _lat = <double>[];
  final _lng = <double>[];
  final _time = <int>[];
  final _duration = <int>[];
  final _kind = <int>[];

  int get length => _lat.length;
  bool get isEmpty => _lat.isEmpty;

  void add(double lat, double lng, int timeSec, PointKind kind, [int durationMin = 0]) {
    if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) return;
    if (lat == 0 && lng == 0) return;
    _lat.add(lat);
    _lng.add(lng);
    _time.add(timeSec.clamp(0, 0xFFFFFFFF));
    _duration.add(durationMin.clamp(0, 0xFFFF));
    _kind.add(kind.index);
  }

  PointSet build() => PointSet(
        lat: Float32List.fromList(_lat),
        lng: Float32List.fromList(_lng),
        time: Uint32List.fromList(_time),
        durationMin: Uint16List.fromList(_duration),
        kind: Uint8List.fromList(_kind),
      );
}
