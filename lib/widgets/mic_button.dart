import 'package:flutter/material.dart';
import 'package:productivity/dataservice/transcription_service.dart';
import 'package:productivity/provider/permission_provider.dart';
import 'package:provider/provider.dart';

/// Mikrofon-Button: Tippen startet die Aufnahme, erneutes Tippen stoppt sie,
/// lädt das Audio hoch und liefert den transkribierten Text über [onText].
///
/// Drei Zustände: ruhend (mic), Aufnahme (stop, rot), Transkription (Spinner).
class MicButton extends StatefulWidget {
  /// Wird mit dem erkannten Text aufgerufen (nur wenn nicht leer).
  final void Function(String text) onText;

  /// Optionaler Sprachcode (z.B. 'de'); null = serverseitige Autoerkennung.
  final String? language;

  /// Optionales Whisper-Modell (z.B. 'small'); null = Servervorgabe.
  /// Für Diktate leer lassen, für kurze Sprachbefehle ein kleines wählen.
  final String? model;

  const MicButton({
    super.key,
    required this.onText,
    this.language = 'de',
    this.model,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool _recording = false;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_recording) {
      // Stoppen + transkribieren (Segmente erscheinen nach und nach)
      setState(() {
        _recording = false;
        _busy = true;
      });
      try {
        var gotAny = false;
        final text = await TranscriptionService.stopAndTranscribe(
          language: widget.language,
          model: widget.model,
          onSegment: (segment) {
            gotAny = true;
            widget.onText(segment.trim());
          },
        );
        if (!gotAny && text.trim().isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Nichts erkannt.')),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Transkription fehlgeschlagen: $e')),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      // Aufnahme starten
      try {
        if (!await TranscriptionService.hasPermission()) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Kein Mikrofon-Zugriff erlaubt.')),
          );
          return;
        }
        await TranscriptionService.start();
        if (mounted) setState(() => _recording = true);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Aufnahme fehlgeschlagen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Die Prüfung sitzt hier und nicht an jeder Aufrufstelle: der Knopf weiß
    // selbst, dass er `/transcribe` braucht, und `/transcribe` verlangt
    // `ai:use`. Ohne das Recht führte jeder Druck in ein 403. Ausblenden ist
    // Höflichkeit, keine Absicherung — geprüft wird im Backend.
    if (!context.watch<PermissionProvider>().darfKi) {
      return const SizedBox.shrink();
    }
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      onPressed: _toggle,
      icon: Icon(_recording ? Icons.stop : Icons.mic_none),
      color: _recording ? Colors.red : null,
      tooltip: _recording ? 'Aufnahme stoppen' : 'Sprechen',
    );
  }
}
