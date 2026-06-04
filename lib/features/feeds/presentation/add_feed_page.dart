import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      showMessage(context, 'Enter an RSS or Atom URL.');
      return;
    }
    setState(() => _loading = true);
    try {
      final parsed = await ref.read(feedsControllerProvider.notifier).preview(url, _category);
      _titleController.text = parsed.title;
      setState(() => _preview = parsed);
    } catch (error) {
      if (mounted) showMessage(context, 'Feed detection failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showMessage(context, 'Enter an RSS or Atom URL.');
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
      showMessage(context, 'Feed added');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showMessage(context, 'Save failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryNamesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add feed')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'RSS / Atom URL',
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          categories.when(
            data: (items) => DropdownButtonFormField<String>(
              initialValue: items.contains(_category) ? _category : 'Other',
              decoration: const InputDecoration(labelText: 'Category'),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: (value) => setState(() => _category = value ?? 'Other'),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Text('Failed to load categories: $error'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.drive_file_rename_outline),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _previewFeed,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Detect'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _save,
                  icon: const Icon(Icons.add),
                  label: const Text('Save'),
                ),
              ),
            ],
          ),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
          if (_preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_preview!.title, style: Theme.of(context).textTheme.titleMedium),
                    if (_preview!.description != null) ...[
                      const SizedBox(height: 8),
                      Text(_preview!.description!),
                    ],
                    const SizedBox(height: 8),
                    Text('Detected ${_preview!.entries.length} item(s)'),
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
