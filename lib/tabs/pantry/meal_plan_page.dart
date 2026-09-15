import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/meal_plan.dart';
import 'package:productivity/dataclasses/recipe.dart';
import 'package:productivity/dataservice/haushalt_sicht.dart';
import 'package:productivity/dataservice/meal_plan_service.dart';
import 'package:productivity/widgets/bereich_umschalter.dart';
import 'package:productivity/dataclasses/shopping_suggestion.dart';
import 'package:productivity/dataservice/recipe_service.dart';
import 'package:productivity/dataclasses/einkauf.dart';
import 'package:productivity/dataservice/einkauf_service.dart';
import 'package:productivity/utils/snack.dart';
import 'package:intl/intl.dart';

class MealPlanPage extends BasePage {
  const MealPlanPage({super.key}) : super(title: 'Essensplaner');

  @override
  Widget buildBody(BuildContext context) {
    return const _MealPlanList();
  }
}

class _MealPlanList extends StatefulWidget {
  const _MealPlanList();

  @override
  State<_MealPlanList> createState() => _MealPlanListState();
}

class _MealPlanListState extends State<_MealPlanList> {
  List<MealPlanEntry> _entries = [];
  List<Recipe> _recipes = [];
  Map<String, Recipe> _recipeMap = {};
  bool _loading = true;

  /// „Alles / Meins / Unseres". Ohne Haushalt nicht zu sehen.
  Bereich _bereich = Bereich.alles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MealPlanService.loadAll(bereich: _bereich),
        // Die Rezeptauswahl bleibt bewusst auf „alles": man plant auch
        // mal ein persönliches Rezept in den gemeinsamen Plan.
        RecipeService.loadAll(),
      ]);

      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<MealPlanEntry>;
        _recipes = results[1] as List<Recipe>;
        _recipeMap = {for (var r in _recipes) r.id: r};
        _entries.sort((a, b) => a.date.compareTo(b.date));
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditDialog([MealPlanEntry? entry]) {
    String? selRecipeId = entry?.recipeId;
    String? selMealType = entry?.mealType ?? 'Mittagessen';
    DateTime selDate = entry?.date ?? DateTime.now();
    final servingsCtrl = TextEditingController(
      text: entry?.servings.toString() ?? '2',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry == null ? 'Essen planen' : 'Planung bearbeiten',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selRecipeId,
                decoration: const InputDecoration(labelText: 'Rezept'),
                items: _recipes
                    .map(
                      (r) => DropdownMenuItem(value: r.id, child: Text(r.name)),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selRecipeId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selMealType,
                decoration: const InputDecoration(labelText: 'Mahlzeit'),
                items: ['Frühstück', 'Mittagessen', 'Abendessen', 'Snack']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selMealType = v),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('Datum'),
                subtitle: Text(DateFormat('EEEE, dd.MM.yyyy').format(selDate)),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDialogState(() => selDate = picked);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: servingsCtrl,
                decoration: const InputDecoration(labelText: 'Personen'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (entry != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await MealPlanService.delete(entry.id);
                        nav.pop();
                        _load();
                      },
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (selRecipeId == null) return;
                      final nav = Navigator.of(context);
                      final newEntry = MealPlanEntry(
                        id: entry?.id ?? '',
                        recipeId: selRecipeId!,
                        date: selDate,
                        mealType: selMealType,
                        servings: int.tryParse(servingsCtrl.text) ?? 2,
                      );
                      await MealPlanService.upsert(
                        newEntry,
                        unseres: _bereich.legtFuerHaushaltAn,
                      );
                      nav.pop();
                      _load();
                    },
                    child: const Text('Speichern'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_entries.isNotEmpty) ...[
            FloatingActionButton.small(
              onPressed: _generateShoppingList,
              tooltip: 'Einkaufsliste aus dem Plan erzeugen',
              heroTag: 'gen-shopping',
              child: const Icon(Icons.shopping_cart_checkout),
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            onPressed: () => _showEditDialog(),
            heroTag: 'add-meal',
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          BereichsUmschalter(
            bereich: _bereich,
            onWechsel: (b) {
              setState(() {
                _bereich = b;
                _loading = true;
              });
              _load();
            },
          ),
          Expanded(
            child: _entries.isEmpty
          ? const Center(
              child: Text(
                'Noch kein Essen geplant.\nTippe auf +, um anzufangen!',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, i) {
                final entry = _entries[i];
                final recipe = _recipeMap[entry.recipeId];
                final showDateHeader =
                    i == 0 ||
                    DateFormat('yyyy-MM-dd').format(_entries[i - 1].date) !=
                        DateFormat('yyyy-MM-dd').format(entry.date);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          _formatDate(entry.date),
                          style: text.titleMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: ListTile(
                        leading: _getMealIcon(entry.mealType ?? '', colors),
                        title: Text(
                          recipe?.name ?? 'Unbekanntes Rezept',
                          style: text.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          [
                            entry.mealType,
                            '${entry.servings} Personen',
                            // Auf „Alles" stehen beide nebeneinander --
                            // dann muss man sie unterscheiden können.
                            if (entry.istUnseres) 'unser Plan',
                          ].whereType<String>().join(' • '),
                        ),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _showEditDialog(entry),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Leitet aus den geplanten Rezepten ab, was noch eingekauft werden muss,
  /// zeigt die Rechnung und legt die bestätigten Posten an.
  Future<void> _generateShoppingList() async {
    if (_entries.isEmpty) return;

    // Zeitraum = was tatsächlich im Plan steht.
    final tage = _entries.map((e) => e.date).toList()..sort();
    final von = tage.first;
    final bis = tage.last;

    List<ShoppingSuggestion> vorschlaege;
    try {
      vorschlaege = await MealPlanService.shoppingSuggestions(from: von, to: bis);
    } catch (e) {
      showErrorSnack('Konnte den Bedarf nicht berechnen: $e');
      return;
    }

    final offen = vorschlaege.where((v) => v.toBuy > 0).toList();
    if (!mounted) return;
    if (offen.isEmpty) {
      showSnack('Alles da — nichts einzukaufen');
      return;
    }

    // Auf WELCHE Liste? Frueher gab es nur eine, die Frage stellte sich
    // nicht. Jetzt schon — und eine falsche Wahl faellt erst im Laden auf.
    final liste = await _listeWaehlen();
    if (liste == null || !mounted) return;

    // Was dort schon steht, wird gar nicht erst angeboten: sonst haette man
    // nach dem zweiten Durchlauf alles doppelt. Verglichen wird ueber den
    // Namen, nicht ueber die Zutat — wer „Milch" von Hand getippt hat, will
    // sie nicht ein zweites Mal.
    Set<String> vorhanden;
    try {
      final positionen = await EinkaufService.positionen(liste.id);
      vorhanden = {
        for (final p in positionen.where((p) => !p.erledigt))
          p.name.trim().toLowerCase(),
      };
    } catch (e) {
      if (mounted) showErrorSnack('Konnte „${liste.name}" nicht lesen: $e');
      return;
    }
    if (!mounted) return;

    final neuLage =
        offen.where((v) => !vorhanden.contains(
            v.ingredientName.trim().toLowerCase())).toList();
    if (neuLage.isEmpty) {
      showSnack('Steht schon alles auf „${liste.name}".');
      return;
    }

    final gewaehlt = {for (final v in neuLage) v.ingredientId: true};
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Auf „${liste.name}"'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  '${DateFormat('dd.MM.').format(von)} – '
                  '${DateFormat('dd.MM.').format(bis)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final v in neuLage)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: gewaehlt[v.ingredientId],
                    onChanged: (an) =>
                        setLocal(() => gewaehlt[v.ingredientId] = an ?? false),
                    title: Text(
                      '${v.ingredientName} · '
                      '${_fmtMenge(v.toBuy)}${v.unitSymbol != null ? ' ${v.unitSymbol}' : ''}',
                    ),
                    subtitle: Text(
                      v.pantryComparable
                          ? 'Bedarf ${_fmtMenge(v.needed)}, '
                            'Vorrat ${_fmtMenge(v.inPantry)}'
                          : 'Bedarf ${_fmtMenge(v.needed)} · '
                            'Vorrat in anderer Einheit, nicht verrechnet',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Auf die Liste'),
            ),
          ],
        ),
      ),
    );
    if (bestaetigt != true) return;

    final zuAnlegen = neuLage.where((v) => gewaehlt[v.ingredientId] == true);
    var angelegt = 0;
    try {
      for (final v in zuAnlegen) {
        // Die Zutat wandert mit. Ohne sie liesse sich der Posten spaeter
        // nicht in den Vorrat zurueckbuchen, und der Kreislauf
        // Essensplan -> Einkauf -> Vorrat bliebe offen.
        await EinkaufService.positionAnlegen(
          liste.id,
          name: v.ingredientName,
          menge: v.toBuy,
          ingredientId: v.ingredientId,
          unitId: v.unitId,
        );
        angelegt++;
      }
    } catch (e) {
      showErrorSnack('Nach $angelegt Posten abgebrochen: $e');
      return;
    }
    showSnack(
      angelegt == 1
          ? '1 Posten auf „${liste.name}"'
          : '$angelegt Posten auf „${liste.name}"',
    );
  }

  /// Fragt, auf welche Einkaufsliste die Posten sollen.
  ///
  /// Bei genau einer Liste wird nicht gefragt — eine Rueckfrage mit einer
  /// einzigen Antwort ist keine.
  Future<Einkaufsliste?> _listeWaehlen() async {
    List<Einkaufsliste> listen;
    try {
      listen = await EinkaufService.listen();
    } catch (e) {
      if (mounted) showErrorSnack('Konnte die Einkaufslisten nicht laden: $e');
      return null;
    }
    if (!mounted) return null;

    if (listen.isEmpty) {
      showErrorSnack('Keine Einkaufsliste vorhanden — erst eine anlegen.');
      return null;
    }
    if (listen.length == 1) return listen.first;

    return showDialog<Einkaufsliste>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auf welche Liste?'),
        children: [
          for (final l in listen)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, l),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle,
                    color: Color(
                        int.parse(l.color.replaceFirst('#', '0xFF')))),
                title: Text(l.name),
                subtitle: Text(l.offen == 1
                    ? '1 offener Posten'
                    : '${l.offen} offene Posten'),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtMenge(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Morgen';
    return DateFormat('EEEE, dd. MMMM', 'de_DE').format(date);
  }

  Widget _getMealIcon(String type, ColorScheme colors) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'frühstück':
        icon = Icons.coffee_outlined;
        break;
      case 'mittagessen':
        icon = Icons.lunch_dining_outlined;
        break;
      case 'abendessen':
        icon = Icons.dinner_dining_outlined;
        break;
      default:
        icon = Icons.restaurant_outlined;
    }
    return CircleAvatar(
      backgroundColor: colors.primaryContainer,
      child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
    );
  }
}
