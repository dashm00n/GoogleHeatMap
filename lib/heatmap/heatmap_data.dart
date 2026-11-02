import 'dart:math' as math;
import 'dart:typed_data';

import '../data/heat_settings.dart';
import '../data/location_point.dart';

const tileSize = 256;
const maxHeatZoom = 19;

/// Rasterzellengröße in Bildschirmpixeln für die Vorab-Aggregation.
const _cellPx = 3.0;

/// Gefilterte, gewichtete Punkte in Web-Mercator-Koordinaten (0..1) plus
/// pro Zoomstufe vorab aggregierte Raster, damit auch Hunderttausende Punkte
/// flüssig als Heatmap-Kacheln gerendert werden können.
class HeatmapData {
  HeatmapData._(this._x, this._y, this._w, this.settings, this.generation);

  factory HeatmapData.build(PointSet s, HeatFilter filter, HeatSettings settings) {
    final accept = filter.compile();
    final xs = <double>[], ys = <double>[], ws = <double>[];
    for (var i = 0; i < s.length; i++) {
      if (!accept(s, i)) continue;
      final lat = s.lat[i].clamp(-85.05112878, 85.05112878) * math.pi / 180;
      xs.add((s.lng[i] + 180) / 360);
      ys.add(0.5 - math.log(math.tan(math.pi / 4 + lat / 2)) / (2 * math.pi));
      var w = 1.0;
      if (settings.weightByDuration && s.kind[i] == PointKind.visit.index) {
        // Jede halbe Stunde Aufenthalt zählt wie ein weiterer Punkt (max. 1 Tag).
        w += math.min(s.durationMin[i], 24 * 60) / 30;
      }
      ws.add(w);
    }
    return HeatmapData._(
      Float64List.fromList(xs),
      Float64List.fromList(ys),
      Float64List.fromList(ws),
      settings,
      ++_generationCounter,
    );
  }

  static int _generationCounter = 0;

  final Float64List _x, _y, _w;
  final HeatSettings settings;

  /// Eindeutige Kennung dieses Datenstands (für Bild-Caches).
  final int generation;

  final _levels = <int, ZoomLevel>{};

  int get length => _x.length;

  ZoomLevel level(int z) => _levels.putIfAbsent(z, () => _buildLevel(z.clamp(0, maxHeatZoom)));

  ZoomLevel _buildLevel(int z) {
    final scale = tileSize * math.pow(2, z).toDouble();
    final cells = <int, _Cell>{};
    for (var i = 0; i < length; i++) {
      final px = _x[i] * scale, py = _y[i] * scale;
      final key = (px / _cellPx).floor() * 67108864 + (py / _cellPx).floor();
      (cells[key] ??= _Cell()).add(px, py, _w[i]);
    }

    final byTile = <int, List<double>>{};
    final tilesPerAxis = 1 << z;
    for (final c in cells.values) {
      final tx = (c.x / tileSize).floor().clamp(0, tilesPerAxis - 1);
      final ty = (c.y / tileSize).floor().clamp(0, tilesPerAxis - 1);
      (byTile[tx * tilesPerAxis + ty] ??= []).addAll([c.x, c.y, c.w]);
    }

    return ZoomLevel._(
      z,
      byTile.map((key, v) => MapEntry(key, Float64List.fromList(v))),
      math.max(1.0, _peakDensity(cells.values, settings.radius)),
    );
  }

  /// Höchste Dichte, die beim Rendern irgendwo entsteht (gleicher Kernel wie
  /// im Renderer). Dient als globaler Maßstab, damit Kacheln nahtlos sind und
  /// nur der heißeste Ort ganz rot wird.
  static double _peakDensity(Iterable<_Cell> cells, double r) {
    final buckets = <int, List<_Cell>>{};
    int key(int bx, int by) => bx * 67108864 + by;
    for (final c in cells) {
      (buckets[key((c.x / r).floor(), (c.y / r).floor())] ??= []).add(c);
    }
    var peak = 0.0;
    final r2 = r * r;
    for (final c in cells) {
      final bx = (c.x / r).floor(), by = (c.y / r).floor();
      var d = 0.0;
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          for (final o in buckets[key(bx + dx, by + dy)] ?? const <_Cell>[]) {
            final q = ((o.x - c.x) * (o.x - c.x) + (o.y - c.y) * (o.y - c.y)) / r2;
            if (q < 1) d += o.w * (1 - q) * (1 - q);
          }
        }
      }
      peak = math.max(peak, d);
    }
    return peak;
  }
}

class _Cell {
  double w = 0, sx = 0, sy = 0;

  double get x => sx / w;
  double get y => sy / w;

  void add(double x, double y, double weight) {
    w += weight;
    sx += x * weight;
    sy += y * weight;
  }
}

class ZoomLevel {
  ZoomLevel._(this.zoom, this._tiles, this.reference);

  final int zoom;
  final Map<int, Float64List> _tiles;

  /// Dichte, ab der eine Stelle als „voll heiß“ gilt (vor Intensitäts-Faktor).
  final double reference;

  /// Punkte (x, y, Gewicht) relativ zur Kachel [tx]/[ty], inklusive der
  /// Nachbarkacheln im Abstand [margin], damit Kachelgrenzen nahtlos sind.
  Float64List pointsForTile(int tx, int ty, double margin) {
    final n = 1 << zoom;
    final ox = tx * tileSize.toDouble(), oy = ty * tileSize.toDouble();
    final out = <double>[];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final nx = tx + dx, ny = ty + dy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final pts = _tiles[nx * n + ny];
        if (pts == null) continue;
        for (var i = 0; i < pts.length; i += 3) {
          final x = pts[i] - ox, y = pts[i + 1] - oy;
          if (x < -margin || y < -margin || x > tileSize + margin || y > tileSize + margin) continue;
          out
            ..add(x)
            ..add(y)
            ..add(pts[i + 2]);
        }
      }
    }
    return Float64List.fromList(out);
  }
}
