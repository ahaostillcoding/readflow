import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_refresh_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/sidebar_item_preference.dart';
import '../../entries/presentation/content_flow_page.dart';
import '../../entries/presentation/recommended_page.dart';
import '../../entries/presentation/saved_page.dart';
import '../../entries/presentation/search_page.dart';
import '../../feeds/presentation/feed_list_page.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../movie/presentation/movie_page.dart';
import '../../novel/presentation/novel_page.dart';
import '../../sidebar/presentation/sidebar_providers.dart';
import '../../settings/presentation/settings_page.dart';
import '../../settings/presentation/settings_provider.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(settingsControllerProvider).refreshOnStart) {
        ref.read(feedsControllerProvider.notifier).refreshAll();
      }
      _scheduleRefresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    final minutes = ref.read(settingsControllerProvider).refreshMinutes;
    BackgroundRefreshService.schedule(minutes);
    _timer = Timer.periodic(Duration(minutes: minutes), (_) {
      ref.read(feedsControllerProvider.notifier).refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sidebarItems = ref.watch(visibleSidebarItemsProvider);

    ref.listen(
        settingsControllerProvider.select((value) => value.refreshMinutes),
        (_, __) {
      _scheduleRefresh();
    });

    return sidebarItems.when(
      data: (items) => _buildShell(context, t, _ensureItems(items)),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => _buildShell(context, t, _ensureItems(const [])),
    );
  }

  Widget _buildShell(
    BuildContext context,
    AppStrings t,
    List<SidebarItemPreference> items,
  ) {
    if (_index >= items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }
    final selectedIndex = _index.clamp(0, items.length - 1);
    final destinations = items.map((item) => _destination(t, item)).toList();
    final page = _pageForItem(t, items[selectedIndex]);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 80,
              child: _SidebarList(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelected: (value) => setState(() => _index = value),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }

  List<SidebarItemPreference> _ensureItems(List<SidebarItemPreference> items) {
    final visible = items.where((item) => item.visible).toList();
    if (visible.isNotEmpty) return visible;
    return const [
      SidebarItemPreference(
        type: SidebarItemType.page,
        key: 'settings',
        visible: true,
        sortOrder: 0,
      ),
    ];
  }

  NavigationDestination _destination(AppStrings t, SidebarItemPreference item) {
    return NavigationDestination(
      icon: Icon(_icon(item, selected: false)),
      selectedIcon: Icon(_icon(item, selected: true)),
      label: _label(t, item),
    );
  }

  Widget _pageForItem(AppStrings t, SidebarItemPreference item) {
    if (item.type == SidebarItemType.category) {
      return ContentFlowPage(
        fixedCategory: item.key,
        title: t.categoryLabel(item.key),
      );
    }
    return switch (item.key) {
      'home' => const ContentFlowPage(),
      'feeds' => const FeedListPage(),
      'saved' => const SavedPage(),
      'search' => const SearchPage(),
      'recommended' => const RecommendedPage(),
      'novels' => const NovelPage(),
      'movies' => const MoviePage(),
      'settings' => SettingsPage(),
      _ => const ContentFlowPage(),
    };
  }

  String _label(AppStrings t, SidebarItemPreference item) {
    if (item.type == SidebarItemType.category) return t.categoryLabel(item.key);
    return switch (item.key) {
      'home' => t.home,
      'feeds' => t.feeds,
      'saved' => t.saved,
      'search' => t.search,
      'recommended' => t.forYou,
      'novels' => t.novels,
      'movies' => t.movies,
      'settings' => t.settings,
      _ => item.key,
    };
  }

  IconData _icon(SidebarItemPreference item, {required bool selected}) {
    if (item.type == SidebarItemType.category) {
      return selected ? Icons.folder : Icons.folder_outlined;
    }
    return switch (item.key) {
      'home' => selected ? Icons.dynamic_feed : Icons.dynamic_feed_outlined,
      'feeds' => selected ? Icons.rss_feed : Icons.rss_feed_outlined,
      'saved' => selected ? Icons.star : Icons.star_border,
      'search' => Icons.search,
      'recommended' =>
        selected ? Icons.auto_awesome : Icons.auto_awesome_outlined,
      'novels' => selected ? Icons.menu_book : Icons.menu_book_outlined,
      'movies' => selected ? Icons.movie : Icons.movie_outlined,
      'settings' => selected ? Icons.settings : Icons.settings_outlined,
      _ => Icons.circle_outlined,
    };
  }
}

class _SidebarList extends StatelessWidget {
  const _SidebarList({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          itemCount: destinations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final destination = destinations[index];
            final selected = index == selectedIndex;
            return Tooltip(
              message: destination.label,
              waitDuration: const Duration(milliseconds: 500),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 58,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.secondaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          size: 22,
                          color: selected
                              ? colorScheme.onSecondaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                        child: selected
                            ? destination.selectedIcon ?? destination.icon
                            : destination.icon,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
