import 'package:flutter/material.dart';

import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state.settings;
          return ListView(
            children: [
              _SettingSlider(
                title: 'Punktgröße',
                value: s.radius,
                min: 8,
                max: 40,
                divisions: 16,
                format: (v) => v.round().toString(),
                onChangeEnd: (v) => state.setSettings(s.copyWith(radius: v)),
              ),
              _SettingSlider(
                title: 'Intensität',
                value: s.intensity,
                min: 0.3,
                max: 3,
                divisions: 27,
                format: (v) => v.toStringAsFixed(1),
                onChangeEnd: (v) => state.setSettings(s.copyWith(intensity: v)),
              ),
              SwitchListTile(
                title: const Text('Nach Aufenthaltsdauer gewichten'),
                subtitle: const Text('Orte, an denen du lange warst, leuchten stärker'),
                value: s.weightByDuration,
                onChanged: (v) => state.setSettings(s.copyWith(weightByDuration: v)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text('${state.points.length} gespeicherte Punkte'),
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Alle Daten löschen', style: TextStyle(color: theme.colorScheme.error)),
                enabled: !state.points.isEmpty,
                onTap: () => _confirmClear(context),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Datenschutz'),
                subtitle: Text(
                  'Deine Standortdaten verlassen nie dieses Gerät. Die App lädt nur '
                  'Kartenbilder von tile.openstreetmap.org (verschlüsselt über HTTPS). '
                  'Dabei sieht der OSM-Server deine IP-Adresse und welchen Kartenausschnitt '
                  'du ansiehst, aber keine importierten Daten.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.map_outlined),
                title: Text('Kartendaten'),
                subtitle: Text('© OpenStreetMap contributors (ODbL)'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle Daten löschen?'),
        content: const Text('Die importierten Standortdaten werden von diesem Gerät entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok == true) await state.clearAll();
  }
}

/// Slider, der erst beim Loslassen übernimmt: Die Heatmap neu zu berechnen
/// ist bei vielen Punkten zu teuer für jeden Zwischenwert.
class _SettingSlider extends StatefulWidget {
  const _SettingSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChangeEnd,
  });

  final String title;
  final double value, min, max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final v = _dragging ?? widget.value;
    return ListTile(
      title: Text('${widget.title}: ${widget.format(v)}'),
      subtitle: Slider(
        value: v,
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        label: widget.format(v),
        onChanged: (x) => setState(() => _dragging = x),
        onChangeEnd: (x) {
          setState(() => _dragging = null);
          widget.onChangeEnd(x);
        },
      ),
    );
  }
}
