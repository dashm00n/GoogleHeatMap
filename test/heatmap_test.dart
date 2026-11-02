import 'package:flutter_test/flutter_test.dart';
import 'package:google_heat_map/data/heat_settings.dart';
import 'package:google_heat_map/data/location_point.dart';
import 'package:google_heat_map/heatmap/heatmap_data.dart';
import 'package:google_heat_map/heatmap/tile_renderer.dart';

PointSet sample() {
  final b = PointSetBuilder();
  final t2023 = DateTime.utc(2023, 6, 1).millisecondsSinceEpoch ~/ 1000;
  final t2024 = DateTime.utc(2024, 6, 1).millisecondsSinceEpoch ~/ 1000;
  // München Marienplatz: 100 Wegpunkte 2024, ein langer Besuch 2023.
  for (var i = 0; i < 100; i++) {
    b.add(48.1371 + i * 1e-6, 11.5754, t2024 + i, PointKind.path);
  }
  b.add(48.1371, 11.5754, t2023, PointKind.visit, 600);
  b.add(52.52, 13.405, 0, PointKind.raw); // Berlin, ohne Zeit
  return b.build();
}

void main() {
  test('Filter nach Zeitraum und Art', () {
    final s = sample();
    expect(HeatmapData.build(s, const HeatFilter(), const HeatSettings()).length, 102);
    final only2024 = HeatFilter(from: DateTime(2024), to: DateTime(2024, 12, 31));
    expect(HeatmapData.build(s, only2024, const HeatSettings()).length, 100);
    const onlyVisits = HeatFilter(kinds: {PointKind.visit});
    expect(HeatmapData.build(s, onlyVisits, const HeatSettings()).length, 1);
  });

  test('Aggregation fasst nahe Punkte zusammen und findet die richtige Kachel', () {
    final data = HeatmapData.build(sample(), const HeatFilter(), const HeatSettings());
    // Zoom 12: München liegt in Kachel x=2179, y=1421.
    final level = data.level(12);
    final pts = level.pointsForTile(2179, 1421, 18);
    expect(pts, isNotEmpty);
    var total = 0.0;
    for (var i = 2; i < pts.length; i += 3) {
      total += pts[i];
    }
    // 100 Wegpunkte + Besuch mit 600 min → 1 + 20.
    expect(total, closeTo(121, 1e-6));
    expect(level.pointsForTile(0, 0, 18), isEmpty);
  });

  test('Kachel-Rendering färbt nur die Umgebung der Punkte', () {
    final data = HeatmapData.build(sample(), const HeatFilter(), const HeatSettings());
    final level = data.level(12);
    final pts = level.pointsForTile(2179, 1421, 18);
    final pixels = renderHeatTile(TileJob(pts, 18, level.reference));
    expect(pixels.length, 256 * 256 * 4);
    final px = pts[0].round(), py = pts[1].round();
    expect(pixels[(py * 256 + px) * 4 + 3], greaterThan(100)); // Zentrum deckend
    // Ecke weit weg vom Punkt bleibt transparent.
    final far = px < 128 ? 255 : 0;
    final farY = py < 128 ? 255 : 0;
    expect(pixels[(farY * 256 + far) * 4 + 3], 0);
  });
}
