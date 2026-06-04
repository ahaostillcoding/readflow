import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/snackbar.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../settings/presentation/settings_provider.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final _scrollController = ScrollController();
  bool _initialPositionApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(entryRepositoryProvider).markRead(widget.entryId, true);
      ref.invalidate(entriesProvider);
      ref.invalidate(entryProvider(widget.entryId));
    });
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress() async {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final progress = max <= 0
        ? 1.0
        : (_scrollController.offset / max).clamp(0, 1).toDouble();
    await ref
        .read(entryRepositoryProvider)
        .setReadingProgress(widget.entryId, progress);
  }

  void _restoreProgress(double progress) {
    if (_initialPositionApplied || progress <= 0 || progress >= 1) return;
    _initialPositionApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo((max * progress).clamp(0, max));
    });
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(entryProvider(widget.entryId));
    final fontSize = ref.watch(settingsControllerProvider).fontSize;
    final t = context.t;

    return entry.when(
      data: (item) {
        if (item == null) {
          return Scaffold(body: Center(child: Text(t.contentNotFound)));
        }

        _restoreProgress(item.readingProgress);
        final html = (item.contentHtml?.isNotEmpty ?? false)
            ? item.contentHtml!
            : '<p>${item.summary ?? ''}</p>';

        return Scaffold(
          appBar: AppBar(
            title: Text(item.sourceName),
            actions: [
              IconButton(
                tooltip: item.isFavorite ? t.removeFavorite : t.favorite,
                icon: Icon(item.isFavorite ? Icons.star : Icons.star_border),
                onPressed: () async {
                  await ref
                      .read(entryRepositoryProvider)
                      .setFavorite(item.id, !item.isFavorite);
                  ref.invalidate(entryProvider(item.id));
                  ref.invalidate(entriesProvider);
                  ref.invalidate(favoriteEntriesProvider);
                },
              ),
              IconButton(
                tooltip: item.isLater ? t.removeLater : t.readLater,
                icon: Icon(
                    item.isLater ? Icons.schedule : Icons.schedule_outlined),
                onPressed: () async {
                  await ref
                      .read(entryRepositoryProvider)
                      .setLater(item.id, !item.isLater);
                  ref.invalidate(entryProvider(item.id));
                  ref.invalidate(entriesProvider);
                  ref.invalidate(laterEntriesProvider);
                },
              ),
              IconButton(
                tooltip: item.isRead ? t.markUnread : t.markRead,
                icon: Icon(item.isRead
                    ? Icons.mark_email_read
                    : Icons.mark_email_unread_outlined),
                onPressed: () async {
                  await ref
                      .read(entryRepositoryProvider)
                      .markRead(item.id, !item.isRead);
                  ref.invalidate(entryProvider(item.id));
                  ref.invalidate(entriesProvider);
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'copy') {
                    await Clipboard.setData(ClipboardData(text: item.link));
                    if (context.mounted) {
                      showMessage(context, context.t.linkCopied);
                    }
                  }
                  if (value == 'open') {
                    final uri = Uri.tryParse(item.link);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'copy', child: Text(context.t.copyLink)),
                  PopupMenuItem(
                      value: 'open', child: Text(context.t.openInBrowser)),
                ],
              ),
            ],
          ),
          body: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text(item.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  '${item.sourceName} | ${formatDateTime(item.publishedAt ?? item.fetchedAt)}'),
              if (item.aiSummary?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(item.aiSummary!),
                  ),
                ),
              ],
              if (item.tagList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.tagList
                      .map((tag) => Chip(label: Text(tag)))
                      .toList(),
                ),
              ],
              if (item.imageUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(item.imageUrl!, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 12),
              Html(
                data: html,
                style: {
                  'body': Style(
                    fontSize: FontSize(fontSize),
                    lineHeight: const LineHeight(1.55),
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  'p': Style(margin: Margins.only(bottom: 12)),
                  'img': Style(margin: Margins.symmetric(vertical: 8)),
                },
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text(t.readerFailed(error)))),
    );
  }
}
