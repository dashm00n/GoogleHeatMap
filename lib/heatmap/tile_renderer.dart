import 'dart:math' as math;
import 'dart:typed_data';

import 'heatmap_data.dart' show tileSize;

/// Eingabe für [renderHeatTile]; wird an ein Hintergrund-Isolate geschickt.
class TileJob {
  TileJob(this.points, this.radius, this.reference);

  /// Flach: x, y, Gewicht (Pixel relativ zur Kachel).
  final Float64List points;
  final double radius;
  final double reference;
}

/// Farbverlauf von transparent-blau über cyan, grün, gelb nach rot.
const _stops = <(double, int, int, int, int)>[
  (0.00, 0, 0, 255, 0),
  (0.15, 0, 0, 255, 140),
  (0.35, 0, 255, 255, 170),
  (0.55, 0, 255, 0, 190),
  (0.75, 255, 255, 0, 210),
  (1.00, 255, 0, 0, 230),
];

final Uint8List _gradient = () {
  final lut = Uint8List(256 * 4);
  for (var i = 0; i < 256; i++) {
    final t = i / 255;
    var s = 0;
    while (s < _stops.length - 2 && t > _stops[s + 1].$1) {
      s++;
    }
    final a = _stops[s], b = _stops[s + 1];
    final f = ((t - a.$1) / (b.$1 - a.$1)).clamp(0.0, 1.0);
    int mix(int x, int y) => (x + (y - x) * f).round();
    lut[i * 4] = mix(a.$2, b.$2);
    lut[i * 4 + 1] = mix(a.$3, b.$3);
    lut[i * 4 + 2] = mix(a.$4, b.$4);
    lut[i * 4 + 3] = mix(a.$5, b.$5);
  }
  return lut;
}();

/// Rendert eine 256×256-Heatmap-Kachel als RGBA-Pixel (nicht vormultipliziert).
Uint8List renderHeatTile(TileJob job) {
  const size = tileSize;
  final density = Float32List(size * size);
  final r = job.radius;
  final ri = r.ceil();
  final kSize = 2 * ri + 1;
  final kernel = Float32List(kSize * kSize);
  for (var dy = -ri; dy <= ri; dy++) {
    for (var dx = -ri; dx <= ri; dx++) {
      final d2 = (dx * dx + dy * dy) / (r * r);
      if (d2 < 1) kernel[(dy + ri) * kSize + dx + ri] = (1 - d2) * (1 - d2);
    }
  }

  final pts = job.points;
  for (var i = 0; i < pts.length; i += 3) {
    final px = pts[i].round(), py = pts[i + 1].round();
    final w = pts[i + 2];
    final y0 = math.max(0, py - ri), y1 = math.min(size - 1, py + ri);
    final x0 = math.max(0, px - ri), x1 = math.min(size - 1, px + ri);
    for (var y = y0; y <= y1; y++) {
      final krow = (y - py + ri) * kSize - px + ri;
      final drow = y * size;
      for (var x = x0; x <= x1; x++) {
        density[drow + x] += w * kernel[krow + x];
      }
    }
  }

  final pixels = Uint8List(size * size * 4);
  final logRef = math.log(1 + job.reference);
  for (var i = 0; i < density.length; i++) {
    final d = density[i];
    if (d <= 0) continue;
    final t = (math.log(1 + d) / logRef).clamp(0.0, 1.0);
    final c = (t * 255).round() * 4;
    pixels[i * 4] = _gradient[c];
    pixels[i * 4 + 1] = _gradient[c + 1];
    pixels[i * 4 + 2] = _gradient[c + 2];
    pixels[i * 4 + 3] = _gradient[c + 3];
  }
  return pixels;
}
