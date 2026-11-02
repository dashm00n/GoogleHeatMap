import '../location_point.dart';
import 'json_helpers.dart';

/// Altes Google-Takeout `Records.json`: `{"locations": [{latitudeE7, longitudeE7, timestamp}]}`.
void parseTakeoutRecords(List<dynamic> locations, PointSetBuilder out) {
  for (final l in locations) {
    final loc = asMap(l);
    if (loc == null) continue;
    final lat = fromE7(loc['latitudeE7']);
    final lng = fromE7(loc['longitudeE7']);
    if (lat == null || lng == null) continue;
    out.add(lat, lng, parseTimeSec(loc['timestamp'] ?? loc['timestampMs']), PointKind.raw);
  }
}

/// Altes Google-Takeout „Semantic Location History“ (`{"timelineObjects": [...]}`).
void parseTakeoutSemantic(List<dynamic> objects, PointSetBuilder out) {
  for (final o in objects) {
    final obj = asMap(o);
    if (obj == null) continue;

    final visit = asMap(obj['placeVisit']);
    if (visit != null) {
      final loc = asMap(visit['location']);
      final (start, end) = _duration(visit);
      final lat = fromE7(loc?['latitudeE7']);
      final lng = fromE7(loc?['longitudeE7']);
      if (lat != null && lng != null) {
        final minutes = (start > 0 && end > start) ? (end - start) ~/ 60 : 0;
        out.add(lat, lng, start, PointKind.visit, minutes);
      }
    }

    final activity = asMap(obj['activitySegment']);
    if (activity != null) {
      final (start, end) = _duration(activity);
      _addE7(asMap(activity['startLocation']), start, out);
      _addE7(asMap(activity['endLocation']), end, out);
      for (final w in asList(asMap(activity['waypointPath'])?['waypoints'])) {
        final wp = asMap(w);
        final lat = fromE7(wp?['latE7']);
        final lng = fromE7(wp?['lngE7']);
        if (lat != null && lng != null) out.add(lat, lng, start, PointKind.path);
      }
      for (final p in asList(asMap(activity['simplifiedRawPath'])?['points'])) {
        final pt = asMap(p);
        final lat = fromE7(pt?['latE7']);
        final lng = fromE7(pt?['lngE7']);
        if (lat != null && lng != null) {
          out.add(lat, lng, parseTimeSec(pt?['timestamp'] ?? pt?['timestampMs']), PointKind.path);
        }
      }
    }
  }
}

(int, int) _duration(Map<String, dynamic> o) {
  final d = asMap(o['duration']);
  return (
    parseTimeSec(d?['startTimestamp'] ?? d?['startTimestampMs']),
    parseTimeSec(d?['endTimestamp'] ?? d?['endTimestampMs']),
  );
}

void _addE7(Map<String, dynamic>? loc, int time, PointSetBuilder out) {
  final lat = fromE7(loc?['latitudeE7']);
  final lng = fromE7(loc?['longitudeE7']);
  if (lat != null && lng != null) out.add(lat, lng, time, PointKind.path);
}
