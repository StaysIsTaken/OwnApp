import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:productivity/provider/user_provider.dart';
import 'package:productivity/provider/chat_provider.dart';
import 'package:productivity/tabs/assistant/assistant_page.dart';

/// Legt über die gesamte App einen Floating-Button, der den Assistenten in
/// einem schwebenden Chat-Fenster öffnet — auf jeder Seite verfügbar.
///
/// Die schwebenden Elemente liegen in einem EIGENEN [Overlay], damit Tooltips,
/// Textfeld-Auswahl etc. einen Overlay-Vorfahren haben (MaterialApp.builder
/// liegt sonst außerhalb des Navigator-Overlays).
class GlobalAssistantOverlay extends StatelessWidget {
  final Widget child;
  const GlobalAssistantOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Overlay(
          initialEntries: [
            OverlayEntry(builder: (context) => const _AssistantFloating()),
          ],
        ),
      ],
    );
  }
}

class _AssistantFloating extends StatefulWidget {
  const _AssistantFloating();

  @override
  State<_AssistantFloating> createState() => _AssistantFloatingState();
}

class _AssistantFloatingState extends State<_AssistantFloating> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<UserProvider>().isLoggedIn;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        if (loggedIn && !_open)
          Positioned(
            right: 16,
            bottom: 88, // über einem evtl. vorhandenen Seiten-FAB
            child: FloatingActionButton(
              heroTag: 'global_assistant_fab',
              tooltip: 'Assistent',
              onPressed: () => setState(() => _open = true),
              child: const Icon(Icons.smart_toy_outlined),
            ),
          ),
        if (_open) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _open = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: SizedBox(
                width: min(420.0, size.width - 24),
                height: min(620.0, size.height * 0.85),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('Assistent'),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.add_comment_outlined),
                          tooltip: 'Neuer Chat',
                          onPressed: () =>
                              context.read<ChatProvider>().clear(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _open = false),
                        ),
                      ],
                    ),
                    body: const AssistantChatView(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
