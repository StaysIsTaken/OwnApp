import 'package:flutter/material.dart';
import 'package:productivity/dataservice/unit_service.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/unit.dart';
import 'package:productivity/widgets/manage_item_tile.dart';

class ManageUnitsPage extends BasePage {
  const ManageUnitsPage({super.key}) : super(title: 'Einheiten verwalten');

  @override
  Widget buildBody(BuildContext context) => const _ManageUnitsContent();
}

class _ManageUnitsContent extends StatefulWidget {
  const _ManageUnitsContent();

  @override
  State<_ManageUnitsContent> createState() => _ManageUnitsContentState();
}

class _ManageUnitsContentState extends State<_ManageUnitsContent> {
  List<Unit> _units = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final units = await UnitService.loadAll();
    if (!mounted) return;
    setState(() {
      _units = units;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(Unit unit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Einheit löschen?'),
        content: Text('„${unit.name} (${unit.symbol})" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await UnitService.delete(unit.id);
      await _load();
    }
  }

  void _openForm({Unit? unit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (_) => _UnitForm(
        unit: unit,
        onSave: (u) async {
          await UnitService.upsert(u);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Stack(
      children: [
        _loading
            ? const Center(child: CircularProgressIndicator())
            : _units.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten_outlined,
                            size: 64, color: colors.outlineVariant),
                        const SizedBox(height: 12),
                        Text('Noch keine Einheiten',
                            style: text.bodyMedium
                                ?.copyWith(color: colors.outline)),
                        const SizedBox(height: 6),
                        Text('Tippe auf + um eine Einheit anzulegen',
                            style: text.bodySmall
                                ?.copyWith(color: colors.outlineVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: _units.length,
                    itemBuilder: (_, i) => ManageItemTile(
                      title: _units[i].name,
                      subtitle: _units[i].symbol,
                      onEdit: () => _openForm(unit: _units[i]),
                      onDelete: () => _confirmDelete(_units[i]),
                    ),
                  ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _openForm(),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _UnitForm extends StatefulWidget {
  final Unit? unit;
  final Future<void> Function(Unit) onSave;

  const _UnitForm({this.unit, required this.onSave});

  @override
  State<_UnitForm> createState() => _UnitFormState();
}

class _UnitFormState extends State<_UnitForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _symbolCtrl;
  late final TextEditingController _factorCtrl;
  UnitDimension? _dimension;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.unit?.name ?? '');
    _symbolCtrl = TextEditingController(text: widget.unit?.symbol ?? '');
    _dimension = widget.unit?.dimension;
    final f = widget.unit?.factor ?? 1.0;
    _factorCtrl = TextEditingController(
      text: f % 1 == 0 ? f.toInt().toString() : f.toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _symbolCtrl.dispose();
    _factorCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final unit = Unit(
      // Leere id = neu (siehe UnitService.upsert).
      id: widget.unit?.id ?? '',
      name: _nameCtrl.text.trim(),
      symbol: _symbolCtrl.text.trim(),
      dimension: _dimension,
      factor: double.tryParse(_factorCtrl.text.replaceAll(',', '.')) ?? 1.0,
    );
    await widget.onSave(unit);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isEdit = widget.unit != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEdit ? 'Einheit bearbeiten' : 'Neue Einheit',
              style: text.titleLarge,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'z. B. Gramm',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name eingeben' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symbolCtrl,
              decoration: const InputDecoration(
                labelText: 'Symbol',
                hintText: 'z. B. g',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Symbol eingeben' : null,
            ),
            const SizedBox(height: 20),

            // ── Umrechnung ──────────────────────────────
            Text('Umrechnung', style: text.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Nur Einheiten derselben Art lassen sich verrechnen. '
              'Masse gegen Volumen geht nicht — dafür bräuchte es die Dichte '
              'der jeweiligen Zutat.',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UnitDimension?>(
              initialValue: _dimension,
              decoration: const InputDecoration(labelText: 'Art'),
              items: [
                const DropdownMenuItem<UnitDimension?>(
                  value: null,
                  child: Text('Nicht umrechenbar'),
                ),
                for (final d in UnitDimension.values)
                  DropdownMenuItem<UnitDimension?>(
                    value: d,
                    child: Text('${d.label} (Basis: ${d.baseSymbol})'),
                  ),
              ],
              onChanged: (v) => setState(() => _dimension = v),
            ),
            if (_dimension != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _factorCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Entspricht wie viel ${_dimension!.baseSymbol}?',
                  hintText: 'z. B. 1000 für kg',
                ),
                validator: (v) {
                  if (_dimension == null) return null;
                  final d = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (d == null || d <= 0) return 'Zahl größer als 0 eingeben';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isEdit ? 'Speichern' : 'Einheit anlegen'),
            ),
          ],
        ),
      ),
    );
  }
}
