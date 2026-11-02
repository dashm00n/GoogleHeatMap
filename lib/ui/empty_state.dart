import 'package:flutter/material.dart';

/// Anleitung, die angezeigt wird, solange noch keine Daten importiert sind.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 96, 16, 24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('So kommst du an deine Daten', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                    'Google speichert die Zeitachse nur noch auf deinem Handy. '
                    'Exportiere sie einmal und importiere die Datei hier. Die Daten bleiben auf dem Gerät.'),
                const SizedBox(height: 16),
                Text('Android', style: theme.textTheme.titleSmall),
                const Text('Einstellungen → Standort → Standortdienste → Zeitachse → '
                    '„Zeitachsendaten exportieren“'),
                const SizedBox(height: 12),
                Text('iPhone', style: theme.textTheme.titleSmall),
                const Text('Google Maps → Profilbild → Deine Zeitachse → ⋯ → Einstellungen → '
                    '„Zeitachsendaten exportieren“'),
                const SizedBox(height: 12),
                Text(
                  'Auch alte Google-Takeout-Dateien (Records.json, Semantic Location History) funktionieren.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Datei importieren'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
