import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/category_providers.dart';
import '../data/parsed_feed.dart';
import 'feed_providers.dart';

class AddFeedPage extends ConsumerStatefulWidget {
  const AddFeedPage({super.key});

  @override
  ConsumerState<AddFeedPage> createState() => _AddFeedPageState();
}

class _AddFeedPageState extends ConsumerState<AddFeedPage> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String _category = 'Other';
  ParsedFeed? _preview;
  bool _loading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _previewFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showMessage(context, context.t.enterFeedUrl);
      return;
    }
    setState(() => _loading = true);
    try {
      final parsed = await ref
          .read(feedsControllerProvider.notifier)
          .preview(url, _category);
      _titleController.text = parsed.title;
      setState(() => _preview = parsed);
    } catch (error) {
      if (mounted) showMessage(context, context.t.feedDetectionFailed(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showMessage(context, context.t.enterFeedUrl);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(feedsControllerProvider.notifier).addFeed(
            url,
            _category,
            title: _titleController.text,
          );
      if (!mounted) return;
      showMessage(context, context.t.feedAdded);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, context.t.saveFailed(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryNamesProvider);
    final t = context.t;

    return Scaffold(
      appBar: AppBar(title: Text(t.addFeed)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: t.rssAtomUrl,
              prefixIcon: const Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          categories.when(
            data: (items) => DropdownButtonFormField<String>(
              initialValue: items.contains(_category) ? _category : 'Other',
              decoration: InputDecoration(labelText: t.category),
              items: items
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(t.categoryLabel(item))))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _category = value ?? 'Other'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text(t.failedToLoadCategories(error)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: t.displayName,
              prefixIcon: const Icon(Icons.drive_file_rename_outline),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _previewFeed,
                  icon: const Icon(Icons.travel_explore),
                  label: Text(t.detect),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: const Icon(Icons.add),
                  label: Text(t.save),
                ),
              ),
            ],
          ),
          if (_loading)
            const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator()),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_preview!.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_preview!.description != null) ...[
                      const SizedBox(height: 8),
                      Text(_preview!.description!),
                    ],
                    const SizedBox(height: 8),
                    Text(t.detectedItems(_preview!.entries.length)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
