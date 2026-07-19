import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/connection_status_badge.dart';
import '../animations/animations_screen.dart';
import '../connection/connection_screen.dart';
import '../editor/editor_screen.dart';
import '../import_image/import_image_screen.dart';
import '../text/text_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eyzo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ConnectionStatusBadge(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnectionScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _ModeCard(
              icon: Icons.text_fields,
              label: 'Texte défilant',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TextScreen())),
            ),
            _ModeCard(
              icon: Icons.animation,
              label: 'Animations',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnimationsScreen())),
            ),
            _ModeCard(
              icon: Icons.photo_library_outlined,
              label: 'Import image / GIF',
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ImportImageScreen())),
            ),
            _ModeCard(
              icon: Icons.brush_outlined,
              label: 'Éditeur pixel-art',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppColors.textPrimary),
            const SizedBox(height: 12),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
