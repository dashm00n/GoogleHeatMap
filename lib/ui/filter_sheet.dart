import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/location_point.dart';

const _kindLabels = {
  PointKind.visit: 'Besuche',
  PointKind.path: 'Wegstrecken',
  PointKind.raw: 'GPS-Rohdaten',
};

Future<void> showFilterSheet(BuildContext context, AppState state) => showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => _FilterSheet(state: state),
      ),
    );

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final f = state.filter;
    final theme = Theme.of(context);
    final loc = MaterialLocalizations.of(context);

    int? selectedYear;
    if (f.from != null && f.to != null && f.from!.year == f.to!.year &&
        f.from == DateTime(f.from!.year) && f.to == DateTime(f.from!.year, 12, 31)) {
      selectedYear = f.from!.year;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Zeitraum', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Alle'),
                  selected: !f.hasDateRange,
                  onSelected: (_) => state.setFilter(f.copyWith(clearDates: true)),
                ),
                for (final y in state.years)
                  ChoiceChip(
                    label: Text('$y'),
                    selected: selectedYear == y,
                    onSelected: (_) =>
                        state.setFilter(f.copyWith(from: DateTime(y), to: DateTime(y, 12, 31))),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(f.hasDateRange && selectedYear == null
                      ? '${f.from == null ? '…' : loc.formatShortDate(f.from!)} – '
                          '${f.to == null ? '…' : loc.formatShortDate(f.to!)}'
                      : 'Eigener Zeitraum'),
                  onPressed: () => _pickRange(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Datenarten', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final k in PointKind.values)
                  FilterChip(
                    label: Text(_kindLabels[k]!),
                    selected: f.kinds.contains(k),
                    onSelected: (on) {
                      final kinds = {...f.kinds};
                      on ? kinds.add(k) : kinds.remove(k);
                      if (kinds.isNotEmpty) state.setFilter(f.copyWith(kinds: kinds));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${state.heatmap.length} von ${state.points.length} Punkten sichtbar',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final years = state.years;
    final first = DateTime(years.isEmpty ? 2005 : years.first);
    final last = DateTime(years.isEmpty ? DateTime.now().year : years.last, 12, 31);
    final f = state.filter;
    final range = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: f.from != null && f.to != null ? DateTimeRange(start: f.from!, end: f.to!) : null,
    );
    if (range != null) state.setFilter(f.copyWith(from: range.start, to: range.end));
  }
}
