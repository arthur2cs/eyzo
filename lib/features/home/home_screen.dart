import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/connection_status_badge.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.text_fields,
                  label: 'Texte défilant',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TextScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _ModeCard(
                  icon: Icons.photo_library_outlined,
                  label: 'Import image / GIF',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ImportImageScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _ModeCard(
                  icon: Icons.brush_outlined,
                  label: 'Éditeur pixel-art',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditorScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 26, color: AppColors.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
