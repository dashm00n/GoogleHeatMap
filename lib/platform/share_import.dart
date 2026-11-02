import 'package:flutter/services.dart';

/// Empfängt Dateien, die über „Teilen“ / „Öffnen mit“ an die App geschickt
/// werden (derzeit nur Android, siehe MainActivity.kt).
class ShareImport {
  ShareImport(this.onFile);

  final void Function(String path) onFile;

  static const _channel = MethodChannel('de.vierzigmann.google_heat_map/import');

  /// Registriert den Listener und holt eine beim Start übergebene Datei ab.
  Future<void> start() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'fileAvailable') await _take();
    });
    await _take();
  }

  Future<void> _take() async {
    try {
      final path = await _channel.invokeMethod<String>('takePendingFile');
      if (path != null) onFile(path);
    } on MissingPluginException {
      // Plattform ohne Teilen-Unterstützung (z. B. iOS): Import nur über Dateiauswahl.
    }
  }
}
