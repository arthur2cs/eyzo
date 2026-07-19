import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/storage/favorites_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../widgets/pixel_frame_painter.dart';
import '../editor/editor_screen.dart';
import '../text/text_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _resend(BuildContext context, WidgetRef ref, FavoriteItem item) async {
    final connected = ref.read(connectionStateProvider).value == BleConnectionState.connected;
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lunettes non connectées.')));
      return;
    }
    final service = ref.read(bleServiceProvider);
    try {
      if (item.type == FavoriteType.text && item.textContent != null) {
        await service.sendText(item.targetScreen, item.textContent!);
      } else if (item.type == FavoriteType.animation && item.animation != null) {
        final anim = item.animation!;
        if (anim.frames.length > 1) {
          await service.sendAnimation(item.targetScreen, anim);
        } else {
          await service.sendStaticImage(item.targetScreen, anim.frames.first);
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renvoyé aux lunettes.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l\'envoi : $e')));
      }
    }
  }

  void _edit(BuildContext context, FavoriteItem item) {
    if (item.type == FavoriteType.text && item.textContent != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TextScreen(initial: item.textContent)),
      );
    } else if (item.type == FavoriteType.animation && item.animation != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorScreen(initialAnimation: item.animation, initialTarget: item.targetScreen),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    if (favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Aucun favori pour l\'instant.\nEnregistrez un texte ou une animation depuis leur écran d\'envoi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = favorites[index];
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 40,
              height: 40,
              child: item.type == FavoriteType.animation && item.animation != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CustomPaint(painter: PixelFramePainter(item.animation!.frames.first)),
                    )
                  : const Icon(Icons.text_fields),
            ),
            title: Text(item.name),
            subtitle: Text(
              '${item.targetScreen.label} • ${DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _resend(context, ref, item),
                  icon: const Icon(Icons.send),
                  tooltip: 'Renvoyer',
                ),
                IconButton(
                  onPressed: () => _edit(context, item),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Éditer',
                ),
                IconButton(
                  onPressed: () => ref.read(favoritesProvider.notifier).remove(item.id),
                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
