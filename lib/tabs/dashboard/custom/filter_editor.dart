import 'package:flutter/material.dart';
import 'package:productivity/tabs/dashboard/custom/tile_filter.dart';

/// Bearbeitet die Filterregeln einer Kachel.
///
/// Aufbau je Zeile: Feld → Operator → Wert. Operator und Eingabeart ergeben
/// sich aus dem Datentyp des gewählten Feldes — es lässt sich also keine
/// unsinnige Bedingung zusammenklicken.
class FilterEditor extends StatelessWidget {
  final Map<String, FilterField> fields;
  final List<FilterRule> rules;
  final ValueChanged<List<FilterRule>> onChanged;

  const FilterEditor({
    super.key,
    required this.fields,
    required this.rules,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    if (fields.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Filter', style: text.labelLarge),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Bedingung'),
              onPressed: () {
                final erstes = fields.values.first;
                onChanged([
                  ...rules,
                  FilterRule(
                    field: erstes.key,
                    op: operatorsFor(erstes.type).first,
                  ),
                ]);
              },
            ),
          ],
        ),
        if (rules.isEmpty)
          Text(
            'Ohne Filter zählt alles.',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('und', style: text.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
            ),
          _Zeile(
            fields: fields,
            rule: rules[i],
            onChanged: (neu) {
              final liste = List<FilterRule>.from(rules);
              liste[i] = neu;
              onChanged(liste);
            },
            onRemove: () {
              final liste = List<FilterRule>.from(rules)..removeAt(i);
              onChanged(liste);
            },
          ),
        ],
      ],
    );
  }
}

class _Zeile extends StatelessWidget {
  final Map<String, FilterField> fields;
  final FilterRule rule;
  final ValueChanged<FilterRule> onChanged;
  final VoidCallback onRemove;

  const _Zeile({
    required this.fields,
    required this.rule,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final feld = fields[rule.field] ?? fields.values.first;
    final operatoren = operatorsFor(feld.type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ── Feld ──
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: feld.key,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Feld',
                    isDense: true,
                  ),
                  items: [
                    for (final f in fields.values)
                      DropdownMenuItem(value: f.key, child: Text(f.label)),
                  ],
                  onChanged: (k) {
                    if (k == null) return;
                    final neuesFeld = fields[k]!;
                    // Passt der bisherige Operator nicht zum neuen Typ,
                    // den ersten passenden nehmen.
                    final ops = operatorsFor(neuesFeld.type);
                    onChanged(FilterRule(
                      field: k,
                      op: ops.contains(rule.op) ? rule.op : ops.first,
                      value: '',
                    ));
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Bedingung entfernen',
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // ── Operator ──
              Expanded(
                flex: 5,
                child: DropdownButtonFormField<FilterOp>(
                  initialValue:
                      operatoren.contains(rule.op) ? rule.op : operatoren.first,
                  isDense: true,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final o in operatoren)
                      DropdownMenuItem(value: o, child: Text(o.label)),
                  ],
                  onChanged: (o) => o == null
                      ? null
                      : onChanged(FilterRule(
                          field: rule.field, op: o, value: rule.value)),
                ),
              ),
              if (rule.op.needsValue) ...[
                const SizedBox(width: 8),
                Expanded(flex: 4, child: _Wert(feld: feld, rule: rule, onChanged: onChanged)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Die Werteingabe richtet sich nach dem Datentyp: freie Eingabe bei Text und
/// Zahl, Auswahlliste bei festen Werten, Datumswähler bei Daten.
class _Wert extends StatelessWidget {
  final FilterField feld;
  final FilterRule rule;
  final ValueChanged<FilterRule> onChanged;

  const _Wert({required this.feld, required this.rule, required this.onChanged});

  void _setze(String v) =>
      onChanged(FilterRule(field: rule.field, op: rule.op, value: v));

  @override
  Widget build(BuildContext context) {
    // Feste Auswahl
    if (feld.type == FieldType.choice && feld.choices.isNotEmpty) {
      final wert = feld.choices.contains(rule.value) ? rule.value : null;
      return DropdownButtonFormField<String>(
        initialValue: wert,
        isDense: true,
        decoration: const InputDecoration(isDense: true, hintText: 'Wert'),
        items: [
          for (final c in feld.choices)
            DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => _setze(v ?? ''),
      );
    }

    // Datum – ausser bei „letzte N Tage", das ist eine Zahl
    if (feld.type == FieldType.date && rule.op != FilterOp.lastDays) {
      final gewaehlt = DateTime.tryParse(rule.value);
      return OutlinedButton(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: gewaehlt ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            _setze('${d.year.toString().padLeft(4, '0')}-'
                '${d.month.toString().padLeft(2, '0')}-'
                '${d.day.toString().padLeft(2, '0')}');
          }
        },
        child: Text(
          gewaehlt == null
              ? 'Datum'
              : '${gewaehlt.day.toString().padLeft(2, '0')}.'
                  '${gewaehlt.month.toString().padLeft(2, '0')}.'
                  '${gewaehlt.year}',
          maxLines: 1,
        ),
      );
    }

    // Zahl oder Text
    final zahl = feld.type == FieldType.number || rule.op == FilterOp.lastDays;
    return TextFormField(
      initialValue: rule.value,
      keyboardType: zahl
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        isDense: true,
        hintText: rule.op == FilterOp.lastDays ? 'Tage' : 'Wert',
      ),
      onChanged: _setze,
    );
  }
}
