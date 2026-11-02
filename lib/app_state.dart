import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'data/heat_settings.dart';
import 'data/location_point.dart';
import 'data/parsers/timeline_parser.dart';
import 'data/point_store.dart';
import 'heatmap/heatmap_data.dart';

class ImportResult {
  ImportResult(this.imported, this.total, this.formatName);
  final int imported;
  final int total;
  final String formatName;
}

/// Zentraler App-Zustand: geladene Punkte, Filter, Einstellungen.
class AppState extends ChangeNotifier {
  // Im Browser (Test am PC) gibt es kein Dateisystem: Daten nur im Speicher.
  PointStore? _store;
  File? _settingsFile;

  PointSet points = PointSet.empty();
  HeatFilter filter = const HeatFilter();
  HeatSettings settings = const HeatSettings();
  HeatmapData heatmap = HeatmapData.build(PointSet.empty(), const HeatFilter(), const HeatSettings());
  List<int> years = const [];

  bool loading = true;
  bool importing = false;

  Future<void> load() async {
    if (!kIsWeb) {
      final dir = await getApplicationSupportDirectory();
      final store = _store = PointStore(File('${dir.path}/points.bin'));
      final settingsFile = _settingsFile = File('${dir.path}/settings.json');
      try {
        if (await settingsFile.exists()) {
          settings = HeatSettings.fromJson(
              jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>);
        }
      } catch (_) {
        // Beschädigte Einstellungen ignorieren, Standardwerte verwenden.
      }
      points = await store.load();
    }
    _rebuild();
    loading = false;
    notifyListeners();
  }

  /// Importiert aus einem Dateipfad (Handy) oder aus Bytes (Browser).
  Future<ImportResult> importFile({String? path, Uint8List? bytes, required bool merge}) async {
    importing = true;
    notifyListeners();
    try {
      final result = path != null ? await parseTimelineFile(path) : await parseTimelineBytes(bytes!);
      final before = merge ? points.length : 0;
      final next = merge ? points.merge(result.points) : result.points;
      await _store?.save(next);
      points = next;
      filter = const HeatFilter();
      _rebuild();
      return ImportResult(next.length - before, next.length, result.formatName);
    } finally {
      importing = false;
      notifyListeners();
    }
  }

  void setFilter(HeatFilter f) {
    filter = f;
    _rebuild();
    notifyListeners();
  }

  Future<void> setSettings(HeatSettings s) async {
    settings = s;
    _rebuild();
    notifyListeners();
    await _settingsFile?.writeAsString(jsonEncode(s.toJson()));
  }

  Future<void> clearAll() async {
    await _store?.clear();
    points = PointSet.empty();
    filter = const HeatFilter();
    _rebuild();
    notifyListeners();
  }

  void _rebuild() {
    heatmap = HeatmapData.build(points, filter, settings);
    if (_yearsFor != points) {
      years = points.years();
      _yearsFor = points;
    }
  }

  PointSet? _yearsFor;
}
