import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dmoney_manager/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync_photos.dart';
import '../../core/services/sync_remote.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
            if (photos.isEmpty) return Text(l10n.txPhotos);
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
                tooltip: l10n.txDeletePhoto,
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  Haptics.select();
                  _confirmDelete(context, db, photos[i]);
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionPhoto>>(
        stream: db.watchPhotos(widget.transactionId),
        builder: (context, snap) {
          if (!snap.hasData) {
            // Stream hasn't emitted yet — don't confuse "loading"
            // with "empty", or the viewer would pop itself on open.
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          final photos = snap.data!;
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
                child: _PhotoImage(photo: photos[i], db: db),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.txDeletePhotoTitle),
        content: Text(l10n.txDeletePhotoBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Haptics.medium();
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await db.deletePhoto(photo.id);
    }
  }
}

/// One page of the viewer. A photo whose bytes are on this device
/// shows immediately; a synced photo whose file is missing (lazy
/// download, §9) fetches its bytes from Storage on first view and
/// caches them at its local path, then shows the image. A photo
/// with no remote key and no local file stays "unavailable" —
/// exactly the pre-sync behaviour. The download is never
/// Wi-Fi-gated: opening a photo is an explicit request for it.
class _PhotoImage extends StatefulWidget {
  const _PhotoImage({required this.photo, required this.db});

  final TransactionPhoto photo;
  final AppDatabase db;

  @override
  State<_PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<_PhotoImage> {
  late final Future<bool> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _load();
  }

  Future<bool> _load() async {
    if (await File(widget.photo.path).exists()) return true;
    // No local file: only a synced photo can be fetched.
    // ensureLocalFile never throws, but constructing the real
    // remote needs an initialised Supabase client — anything
    // failing here just leaves the photo unavailable.
    if (widget.photo.remoteKey == null) return false;
    try {
      final service = SyncPhotoService(
        db: widget.db,
        remote: SupabaseSyncRemote(),
      );
      return await service.ensureLocalFile(widget.photo);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data == true) {
          return Image.file(
            File(widget.photo.path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _unavailable(context),
          );
        }
        return _unavailable(context);
      },
    );
  }
}

Widget _unavailable(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.broken_image_outlined,
        color: context.textMuted,
        size: 64,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.txPhotoUnavailable,
        style: TextStyle(color: context.textMuted),
      ),
    ],
  );
}
