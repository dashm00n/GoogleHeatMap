import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_heat_map/data/parsers/timeline_parser.dart';

/// Prüft die mit `dart run tool/generate_sample_data.dart` erzeugten Probedaten.
void main() {
  final files = {
    'Timeline_Android_2025-2026.json': 'Android',
    'Timeline_iPhone_2024.json': 'iPhone',
    'Takeout_Records_2023.json': 'Records',
    'Takeout_Semantic_2022.json': 'Semantic',
  };
  for (final MapEntry(key: name, value: format) in files.entries) {
    final file = File('sample_data/$name');
    test(name, () {
      final r = parseTimelineJson(file.readAsStringSync());
      expect(r.formatName, contains(format));
      expect(r.points.length, greaterThan(1000));
      // ignore: avoid_print
      print('$name: ${r.points.length} Punkte, Jahre ${r.points.years()}');
    }, skip: file.existsSync() ? false : 'Probedaten nicht erzeugt');
  }
}
