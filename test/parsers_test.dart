import 'package:flutter_test/flutter_test.dart';
import 'package:google_heat_map/data/location_point.dart';
import 'package:google_heat_map/data/parsers/json_helpers.dart';
import 'package:google_heat_map/data/parsers/timeline_parser.dart';

const androidExport = '''
{
  "semanticSegments": [
    {
      "startTime": "2024-05-01T08:00:00.000+02:00",
      "endTime": "2024-05-01T10:00:00.000+02:00",
      "visit": {
        "hierarchyLevel": 0,
        "topCandidate": {
          "placeId": "abc",
          "placeLocation": { "latLng": "48.1371079°, 11.5753822°" }
        }
      }
    },
    {
      "startTime": "2024-05-01T10:00:00.000+02:00",
      "endTime": "2024-05-01T10:30:00.000+02:00",
      "activity": {
        "start": { "latLng": "48.1371079°, 11.5753822°" },
        "end": { "latLng": "48.1500000°, 11.5800000°" },
        "topCandidate": { "type": "WALKING" }
      }
    },
    {
      "startTime": "2024-05-01T10:00:00.000+02:00",
      "endTime": "2024-05-01T12:00:00.000+02:00",
      "timelinePath": [
        { "point": "48.1400000°, 11.5760000°", "time": "2024-05-01T10:10:00.000+02:00" },
        { "point": "48.1450000°, 11.5780000°", "time": "2024-05-01T10:20:00.000+02:00" }
      ]
    }
  ],
  "rawSignals": [
    { "position": { "LatLng": "-33.8688°, 151.2093°", "timestamp": "2024-05-02T00:00:00.000Z" } },
    { "wifiScan": { "deliveryTime": "2024-05-02T00:00:00.000Z" } }
  ],
  "userLocationProfile": {}
}
''';

const iosExport = '''
[
  {
    "startTime": "2023-07-01T09:00:00.000+02:00",
    "endTime": "2023-07-01T09:45:00.000+02:00",
    "visit": {
      "hierarchyLevel": "0",
      "topCandidate": { "placeID": "x", "placeLocation": "geo:52.520008,13.404954" }
    }
  },
  {
    "startTime": "2023-07-01T10:00:00.000+02:00",
    "endTime": "2023-07-01T11:00:00.000+02:00",
    "activity": { "start": "geo:52.520008,13.404954", "end": "geo:52.5163,13.3777" }
  },
  {
    "startTime": "2023-07-01T10:00:00.000+02:00",
    "endTime": "2023-07-01T12:00:00.000+02:00",
    "timelinePath": [
      { "point": "geo:52.5180,13.3900", "durationMinutesOffsetFromStartTime": "15" }
    ]
  }
]
''';

const takeoutRecords = '''
{
  "locations": [
    { "latitudeE7": 481371079, "longitudeE7": 115753822, "timestamp": "2019-01-01T12:00:00Z" },
    { "latitudeE7": 481371079, "longitudeE7": 115753822, "timestampMs": "1546344000000" },
    { "latitudeE7": 4294967295 }
  ]
}
''';

const takeoutSemantic = '''
{
  "timelineObjects": [
    {
      "placeVisit": {
        "location": { "latitudeE7": 535511000, "longitudeE7": 99937000 },
        "duration": { "startTimestamp": "2018-03-01T10:00:00Z", "endTimestamp": "2018-03-01T13:00:00Z" }
      }
    },
    {
      "activitySegment": {
        "startLocation": { "latitudeE7": 535511000, "longitudeE7": 99937000 },
        "endLocation": { "latitudeE7": 535600000, "longitudeE7": 100000000 },
        "duration": { "startTimestampMs": "1519902000000", "endTimestampMs": "1519905600000" },
        "waypointPath": { "waypoints": [ { "latE7": 535550000, "lngE7": 99950000 } ] },
        "simplifiedRawPath": { "points": [ { "latE7": 535560000, "lngE7": 99960000, "timestamp": "2018-03-01T13:30:00Z" } ] }
      }
    }
  ]
}
''';

int countKind(PointSet s, PointKind k) =>
    List.generate(s.length, s.kindAt).where((e) => e == k).length;

void main() {
  group('Koordinaten', () {
    test('Android-Schreibweise', () {
      expect(parseLatLngString('48.1371079°, 11.5753822°'), (48.1371079, 11.5753822));
    });
    test('iOS-Schreibweise', () {
      expect(parseLatLngString('geo:-33.8688,151.2093'), (-33.8688, 151.2093));
    });
    test('ungültig', () {
      expect(parseLatLngString('geo:95,10'), isNull);
      expect(parseLatLngString('abc'), isNull);
    });
    test('E7 mit Überlauf', () {
      expect(fromE7(4294967295), closeTo(-1e-7, 1e-9));
    });
  });

  test('Android-Export', () {
    final r = parseTimelineJson(androidExport);
    expect(r.formatName, contains('Android'));
    expect(r.points.length, 6);
    expect(countKind(r.points, PointKind.visit), 1);
    expect(countKind(r.points, PointKind.path), 4);
    expect(countKind(r.points, PointKind.raw), 1);
    expect(r.points.durationMin[0], 120);
    expect(r.points.lat[0], closeTo(48.1371, 1e-4));
    expect(r.points.years(), [2024]);
  });

  test('iOS-Export', () {
    final r = parseTimelineJson(iosExport);
    expect(r.formatName, contains('iPhone'));
    expect(r.points.length, 4);
    expect(r.points.durationMin[0], 45);
    // Wegpunkt: Segmentbeginn 08:00 UTC + 15 min
    final start = DateTime.parse('2023-07-01T10:00:00.000+02:00').millisecondsSinceEpoch ~/ 1000;
    expect(r.points.time[3], start + 15 * 60);
  });

  test('Takeout Records.json', () {
    final r = parseTimelineJson(takeoutRecords);
    expect(r.formatName, contains('Records'));
    expect(r.points.length, 2); // Eintrag ohne Längengrad wird verworfen
    expect(r.points.time[0], r.points.time[1]);
  });

  test('Takeout Semantic Location History', () {
    final r = parseTimelineJson(takeoutSemantic);
    expect(r.points.length, 5);
    expect(countKind(r.points, PointKind.visit), 1);
    expect(r.points.durationMin[0], 180);
  });

  test('Fehlermeldungen', () {
    expect(() => parseTimelineJson('kein json'), throwsA(isA<TimelineFormatException>()));
    expect(() => parseTimelineJson('{"foo": 1}'), throwsA(isA<TimelineFormatException>()));
    expect(() => parseTimelineJson('[]'), throwsA(isA<TimelineFormatException>()));
  });

  test('Zusammenführen entfernt Duplikate', () {
    final a = parseTimelineJson(androidExport).points;
    final merged = a.merge(a);
    expect(merged.length, a.length);
    final both = a.merge(parseTimelineJson(iosExport).points);
    expect(both.length, a.length + 4);
  });
}
