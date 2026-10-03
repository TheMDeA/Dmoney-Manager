import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_icons.dart';

/// Full-screen icon picker: grouped grids with a DONE action.
/// Returns the selected icon key, or null if cancelled.
class PickIconScreen extends StatefulWidget {
  const PickIconScreen({super.key, required this.initialKey});

  final String initialKey;

  @override
  State<PickIconScreen> createState() => _PickIconScreenState();
}

class _PickIconScreenState extends State<PickIconScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialKey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Icon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('DONE'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in iconPickerSections) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  section.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 12,
                ),
                itemCount: section.entries.length,
                itemBuilder: (context, i) {
                  final entry = section.entries[i];
                  final selected = entry.key == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = entry.key),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? AppColors.brandBlue
                            : AppColors.bgRaised,
                      ),
                      child: Icon(
                        entry.icon,
                        size: 28,
                        color: selected
                            ? Colors.white
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.75),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
