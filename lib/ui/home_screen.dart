import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../data/location_point.dart';
import '../data/parsers/timeline_parser.dart';
import '../heatmap/heatmap_tile_provider.dart';
import '../platform/share_import.dart';
import 'empty_state.dart';
import 'filter_sheet.dart';
import 'settings_screen.dart';

/// Einziger Server, mit dem die App spricht: OpenStreetMap-Kartenkacheln.
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  bool _mapReady = false;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    ShareImport(_import).start();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final hasData = !state.points.isEmpty;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Meine Heatmap'),
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            actions: [
              if (hasData)
                IconButton(
                  tooltip: 'Filter',
                  icon: Badge(
                    isLabelVisible: state.filter.hasDateRange ||
                        state.filter.kinds.length != PointKind.values.length,
                    child: const Icon(Icons.filter_alt_outlined),
                  ),
                  onPressed: () => showFilterSheet(context, state),
                ),
              IconButton(
                tooltip: 'Einstellungen',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SettingsScreen(state: state)),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: const LatLng(51.2, 10.4),
                  initialZoom: 5,
                  minZoom: 2,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    _fitToData();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: osmTileUrl,
                    userAgentPackageName: 'de.vierzigmann.google_heat_map',
                    maxNativeZoom: 19,
                  ),
                  TileLayer(
                    key: ValueKey(state.heatmap.generation),
                    tileProvider: HeatmapTileProvider(state.heatmap),
                    maxNativeZoom: 19,
                    tileDisplay: const TileDisplay.instantaneous(),
                  ),
                  const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
                ],
              ),
              if (!state.loading && !hasData) EmptyState(onImport: _pickAndImport),
              if (state.importing || state.loading)
                const ColoredBox(
                  color: Colors.black38,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
          floatingActionButton: hasData && !state.importing
              ? FloatingActionButton(
                  tooltip: 'Zeitachse importieren',
                  onPressed: _pickAndImport,
                  child: const Icon(Icons.upload_file),
                )
              : null,
        );
      },
    );
  }

  Future<void> _pickAndImport() async {
    final file = await FilePicker.pickFile(dialogTitle: 'Zeitachsen-Export auswählen');
    if (file == null) return;
    final path = file.path;
    // Im Browser gibt es keinen Dateipfad, dort werden die Bytes direkt gelesen.
    if (path != null) {
      await _import(path);
    } else {
      await _import(null, await file.readAsBytes());
    }
  }

  Future<void> _import(String? path, [Uint8List? bytes]) async {
    if (state.importing) return;
    var merge = false;
    if (!state.points.isEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bestehende Daten'),
          content: const Text(
              'Sollen die neuen Daten zu den vorhandenen hinzugefügt werden oder sie ersetzen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ersetzen')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true), child: const Text('Hinzufügen')),
          ],
        ),
      );
      if (choice == null) return;
      merge = choice;
    }

    String message;
    try {
      final r = await state.importFile(path: path, bytes: bytes, merge: merge);
      message = '${r.imported} Punkte importiert (${r.formatName}).';
      _fitToData();
    } on TimelineFormatException catch (e) {
      message = e.message;
    } catch (e) {
      message = 'Import fehlgeschlagen: $e';
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Zoomt auf den Bereich, in dem 98 % der Punkte liegen (Ausreißer wie
  /// einzelne Fernreisen sollen die Ansicht nicht auf die Weltkarte ziehen).
  void _fitToData() {
    final s = state.points;
    if (!_mapReady || s.isEmpty) return;
    final lats = Float32List.fromList(s.lat)..sort();
    final lngs = Float32List.fromList(s.lng)..sort();
    int q(double f) => ((s.length - 1) * f).round();
    final bounds = LatLngBounds(
      LatLng(lats[q(0.01)], lngs[q(0.01)]),
      LatLng(lats[q(0.99)], lngs[q(0.99)]),
    );
    _map.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48), maxZoom: 15),
    );
  }
}
