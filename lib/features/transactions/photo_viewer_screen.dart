import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/database/app_database.dart';
import '../../state/providers.dart';

/// Full-screen receipt photo viewer: swipe between photos, pinch to zoom,
/// delete the current photo.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.transactionId,
    required this.initialIndex,
  });

  final int transactionId;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: StreamBuilder<List<TransactionPhoto>>(
          stream: db.watchPhotos(widget.transactionId),
          builder: (context, snap) {
            final photos = snap.data ?? const <TransactionPhoto>[];
            if (photos.isEmpty) return const Text('Photos');
            final i = _index.clamp(0, photos.length - 1);
            return Text('${i + 1} / ${photos.length}');
          },
        ),
        actions: [
          StreamBuilder<List<TransactionPhoto>>(
            stream: db.watchPhotos(widget.transactionId),
            builder: (context, snap) {
              final photos = snap.data ?? const <TransactionPhoto>[];
              if (photos.isEmpty) return const SizedBox.shrink();
              final i = _index.clamp(0, photos.length - 1);
              return IconButton(
                tooltip: 'Delete photo',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, db, photos[i]),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionPhoto>>(
        stream: db.watchPhotos(widget.transactionId),
        builder: (context, snap) {
          final photos = snap.data ?? const <TransactionPhoto>[];
          if (photos.isEmpty) {
            // All photos deleted — close the viewer on the next frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
            return const SizedBox.shrink();
          }
          if (_index >= photos.length) {
            _index = photos.length - 1;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController.hasClients) {
                _pageController.jumpToPage(_index);
              }
            });
          }
          return PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(photos[i].path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: AppColors.textMuted, size: 64),
                      SizedBox(height: 12),
                      Text(
                        'This photo is no longer available',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppDatabase db,
    TransactionPhoto photo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
          'This removes the attached copy from the record. '
          'Your original photo in the gallery is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deletePhoto(photo.id);
    }
  }
}
