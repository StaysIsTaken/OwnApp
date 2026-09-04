import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein auf- und zuklappbarer Abschnitt auf einer Übersichtsseite.
///
/// Der Zustand bleibt lokal auf dem Gerät: ob jemand einen Abschnitt gerade
/// eingeklappt hat, ist eine Ansichtssache des Moments — anders als die
/// Anordnung der Kacheln, die zum Konto gehört und im Backend liegt.
class CollapsibleSection extends StatefulWidget {
  /// Eindeutig je Seite und Abschnitt, z.B. 'dashboard.uebersicht'.
  final String sectionKey;
  final String title;
  final bool initiallyExpanded;

  /// Rechts neben dem Titel, z.B. die Bearbeiten-Knöpfe.
  final List<Widget> actions;
  final Widget child;

  const CollapsibleSection({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.actions = const [],
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  bool? _offen;

  @override
  void initState() {
    super.initState();
    _lade();
  }

  Future<void> _lade() async {
    bool offen = widget.initiallyExpanded;
    try {
      final p = await SharedPreferences.getInstance();
      offen = p.getBool(_prefKey) ?? widget.initiallyExpanded;
    } catch (_) {
      // Kein lokaler Speicher – dann eben der Standard.
    }
    if (mounted) setState(() => _offen = offen);
  }

  String get _prefKey => 'section_open_${widget.sectionKey}';

  Future<void> _umschalten() async {
    final neu = !(_offen ?? widget.initiallyExpanded);
    setState(() => _offen = neu);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_prefKey, neu);
    } catch (_) {
      // Nicht gespeichert – die Ansicht stimmt trotzdem.
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    // Bis der gespeicherte Zustand da ist, den Standard zeigen — sonst
    // klappt der Abschnitt beim Laden sichtbar auf und wieder zu.
    final offen = _offen ?? widget.initiallyExpanded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _umschalten,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: offen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Text(widget.title, style: text.titleLarge),
                const Spacer(),
                ...widget.actions,
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              offen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: widget.child,
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
