// Erzeugt erfundene Probedaten in allen unterstützten Exportformaten.
//
//   dart run tool/generate_sample_data.dart
//
// Szenario: eine fiktive Person wohnt in München-Schwabing, radelt werktags ins
// Werksviertel, geht zum Sport und einkaufen, macht Wochenendausflüge in die
// Berge, besucht die Eltern in Augsburg und verreist an den Gardasee, nach
// Berlin und nach Hamburg. Alle Daten sind zufällig (fester Seed) erzeugt.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

class Place {
  const Place(this.name, this.lat, this.lng, [this.type = 'UNKNOWN']);
  final String name;
  final double lat, lng;
  final String type;
  String get id => 'ChIJ_${name.replaceAll(' ', '_')}';
}

const home = Place('Zuhause', 48.1620, 11.5860, 'HOME');
const work = Place('Büro', 48.1240, 11.6020, 'WORK');
const gym = Place('Fitnessstudio', 48.1550, 11.5700);
const supermarket = Place('Supermarkt', 48.1600, 11.5900);
const friends = Place('Freunde Haidhausen', 48.1300, 11.5950);
const park = Place('Englischer Garten', 48.1640, 11.6050);
const cafe = Place('Café Gärtnerplatz', 48.1310, 11.5760);
const parents = Place('Eltern Augsburg', 48.3705, 10.8978);
const tegernsee = Place('Tegernsee', 47.7120, 11.7580);
const garmisch = Place('Garmisch', 47.4920, 11.0950);
const gardaHotel = Place('Hotel Riva', 45.8850, 10.8410);
const malcesine = Place('Malcesine', 45.7640, 10.8090);
const limone = Place('Limone', 45.8130, 10.7920);
const berlinHotel = Place('Hotel Berlin', 52.5200, 13.4050);
const brandenburg = Place('Brandenburger Tor', 52.5163, 13.3777);
const eastSide = Place('East Side Gallery', 52.5050, 13.4397);
const hamburgHotel = Place('Hotel Hamburg', 53.5511, 9.9937);
const elphi = Place('Elbphilharmonie', 53.5413, 9.9841);

sealed class Event {}

class Visit extends Event {
  Visit(this.place, this.start, this.end);
  final Place place;
  final DateTime start, end;
}

class Move extends Event {
  Move(this.from, this.to, this.start, this.end, this.mode, this.path);
  final Place from, to;
  final DateTime start, end;
  final String mode;
  final List<(double, double, DateTime)> path;
}

final rnd = math.Random(42);

/// Simuliert den Tagesablauf ab [from] bis [until] (exklusive).
class Simulator {
  Simulator(DateTime start) : _t = start;

  final events = <Event>[];
  Place _at = home;
  DateTime _t;
  DateTime? _visitStart;

  void stayUntil(DateTime t) {
    _visitStart ??= _t;
    if (t.isAfter(_t)) _t = t;
  }

  void stayFor(int minutes) => stayUntil(_t.add(Duration(minutes: minutes)));

  void goTo(Place p, {String? mode}) {
    if (p == _at) return;
    _flushVisit();
    final km = _distanceKm(_at, p);
    final m = mode ?? (km < 2 ? 'WALKING' : km < 12 ? 'CYCLING' : km < 120 ? 'IN_PASSENGER_VEHICLE' : 'IN_TRAIN');
    final speed = switch (m) { 'WALKING' => 5.0, 'CYCLING' => 16.0, 'IN_TRAIN' => 110.0, _ => 60.0 };
    final minutes = math.max(5, (km / speed * 60 * (1 + rnd.nextDouble() * 0.3)).round());
    final end = _t.add(Duration(minutes: minutes));

    // Wegpunkte etwa alle 2 Minuten (bei langen Fahrten seltener), leicht gekrümmt.
    final n = math.min(120, math.max(3, minutes ~/ 2));
    final bend = (rnd.nextDouble() - 0.5) * 0.15;
    final path = <(double, double, DateTime)>[];
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final curve = math.sin(f * math.pi) * bend;
      final lat = _at.lat + (p.lat - _at.lat) * f + (p.lng - _at.lng) * curve + _noise();
      final lng = _at.lng + (p.lng - _at.lng) * f - (p.lat - _at.lat) * curve + _noise();
      path.add((lat, lng, _t.add(Duration(seconds: (minutes * 60 * f).round()))));
    }
    events.add(Move(_at, p, _t, end, m, path));
    _at = p;
    _t = end;
  }

  void _flushVisit() {
    final s = _visitStart;
    if (s != null && _t.difference(s).inMinutes >= 5) events.add(Visit(_at, s, _t));
    _visitStart = null;
  }

  void finish() => _flushVisit();

  DateTime at(int hour, [int minute = 0, int jitterMin = 0]) {
    final d = DateTime.utc(_t.year, _t.month, _t.day, hour, minute);
    return d.add(Duration(minutes: jitterMin == 0 ? 0 : rnd.nextInt(2 * jitterMin) - jitterMin));
  }
}

double _noise() => (rnd.nextDouble() - 0.5) * 0.0006;

double _distanceKm(Place a, Place b) {
  const r = 6371.0;
  final dLat = (b.lat - a.lat) * math.pi / 180, dLng = (b.lng - a.lng) * math.pi / 180;
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.lat * math.pi / 180) * math.cos(b.lat * math.pi / 180) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

bool _within(DateTime d, String from, String to) =>
    !d.isBefore(DateTime.parse('${from}T00:00:00Z')) && !d.isAfter(DateTime.parse('${to}T23:59:59Z'));

/// Simuliert alle Tage von [from] bis [to] (inklusive).
List<Event> simulate(String from, String to) {
  var day = DateTime.parse('${from}T00:00:00Z');
  final last = DateTime.parse('${to}T00:00:00Z');
  final sim = Simulator(day);
  while (!day.isAfter(last)) {
    _planDay(sim, day);
    day = day.add(const Duration(days: 1));
    sim.stayUntil(day);
  }
  sim.finish();
  return sim.events;
}

void _trip(Simulator s, DateTime day, String from, String to, Place hotel, List<Place> sights) {
  final first = day == DateTime.parse('${from}T00:00:00Z');
  final lastDay = day == DateTime.parse('${to}T00:00:00Z');
  if (first) {
    s.stayUntil(s.at(8, 0, 30));
    s.goTo(hotel);
  }
  s.stayUntil(s.at(first ? 15 : 9, 30, 30));
  for (final p in (sights.toList()..shuffle(rnd)).take(first ? 1 : 2)) {
    s.goTo(p, mode: 'WALKING');
    s.stayFor(60 + rnd.nextInt(150));
  }
  s.goTo(hotel, mode: 'WALKING');
  if (lastDay) {
    s.stayUntil(s.at(14, 0, 30));
    s.goTo(home);
  }
}

void _planDay(Simulator s, DateTime day) {
  const trips = [
    ('2022-08-13', '2022-08-20', gardaHotel, [malcesine, limone]),
    ('2023-08-12', '2023-08-26', gardaHotel, [malcesine, limone]),
    ('2024-11-15', '2024-11-17', berlinHotel, [brandenburg, eastSide]),
    ('2025-08-09', '2025-08-23', gardaHotel, [malcesine, limone]),
    ('2026-03-13', '2026-03-15', berlinHotel, [brandenburg, eastSide]),
    ('2026-06-05', '2026-06-07', hamburgHotel, [elphi]),
  ];
  for (final (from, to, hotel, sights) in trips) {
    if (_within(day, from, to)) return _trip(s, day, from, to, hotel, sights);
  }

  final weekday = day.weekday <= 5;
  if (weekday && rnd.nextDouble() > 0.06) {
    s.stayUntil(s.at(7, 30, 25));
    s.goTo(work);
    s.stayUntil(s.at(16, 45, 60));
    if (rnd.nextDouble() < 0.4) {
      s.goTo(gym);
      s.stayFor(60 + rnd.nextInt(40));
    }
    if (rnd.nextDouble() < 0.35) {
      s.goTo(supermarket);
      s.stayFor(15 + rnd.nextInt(20));
    }
    if (rnd.nextDouble() < 0.15) {
      s.goTo(friends);
      s.stayFor(120 + rnd.nextInt(120));
    }
    s.goTo(home);
    return;
  }

  // Wochenende oder freier Tag.
  s.stayUntil(s.at(9, 30, 60));
  final r = rnd.nextDouble();
  if (r < 0.2) {
    final dest = rnd.nextBool() ? tegernsee : garmisch;
    s.goTo(dest);
    s.stayFor(240 + rnd.nextInt(180));
  } else if (r < 0.32 && day.day <= 14) {
    s.goTo(parents);
    s.stayFor(300 + rnd.nextInt(180));
  } else if (r < 0.65) {
    s.goTo(park, mode: 'WALKING');
    s.stayFor(90 + rnd.nextInt(120));
    if (rnd.nextBool()) {
      s.goTo(cafe);
      s.stayFor(60);
    }
  } else {
    s.goTo(supermarket, mode: 'WALKING');
    s.stayFor(25);
  }
  s.goTo(home);
}

// ---------------------------------------------------------------------------
// Ausgabeformate

String _iso(DateTime t) => t.toUtc().toIso8601String();
String _deg(double lat, double lng) => '${lat.toStringAsFixed(7)}°, ${lng.toStringAsFixed(7)}°';
String _geo(double lat, double lng) => 'geo:${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
int _e7(double v) => (v * 1e7).round();

Map<String, dynamic> androidExport(List<Event> events) {
  final segments = <Map<String, dynamic>>[];
  final raw = <Map<String, dynamic>>[];
  for (final e in events) {
    switch (e) {
      case Visit():
        segments.add({
          'startTime': _iso(e.start),
          'endTime': _iso(e.end),
          'startTimeTimezoneUtcOffsetMinutes': 60,
          'endTimeTimezoneUtcOffsetMinutes': 60,
          'visit': {
            'hierarchyLevel': 0,
            'probability': 0.9,
            'topCandidate': {
              'placeId': e.place.id,
              'semanticType': e.place.type,
              'probability': 0.85,
              'placeLocation': {'latLng': _deg(e.place.lat, e.place.lng)},
            },
          },
        });
      case Move():
        segments.add({
          'startTime': _iso(e.start),
          'endTime': _iso(e.end),
          'activity': {
            'start': {'latLng': _deg(e.from.lat, e.from.lng)},
            'end': {'latLng': _deg(e.to.lat, e.to.lng)},
            'distanceMeters': (_distanceKm(e.from, e.to) * 1000).roundToDouble(),
            'probability': 0.95,
            'topCandidate': {'type': e.mode, 'probability': 0.9},
          },
        });
        segments.add({
          'startTime': _iso(e.start),
          'endTime': _iso(e.end),
          'timelinePath': [
            for (final (lat, lng, t) in e.path) {'point': _deg(lat, lng), 'time': _iso(t)},
          ],
        });
        for (var i = 0; i < e.path.length; i += 3) {
          final (lat, lng, t) = e.path[i];
          raw.add({
            'position': {
              'LatLng': _deg(lat, lng),
              'accuracyMeters': 5 + rnd.nextInt(20),
              'altitudeMeters': 520.0,
              'source': 'GPS',
              'timestamp': _iso(t),
            },
          });
        }
        raw.add({
          'wifiScan': {'deliveryTime': _iso(e.start), 'devicesRecords': []},
        });
    }
  }
  return {
    'semanticSegments': segments,
    'rawSignals': raw,
    'userLocationProfile': {
      'frequentPlaces': [
        {'placeId': home.id, 'placeLocation': _deg(home.lat, home.lng), 'label': 'HOME'},
        {'placeId': work.id, 'placeLocation': _deg(work.lat, work.lng), 'label': 'WORK'},
      ],
    },
  };
}

List<Map<String, dynamic>> iosExport(List<Event> events) => [
      for (final e in events)
        ...switch (e) {
          Visit() => [
              {
                'startTime': _iso(e.start),
                'endTime': _iso(e.end),
                'visit': {
                  'hierarchyLevel': '0',
                  'probability': '0.900000',
                  'topCandidate': {
                    'probability': '0.850000',
                    'semanticType': e.place.type == 'UNKNOWN' ? 'Unknown' : e.place.type == 'HOME' ? 'Home' : 'Work',
                    'placeID': e.place.id,
                    'placeLocation': _geo(e.place.lat, e.place.lng),
                  },
                },
              },
            ],
          Move() => [
              {
                'startTime': _iso(e.start),
                'endTime': _iso(e.end),
                'activity': {
                  'start': _geo(e.from.lat, e.from.lng),
                  'end': _geo(e.to.lat, e.to.lng),
                  'distanceMeters': (_distanceKm(e.from, e.to) * 1000).toStringAsFixed(0),
                  'topCandidate': {'type': e.mode.toLowerCase(), 'probability': '0.900000'},
                },
              },
              {
                'startTime': _iso(e.start),
                'endTime': _iso(e.end),
                'timelinePath': [
                  for (final (lat, lng, t) in e.path)
                    {
                      'point': _geo(lat, lng),
                      'durationMinutesOffsetFromStartTime': '${t.difference(e.start).inMinutes}',
                    },
                ],
              },
            ],
        },
    ];

Map<String, dynamic> takeoutRecords(List<Event> events) {
  final locations = <Map<String, dynamic>>[];
  void add(double lat, double lng, DateTime t) => locations.add({
        'latitudeE7': _e7(lat),
        'longitudeE7': _e7(lng),
        'accuracy': 5 + rnd.nextInt(30),
        'source': 'GPS',
        'deviceTag': 123456789,
        'timestamp': _iso(t),
      });
  for (final e in events) {
    switch (e) {
      case Visit():
        for (var t = e.start; t.isBefore(e.end); t = t.add(const Duration(minutes: 30))) {
          add(e.place.lat + _noise() / 3, e.place.lng + _noise() / 3, t);
        }
      case Move():
        for (final (lat, lng, t) in e.path) {
          add(lat, lng, t);
        }
    }
  }
  return {'locations': locations};
}

Map<String, dynamic> takeoutSemantic(List<Event> events) {
  Map<String, dynamic> loc(Place p) => {'latitudeE7': _e7(p.lat), 'longitudeE7': _e7(p.lng)};
  Map<String, dynamic> dur(DateTime a, DateTime b) => {'startTimestamp': _iso(a), 'endTimestamp': _iso(b)};
  return {
    'timelineObjects': [
      for (final e in events)
        switch (e) {
          Visit() => {
              'placeVisit': {
                'location': {...loc(e.place), 'placeId': e.place.id, 'name': e.place.name},
                'duration': dur(e.start, e.end),
                'placeConfidence': 'HIGH_CONFIDENCE',
              },
            },
          Move() => {
              'activitySegment': {
                'startLocation': loc(e.from),
                'endLocation': loc(e.to),
                'duration': dur(e.start, e.end),
                'distance': (_distanceKm(e.from, e.to) * 1000).round(),
                'activityType': e.mode,
                'waypointPath': {
                  'waypoints': [
                    for (var i = 0; i < e.path.length; i += 4)
                      {'latE7': _e7(e.path[i].$1), 'lngE7': _e7(e.path[i].$2)},
                  ],
                },
              },
            },
        },
    ],
  };
}

void main() {
  final dir = Directory('sample_data')..createSync(recursive: true);
  void write(String name, Object json, int events) {
    final f = File('${dir.path}/$name')..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
    stdout.writeln('${f.path}: $events Ereignisse, ${(f.lengthSync() / 1e6).toStringAsFixed(1)} MB');
  }

  final android = simulate('2025-01-01', '2026-10-29');
  write('Timeline_Android_2025-2026.json', androidExport(android), android.length);

  final ios = simulate('2024-09-01', '2024-12-31');
  write('Timeline_iPhone_2024.json', iosExport(ios), ios.length);

  final records = simulate('2023-01-01', '2023-12-31');
  write('Takeout_Records_2023.json', takeoutRecords(records), records.length);

  final semantic = simulate('2022-06-01', '2022-08-31');
  write('Takeout_Semantic_2022.json', takeoutSemantic(semantic), semantic.length);
}
