import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'heatmap_data.dart';
import 'tile_renderer.dart';

/// Liefert Heatmap-Kacheln für einen [TileLayer]. Dadurch übernimmt
/// flutter_map Caching, Zoom-Übergänge und flüssiges Verschieben.
class HeatmapTileProvider extends TileProvider {
  HeatmapTileProvider(this.data);

  final HeatmapData data;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      HeatmapTileImage(data, coordinates.x, coordinates.y, coordinates.z);
}

class HeatmapTileImage extends ImageProvider<HeatmapTileImage> {
  const HeatmapTileImage(this.data, this.x, this.y, this.z);

  final HeatmapData data;
  final int x, y, z;

  @override
  Future<HeatmapTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(HeatmapTileImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(_load());

  Future<ImageInfo> _load() async {
    final n = 1 << z;
    final level = data.level(z);
    final radius = data.settings.radius;
    final points =
        (y < 0 || y >= n) ? Float64List(0) : level.pointsForTile(x % n, y, radius);
    if (points.isEmpty) return ImageInfo(image: await _decode(Uint8List(4), 1));

    final reference = level.reference / data.settings.intensity;
    final pixels = await compute(renderHeatTile, TileJob(points, radius, reference));
    return ImageInfo(image: await _decode(pixels, tileSize));
  }

  static Future<ui.Image> _decode(Uint8List pixels, int size) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, size, size, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  @override
  bool operator ==(Object other) =>
      other is HeatmapTileImage &&
      other.data.generation == data.generation &&
      other.x == x &&
      other.y == y &&
      other.z == z;

  @override
  int get hashCode => Object.hash(data.generation, x, y, z);
}
