import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/entry.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/snackbar.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../settings/presentation/settings_provider.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.entryId, super.key});

  final int entryId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  static const _readerFontFamily = 'Microsoft YaHei UI';
  static const _readerFontFallback = [
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Source Han Sans SC',
    'Segoe UI',
    'Roboto',
  ];

  final _scrollController = ScrollController();
  final _highlights = <String>[];
  bool _initialPositionApplied = false;
  String? _selectedText;
  bool _fetchingFullText = false;

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

  void _handleSelectionChanged(SelectedContent? content) {
    final selected = content?.plainText.trim();
    _selectedText = selected == null || selected.isEmpty ? null : selected;
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final selectedText = _selectedText;
    final buttonItems = <ContextMenuButtonItem>[
      if (selectedText != null && selectedText.isNotEmpty)
        ContextMenuButtonItem(
          label: context.t.markSelection,
          onPressed: () {
            _markSelection(selectedText);
            selectableRegionState.clearSelection();
            ContextMenuController.removeAny();
            showMessage(context, context.t.selectionMarked);
          },
        ),
      ...selectableRegionState.contextMenuButtonItems,
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  void _markSelection(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return;
    setState(() {
      if (!_highlights.contains(normalized)) {
        _highlights.insert(0, normalized);
      }
    });
  }

  String _applyHighlights(String html) {
    if (_highlights.isEmpty) return html;
    final fragment = html_parser.parseFragment(html);
    for (final highlight in _highlights) {
      _highlightNode(fragment, highlight);
    }
    return fragment.nodes.map(_serializeNode).join();
  }

  String _serializeNode(dom.Node node) {
    if (node is dom.Element) return node.outerHtml;
    if (node is dom.Text) return node.data;
    return node.text ?? '';
  }

  void _highlightNode(dom.Node node, String highlight) {
    if (node is dom.Element && node.localName == 'mark') return;
    for (final child in List<dom.Node>.from(node.nodes)) {
      if (child is dom.Text) {
        _highlightTextNode(child, highlight);
      } else {
        _highlightNode(child, highlight);
      }
    }
  }

  void _highlightTextNode(dom.Text node, String highlight) {
    final text = node.data;
    if (highlight.isEmpty || !text.contains(highlight)) return;

    final parent = node.parentNode;
    if (parent == null) return;

    var start = 0;
    while (true) {
      final index = text.indexOf(highlight, start);
      if (index < 0) {
        final tail = text.substring(start);
        if (tail.isNotEmpty) parent.insertBefore(dom.Text(tail), node);
        break;
      }

      final before = text.substring(start, index);
      if (before.isNotEmpty) parent.insertBefore(dom.Text(before), node);

      final mark = dom.Element.tag('mark')
        ..text = text.substring(index, index + highlight.length);
      parent.insertBefore(mark, node);
      start = index + highlight.length;
    }

    node.remove();
  }

  Future<void> _copyText(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      showMessage(context, context.t.selectionCopied);
    }
  }

  Future<void> _openArticleLink(BuildContext context, String? url) async {
    final normalized = url?.trim();
    if (normalized == null || normalized.isEmpty) return;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showMessage(context, context.t.fullTextFailed);
    }
  }

  Future<void> _fetchFullText(
      BuildContext context, WidgetRef ref, Entry item) async {
    if (_fetchingFullText) return;
    setState(() => _fetchingFullText = true);
    try {
      await ref.read(feedRepositoryProvider).fetchFullTextForEntry(
            entryId: item.id,
            url: item.link,
            mode: item.feedFullTextMode,
            selector: item.feedFullTextSelector,
            excludeSelector: item.feedFullTextExcludeSelector,
          );
      ref.invalidate(entryProvider(item.id));
      ref.invalidate(entriesProvider);
      if (context.mounted) showMessage(context, context.t.fullTextFetched);
    } catch (error) {
      if (context.mounted) {
        showMessage(context, '${context.t.fullTextFailed}: $error');
      }
    } finally {
      if (mounted) setState(() => _fetchingFullText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = ref.watch(entryProvider(widget.entryId));
    final settings = ref.watch(settingsControllerProvider);
    final fontSize = settings.fontSize;
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
        final highlightedHtml = _applyHighlights(html);

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
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'full_text') {
                    await _fetchFullText(context, ref, item);
                    return;
                  }
                  if (value == 'later') {
                    await ref
                        .read(entryRepositoryProvider)
                        .setLater(item.id, !item.isLater);
                    ref.invalidate(entryProvider(item.id));
                    ref.invalidate(entriesProvider);
                    ref.invalidate(laterEntriesProvider);
                    return;
                  }
                  if (value == 'read') {
                    await ref
                        .read(entryRepositoryProvider)
                        .markRead(item.id, !item.isRead);
                    ref.invalidate(entryProvider(item.id));
                    ref.invalidate(entriesProvider);
                    return;
                  }
                  if (value == 'copy') {
                    await Clipboard.setData(ClipboardData(text: item.link));
                    if (context.mounted) {
                      showMessage(context, context.t.linkCopied);
                    }
                    return;
                  }
                  if (value == 'open') {
                    await _openArticleLink(context, item.link);
                  }
                },
                itemBuilder: (context) => [
                  if (item.mayNeedFullText && item.feedFullTextMode != 'off')
                    PopupMenuItem(
                        value: 'full_text', child: Text(context.t.getFullText)),
                  PopupMenuItem(
                    value: 'later',
                    child: Text(item.isLater
                        ? context.t.removeLater
                        : context.t.readLater),
                  ),
                  PopupMenuItem(
                    value: 'read',
                    child: Text(item.isRead
                        ? context.t.markUnread
                        : context.t.markRead),
                  ),
                  PopupMenuItem(value: 'copy', child: Text(context.t.copyLink)),
                  PopupMenuItem(
                      value: 'open', child: Text(context.t.openInBrowser)),
                ],
              ),
            ],
          ),
          body: SelectionArea(
            onSelectionChanged: _handleSelectionChanged,
            contextMenuBuilder: _buildSelectionToolbar,
            child: Scrollbar(
              controller: _scrollController,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth >= 900 ? 32.0 : 20.0;
                  return ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      36,
                    ),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: settings.readerWidth.toDouble()),
                          child: DefaultTextStyle.merge(
                            style: TextStyle(
                              fontFamily: _readerFontFamily,
                              fontFamilyFallback: _readerFontFallback,
                              height: 1.62,
                              letterSpacing: 0,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontFamily: _readerFontFamily,
                                        fontFamilyFallback: _readerFontFallback,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                        letterSpacing: 0,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${item.sourceName} | ${formatDateTime(item.publishedAt ?? item.fetchedAt)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontFamily: _readerFontFamily,
                                        fontFamilyFallback: _readerFontFallback,
                                        height: 1.4,
                                      ),
                                ),
                                if (_highlights.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _HighlightPanel(
                                    highlights: _highlights,
                                    onCopy: (text) => _copyText(context, text),
                                    title: t.articleHighlights,
                                  ),
                                ],
                                if (item.aiSummary?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: 16),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Text(
                                        item.aiSummary!,
                                        style: TextStyle(
                                          fontFamily: _readerFontFamily,
                                          fontFamilyFallback:
                                              _readerFontFallback,
                                          height: 1.58,
                                          letterSpacing: 0,
                                        ),
                                      ),
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
                                if (item.mayNeedFullText &&
                                    item.feedFullTextMode != 'off') ...[
                                  const SizedBox(height: 16),
                                  _FullTextPrompt(
                                    text: t.incompleteContentHint,
                                    buttonText: _fetchingFullText
                                        ? t.gettingFullText
                                        : t.getFullText,
                                    busy: _fetchingFullText,
                                    onPressed: () =>
                                        _fetchFullText(context, ref, item),
                                  ),
                                ],
                                if (item.imageUrl != null) ...[
                                  const SizedBox(height: 18),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(item.imageUrl!,
                                        fit: BoxFit.cover),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Html(
                                  data: highlightedHtml,
                                  onLinkTap: (url, _, __) =>
                                      _openArticleLink(context, url),
                                  style: {
                                    'body': Style(
                                      fontFamily: _readerFontFamily,
                                      fontFamilyFallback: _readerFontFallback,
                                      fontSize: FontSize(fontSize),
                                      lineHeight:
                                          LineHeight(settings.readerLineHeight),
                                      letterSpacing: 0,
                                      margin: Margins.zero,
                                      padding: HtmlPaddings.zero,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    'p': Style(
                                      margin: Margins.only(bottom: 16),
                                      textAlign: TextAlign.start,
                                    ),
                                    'li': Style(
                                      margin: Margins.only(bottom: 8),
                                      lineHeight: const LineHeight(1.62),
                                    ),
                                    'h1': Style(
                                      fontFamily: _readerFontFamily,
                                      fontFamilyFallback: _readerFontFallback,
                                      lineHeight: const LineHeight(1.28),
                                      margin: Margins.only(top: 10, bottom: 12),
                                    ),
                                    'h2': Style(
                                      fontFamily: _readerFontFamily,
                                      fontFamilyFallback: _readerFontFallback,
                                      lineHeight: const LineHeight(1.32),
                                      margin: Margins.only(top: 10, bottom: 10),
                                    ),
                                    'h3': Style(
                                      fontFamily: _readerFontFamily,
                                      fontFamilyFallback: _readerFontFallback,
                                      lineHeight: const LineHeight(1.36),
                                      margin: Margins.only(top: 8, bottom: 8),
                                    ),
                                    'blockquote': Style(
                                      padding: HtmlPaddings.only(left: 14),
                                      margin: Margins.symmetric(vertical: 12),
                                      lineHeight: const LineHeight(1.62),
                                    ),
                                    'mark': Style(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer,
                                    ),
                                    'img': Style(
                                      margin: Margins.symmetric(vertical: 10),
                                    ),
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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

class _HighlightPanel extends StatelessWidget {
  const _HighlightPanel({
    required this.highlights,
    required this.onCopy,
    required this.title,
  });

  final List<String> highlights;
  final ValueChanged<String> onCopy;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_border, size: 18),
                const SizedBox(width: 6),
                Text(title, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            ...highlights.map(
              (highlight) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onCopy(highlight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      highlight,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.48,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullTextPrompt extends StatelessWidget {
  const _FullTextPrompt({
    required this.text,
    required this.buttonText,
    required this.busy,
    required this.onPressed,
  });

  final String text;
  final String buttonText;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.article_outlined,
                size: 20, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_for_offline_outlined),
              label: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
