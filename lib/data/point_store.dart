import 'dart:io';
import 'dart:typed_data';

import 'location_point.dart';

/// Speichert Punkte als kompakte Binärdatei im App-eigenen Ordner.
///
/// Aufbau: Kennung `GHM1`, Anzahl n (uint32), dann spaltenweise
/// lat (float32 × n), lng (float32 × n), time (uint32 × n),
/// durationMin (uint16 × n), kind (uint8 × n).
class PointStore {
  PointStore(this.file);

  final File file;

  static const _magic = 0x47484D31; // "GHM1"
  static const _header = 8;

  Future<PointSet> load() async {
    if (!await file.exists()) return PointSet.empty();
    // Kopie, damit die Typed-Data-Views garantiert ausgerichtet sind.
    final bytes = Uint8List.fromList(await file.readAsBytes());
    if (bytes.length < _header) return PointSet.empty();
    final bd = ByteData.sublistView(bytes);
    if (bd.getUint32(0) != _magic) return PointSet.empty();
    final n = bd.getUint32(4, Endian.little);
    if (bytes.length != _header + n * 13) return PointSet.empty();

    final buf = bytes.buffer;
    var o = _header;
    final lat = Float32List.fromList(buf.asFloat32List(o, n));
    o += 4 * n;
    final lng = Float32List.fromList(buf.asFloat32List(o, n));
    o += 4 * n;
    final time = Uint32List.fromList(buf.asUint32List(o, n));
    o += 4 * n;
    final duration = Uint16List.fromList(buf.asUint16List(o, n));
    o += 2 * n;
    final kind = Uint8List.fromList(buf.asUint8List(o, n));
    return PointSet(lat: lat, lng: lng, time: time, durationMin: duration, kind: kind);
  }

  Future<void> save(PointSet s) async {
    final n = s.length;
    final bytes = Uint8List(_header + n * 13);
    final bd = ByteData.sublistView(bytes);
    bd.setUint32(0, _magic);
    bd.setUint32(4, n, Endian.little);
    final buf = bytes.buffer;
    var o = _header;
    buf.asFloat32List(o, n).setAll(0, s.lat);
    o += 4 * n;
    buf.asFloat32List(o, n).setAll(0, s.lng);
    o += 4 * n;
    buf.asUint32List(o, n).setAll(0, s.time);
    o += 4 * n;
    buf.asUint16List(o, n).setAll(0, s.durationMin);
    o += 2 * n;
    buf.asUint8List(o, n).setAll(0, s.kind);

    // Erst in Temp-Datei schreiben, dann umbenennen: kein halber Datenstand bei Abbruch.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
