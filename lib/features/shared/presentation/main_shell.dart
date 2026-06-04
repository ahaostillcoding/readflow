import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_refresh_service.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../entries/presentation/content_flow_page.dart';
import '../../entries/presentation/recommended_page.dart';
import '../../entries/presentation/saved_page.dart';
import '../../entries/presentation/search_page.dart';
import '../../feeds/presentation/feed_list_page.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../movie/presentation/movie_page.dart';
import '../../novel/presentation/novel_page.dart';
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

  late final _pages = [
    ContentFlowPage(),
    FeedListPage(),
    SavedPage(),
    SearchPage(),
    RecommendedPage(),
    NovelPage(),
    MoviePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedsControllerProvider.notifier).refreshAll();
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
    final destinations = [
      NavigationDestination(
          icon: const Icon(Icons.dynamic_feed_outlined),
          selectedIcon: const Icon(Icons.dynamic_feed),
          label: t.home),
      NavigationDestination(
          icon: const Icon(Icons.rss_feed_outlined),
          selectedIcon: const Icon(Icons.rss_feed),
          label: t.feeds),
      NavigationDestination(
          icon: const Icon(Icons.star_border),
          selectedIcon: const Icon(Icons.star),
          label: t.saved),
      NavigationDestination(
          icon: const Icon(Icons.search),
          selectedIcon: const Icon(Icons.search),
          label: t.search),
      NavigationDestination(
          icon: const Icon(Icons.auto_awesome_outlined),
          selectedIcon: const Icon(Icons.auto_awesome),
          label: t.forYou),
      NavigationDestination(
          icon: const Icon(Icons.menu_book_outlined),
          selectedIcon: const Icon(Icons.menu_book),
          label: t.novels),
      NavigationDestination(
          icon: const Icon(Icons.movie_outlined),
          selectedIcon: const Icon(Icons.movie),
          label: t.movies),
      NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: t.settings),
    ];

    ref.listen(
        settingsControllerProvider.select((value) => value.refreshMinutes),
        (_, __) {
      _scheduleRefresh();
    });

    final wide = MediaQuery.sizeOf(context).width >= 980;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map((item) => NavigationRailDestination(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: Text(item.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _pages[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }
}
