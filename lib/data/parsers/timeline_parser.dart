import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../location_point.dart';
import 'segments_parser.dart';
import 'takeout_parser.dart';

class TimelineFormatException implements Exception {
  TimelineFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ParseResult {
  ParseResult(this.points, this.formatName);
  final PointSet points;
  final String formatName;
}

/// Erkennt das Exportformat automatisch und liest alle Standortpunkte.
ParseResult parseTimelineJson(String content) {
  final Object? json;
  try {
    json = jsonDecode(content);
  } on FormatException {
    throw TimelineFormatException('Die Datei ist kein gültiges JSON.');
  }

  final out = PointSetBuilder();
  final String format;
  if (json is List) {
    parseSegments(json, out);
    format = 'Zeitachse (iPhone)';
  } else if (json is Map<String, dynamic> &&
      (json.containsKey('semanticSegments') || json.containsKey('rawSignals'))) {
    parseSegments(json['semanticSegments'] as List? ?? const [], out);
    parseRawSignals(json['rawSignals'] as List? ?? const [], out);
    format = 'Zeitachse (Android)';
  } else if (json is Map<String, dynamic> && json['locations'] is List) {
    parseTakeoutRecords(json['locations'] as List, out);
    format = 'Google Takeout (Records.json)';
  } else if (json is Map<String, dynamic> && json['timelineObjects'] is List) {
    parseTakeoutSemantic(json['timelineObjects'] as List, out);
    format = 'Google Takeout (Semantic Location History)';
  } else {
    throw TimelineFormatException(
        'Unbekanntes Format. Bitte die Zeitachse aus Google Maps exportieren.');
  }

  if (out.isEmpty) {
    throw TimelineFormatException('In der Datei wurden keine Standortdaten gefunden.');
  }
  return ParseResult(out.build(), format);
}

/// Liest und parst eine Datei im Hintergrund, damit die UI flüssig bleibt.
Future<ParseResult> parseTimelineFile(String path) => compute(_parseFile, path);

/// Wie [parseTimelineFile], aber für bereits geladene Bytes (Web).
Future<ParseResult> parseTimelineBytes(Uint8List bytes) => compute(_parseBytes, bytes);

ParseResult _parseFile(String path) => parseTimelineJson(File(path).readAsStringSync());

ParseResult _parseBytes(Uint8List bytes) =>
    parseTimelineJson(utf8.decode(bytes, allowMalformed: true));
