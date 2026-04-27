import 'package:flutter/material.dart';
import 'package:productivity/main.dart';
import 'package:productivity/dataclasses/pantry_extras.dart';
import 'package:productivity/dataservice/pantry_service.dart';

class ManageStorageLocationsPage extends BasePage {
  const ManageStorageLocationsPage({super.key}) : super(title: 'Lagerorte verwalten');

  @override
  Widget buildBody(BuildContext context) {
    return const _LocationList();
  }
}

class _LocationList extends StatefulWidget {
  const _LocationList();

  @override
  State<_LocationList> createState() => _LocationListState();
}

class _LocationListState extends State<_LocationList> {
  List<StorageLocation> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await PantryService.loadLocations();
      if (!mounted) return;
      setState(() {
        _locations = list;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDialog([StorageLocation? loc]) {
    final ctrl = TextEditingController(text: loc?.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24, right: 24, top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              loc == null ? 'Neuer Lagerort' : 'Lagerort bearbeiten',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Name des Ortes',
                hintText: 'z.B. Kühlschrank, Keller...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (ctrl.text.trim().isEmpty) return;
                      final newLoc = StorageLocation(id: loc?.id ?? '', name: ctrl.text.trim());
                      await PantryService.upsertLocation(newLoc);
                      if (!mounted) return;
                      Navigator.pop(context);
                      _load();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Speichern'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        label: const Text('Lagerort'),
        icon: const Icon(Icons.add),
      ),
      body: _locations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warehouse_outlined, size: 64, color: colors.outline.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('Noch keine Lagerorte', style: text.bodyLarge?.copyWith(color: colors.outline)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _locations.length,
              itemBuilder: (context, i) {
                final loc = _locations[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant.withOpacity(0.5)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: colors.secondaryContainer,
                      child: Icon(Icons.location_on_outlined, color: colors.onSecondaryContainer, size: 20),
                    ),
                    title: Text(loc.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _showDialog(loc),
                          tooltip: 'Bearbeiten',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Löschen?'),
                                content: Text('Möchtest du "${loc.name}" wirklich löschen?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: Text('Löschen', style: TextStyle(color: colors.error)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await PantryService.deleteLocation(loc.id);
                              _load();
                            }
                          },
                          tooltip: 'Löschen',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
