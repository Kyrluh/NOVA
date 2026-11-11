import 'package:flutter/material.dart';

import '../../state/source_controller.dart';

/// A lightweight surface: no catalogue grids or posters are built at startup.
class SourceLoadingPage extends StatelessWidget {
  const SourceLoadingPage({
    super.key,
    this.controller,
    this.initializing = false,
  });
  final SourceController? controller;
  final bool initializing;

  @override
  Widget build(BuildContext context) {
    final source = controller;
    final startup = source?.startupRefreshing == true;
    final progress = initializing
        ? null
        : startup
        ? source!.startupProgress
        : source?.catalogLoadProgress;
    final phase = initializing
        ? 'Ouverture de votre bibliothèque…'
        : startup
        ? source!.startupPhase
        : source?.catalogLoadPhase ?? 'Connexion à la source';
    final name = startup ? source!.startupSourceName : source?.catalogLoadName;
    return Scaffold(
      key: const ValueKey('source-loading-screen'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'NOVA IPTV',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Chargement de vos sources',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  if (name != null)
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    phase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 22),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  if (progress != null) Text('${(progress * 100).floor()} %'),
                  const SizedBox(height: 16),
                  const Text(
                    'Votre bibliothèque sera affichée à la fin du chargement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
