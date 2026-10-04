import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/theme/app_accents.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/form_sheet.dart';

/// Shows the "Update available" bottom sheet for [info].
Future<void> showUpdateSheet(BuildContext context, UpdateInfo info) {
  return showFormSheet<void>(
    context,
    (context) => _UpdateSheet(info: info),
  );
}

enum _Phase { idle, downloading, installing }

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.info});

  final UpdateInfo info;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;
  String? _currentVersion;

  @override
  void initState() {
    super.initState();
    installedVersion().then((v) {
      if (mounted) setState(() => _currentVersion = v);
    });
  }

  Future<void> _download() async {
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });
    Haptics.medium();
    try {
      await downloadAndInstall(
        widget.info.apkUrl,
        onProgress: (p) {
          if (mounted && p >= 0) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.installing);
      // The OS installer takes over from here.
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: ${_friendlyError(e)}')),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    // Strip the "Exception: "/"StateError: " prefixes for display.
    return msg.replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final downloading = _phase == _Phase.downloading;
    return FormSheet(
      title: 'Update available',
      actionLabel: switch (_phase) {
        _Phase.idle => 'Download update',
        _Phase.downloading =>
          'Downloading… ${(_progress * 100).toStringAsFixed(0)}%',
        _Phase.installing => 'Opening installer…',
      },
      onAction: _phase == _Phase.idle ? _download : null,
      busy: _phase == _Phase.installing,
      children: [
        Row(
          children: [
            _versionChip(context, _currentVersion ?? '…', false),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward,
                  size: 18, color: context.textMuted),
            ),
            _versionChip(context, info.version, true),
          ],
        ),
        const SizedBox(height: 16),
        const FormSectionLabel("What's new"),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.raised,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              info.releaseNotes.isEmpty
                  ? 'No release notes.'
                  : info.releaseNotes,
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
        ),
        if (downloading) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
              backgroundColor: context.hairline,
              valueColor:
                  AlwaysStoppedAnimation<Color>(context.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Downloading the update — keep the app open.',
            style:
                TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _versionChip(BuildContext context, String version, bool isNew) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isNew
            ? context.accent.withValues(alpha: 0.14)
            : context.raised,
        borderRadius: BorderRadius.circular(12),
        border: isNew
            ? Border.all(
                color: context.accent.withValues(alpha: 0.4))
            : null,
      ),
      child: Text(
        version,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: isNew ? context.accent : context.textPrimary,
        ),
      ),
    );
  }
}
