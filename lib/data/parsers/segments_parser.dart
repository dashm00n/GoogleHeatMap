import '../location_point.dart';
import 'json_helpers.dart';

/// Liest Zeitachsen-Segmente aus dem aktuellen On-Device-Export.
///
/// Android (`{"semanticSegments": [...], "rawSignals": [...]}`) und iOS
/// (Top-Level-Array) verwenden fast dieselbe Segmentstruktur; sie unterscheiden
/// sich nur in der Koordinatenschreibweise und bei Zeitangaben in Wegpunkten.
void parseSegments(List<dynamic> segments, PointSetBuilder out) {
  for (final s in segments) {
    final seg = asMap(s);
    if (seg == null) continue;
    final start = parseTimeSec(seg['startTime']);
    final end = parseTimeSec(seg['endTime']);

    final visit = asMap(seg['visit']);
    if (visit != null) {
      final loc = latLngOf(asMap(visit['topCandidate'])?['placeLocation']);
      if (loc != null) {
        final minutes = (start > 0 && end > start) ? (end - start) ~/ 60 : 0;
        out.add(loc.$1, loc.$2, start, PointKind.visit, minutes);
      }
    }

    final activity = asMap(seg['activity']);
    if (activity != null) {
      final a = latLngOf(activity['start']);
      if (a != null) out.add(a.$1, a.$2, start, PointKind.path);
      final b = latLngOf(activity['end']);
      if (b != null) out.add(b.$1, b.$2, end, PointKind.path);
    }

    for (final p in asList(seg['timelinePath'])) {
      final point = asMap(p);
      final loc = latLngOf(point?['point']);
      if (point == null || loc == null) continue;
      var t = parseTimeSec(point['time']);
      if (t == 0 && start > 0) {
        // iOS: Minuten-Offset relativ zum Segmentbeginn.
        t = start + (parseNum(point['durationMinutesOffsetFromStartTime']) * 60).round();
      }
      out.add(loc.$1, loc.$2, t, PointKind.path);
    }
  }
}

/// Liest die rohen GPS-Signale aus dem Android-Export.
void parseRawSignals(List<dynamic> signals, PointSetBuilder out) {
  for (final s in signals) {
    final pos = asMap(asMap(s)?['position']);
    final loc = latLngOf(pos);
    if (pos == null || loc == null) continue;
    out.add(loc.$1, loc.$2, parseTimeSec(pos['timestamp']), PointKind.raw);
  }
}
