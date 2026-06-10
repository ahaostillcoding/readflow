import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/content_type.dart';

enum LanguageMode {
  system,
  zh,
  en;

  Locale? get locale {
    return switch (this) {
      LanguageMode.system => null,
      LanguageMode.zh => const Locale('zh'),
      LanguageMode.en => const Locale('en'),
    };
  }
}

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('zh')];
  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  bool get isZh => locale.languageCode.toLowerCase().startsWith('zh');

  String text(String zh, String en) => isZh ? zh : en;

  String get checkConnection => text('检查连接', 'Check connection');
  String get backendConnected => text('后端连接正常', 'Backend connected');
  String get backendNotChecked =>
      text('尚未检查后端连接', 'Backend connection not checked');
  String get backendStartHint => text(
        '请先在 backend 目录启动服务：.venv\\Scripts\\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000',
        r'Start the API in backend: .venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000',
      );
  String backendUnavailable(String baseUrl, int? statusCode) {
    final suffix = statusCode == null
        ? ''
        : text('，状态码 $statusCode', ', status $statusCode');
    return text(
      '后端未连接：$baseUrl$suffix。$backendStartHint',
      'Backend is not reachable: $baseUrl$suffix. $backendStartHint',
    );
  }

  String accountRequestFailed(int? statusCode) {
    final suffix = statusCode == null
        ? ''
        : text('（状态码 $statusCode）', ' (status $statusCode)');
    return text(
      '账号请求失败$suffix，请检查邮箱、密码和后端服务。',
      'Account request failed$suffix. Check email, password, and API service.',
    );
  }

  String get unexpectedAccountError => text(
        '账号操作失败，请检查后端服务和网络连接。',
        'Account operation failed. Check the API service and network.',
      );
  String get manageCategories => text('管理分类', 'Manage categories');
  String get manageSidebar => text('管理侧边栏', 'Manage sidebar');
  String get sidebarPageItems => text('页面入口', 'Page entries');
  String get sidebarCategoryItems => text('分类入口', 'Category entries');
  String get feedCategories => text('订阅分类', 'Feed categories');
  String get contentTypes => text('内容类型', 'Content types');
  String get addCategory => text('添加分类', 'Add category');
  String get renameCategory => text('重命名分类', 'Rename category');
  String get deleteCategory => text('删除分类', 'Delete category');
  String get categoryName => text('分类名称', 'Category name');
  String get showItem => text('显示', 'Show');
  String get hideItem => text('隐藏', 'Hide');
  String get moveUp => text('上移', 'Move up');
  String get moveDown => text('下移', 'Move down');
  String get systemCategoryLocked =>
      text('系统分类不能重命名或删除', 'System category cannot be renamed or deleted');
  String deleteCategoryMessage(String name) => text('删除“$name”？该分类下的订阅会移到“其他”。',
      'Delete "$name"? Feeds in this category will move to "Other".');

  String get appName => 'ReadFlow';
  String get home => text('首页', 'Home');
  String get feeds => text('订阅', 'Feeds');
  String get saved => text('收藏', 'Saved');
  String get search => text('搜索', 'Search');
  String get recommended => text('推荐', 'Recommended');
  String get forYou => text('推荐', 'For you');
  String get novels => text('小说', 'Novels');
  String get movies => text('电影', 'Movies');
  String get settings => text('设置', 'Settings');
  String get all => text('全部', 'All');
  String get unread => text('未读', 'Unread');
  String get favorite => text('收藏', 'Favorite');
  String get favorites => text('收藏', 'Favorites');
  String get readLater => text('稍后读', 'Read later');
  String get later => text('稍后读', 'Later');
  String get add => text('添加', 'Add');
  String get save => text('保存', 'Save');
  String get cancel => text('取消', 'Cancel');
  String get delete => text('删除', 'Delete');
  String get refresh => text('刷新', 'Refresh');
  String get refreshAll => text('刷新全部', 'Refresh all');
  String get rename => text('重命名', 'Rename');
  String get changeCategory => text('更改分类', 'Change category');
  String get category => text('分类', 'Category');
  String get displayName => text('显示名称', 'Display name');
  String get detect => text('检测', 'Detect');
  String get system => text('跟随系统', 'System');
  String get light => text('浅色', 'Light');
  String get dark => text('深色', 'Dark');
  String get appearance => text('外观', 'Appearance');
  String get language => text('语言', 'Language');
  String get systemLanguage => text('跟随系统语言', 'System language');
  String get chinese => text('中文', 'Chinese');
  String get english => text('English', 'English');
  String get refreshFrequency => text('刷新频率', 'Refresh frequency');
  String get aiSummariesAndTags => text('AI 摘要与标签', 'AI summaries and tags');
  String get syncAccount => text('同步账号', 'Sync account');
  String get apiBaseUrl => text('API 地址', 'API base URL');
  String get email => text('邮箱', 'Email');
  String get password => text('密码', 'Password');
  String get login => text('登录', 'Login');
  String get register => text('注册', 'Register');
  String get syncNow => text('立即同步', 'Sync now');
  String get logout => text('退出登录', 'Logout');
  String get importOpml => text('导入 OPML', 'Import OPML');
  String get exportOpml => text('导出 OPML', 'Export OPML');
  String get clearArticleCache => text('清理文章缓存', 'Clear article cache');
  String get buildCommands => text('构建命令', 'Build commands');
  String get notSignedIn => text('未登录', 'Not signed in');
  String get articleCacheCleared => text('文章缓存已清理', 'Article cache cleared');
  String get loginComplete => text('登录完成', 'Login complete');
  String get registrationComplete => text('注册完成', 'Registration complete');
  String get noFeedsImported => text('未导入订阅源', 'No feeds imported');
  String get exportCanceled => text('已取消导出', 'Export canceled');
  String get opmlExported => text('OPML 已导出', 'OPML exported');
  String get addFeed => text('添加订阅', 'Add feed');
  String get rssAtomUrl => text('RSS / Atom 地址', 'RSS / Atom URL');
  String get enterFeedUrl =>
      text('请输入 RSS 或 Atom 地址。', 'Enter an RSS or Atom URL.');
  String get feedAdded => text('订阅已添加', 'Feed added');
  String get noContentYet =>
      text('还没有内容。先添加一个订阅源吧。', 'No content yet. Add a feed to get started.');
  String get noFeedsYet => text('还没有订阅源。', 'No feeds yet.');
  String get noMatchingContent => text('没有匹配内容。', 'No matching content.');
  String get noFavoritesYet => text('还没有收藏内容。', 'No favorites yet.');
  String get noReadLaterYet => text('还没有稍后读内容。', 'No read-later items yet.');
  String get searchAllLocalContent =>
      text('搜索全部本地内容', 'Search all local content');
  String get searchHomeHint => text(
      '搜索标题、摘要、正文、标签或来源', 'Search title, summary, content, tags, or source');
  String get anyType => text('全部类型', 'Any type');
  String get copyLink => text('复制链接', 'Copy link');
  String get openInBrowser => text('在浏览器打开', 'Open in browser');
  String get moreActions => text('更多操作', 'More actions');
  String get filter => text('筛选', 'Filter');
  String get clearFilters => text('清除筛选', 'Clear filters');
  String get activeFilters => text('当前筛选', 'Active filters');
  String get contentManagement => text('内容管理', 'Content management');
  String get dataManagement => text('数据管理', 'Data management');
  String get readingPreferences => text('阅读偏好', 'Reading preferences');
  String get listDensity => text('列表密度', 'List density');
  String get compact => text('紧凑', 'Compact');
  String get comfortable => text('舒适', 'Comfortable');
  String get spacious => text('宽松', 'Spacious');
  String get showImages => text('显示封面图', 'Show images');
  String get showSummaries => text('显示摘要', 'Show summaries');
  String get readerLineHeight => text('阅读行距', 'Reader line height');
  String get readerWidth => text('阅读栏宽度', 'Reader width');
  String get refreshOnStart => text('启动时自动刷新', 'Refresh on start');
  String get fullTextMode => text('全文抓取', 'Full text');
  String get fullTextOff => text('关闭', 'Off');
  String get fullTextManual => text('手动', 'Manual');
  String get fullTextAuto => text('自动', 'Auto');
  String get fullTextSelector => text('正文选择器', 'Content selector');
  String get fullTextExcludeSelector => text('排除选择器', 'Exclude selector');
  String get fullTextSettings => text('全文抓取设置', 'Full text settings');
  String get getFullText => text('获取全文', 'Get full text');
  String get gettingFullText => text('正在获取全文...', 'Getting full text...');
  String get fullTextFetched => text('全文已加载', 'Full text loaded');
  String get fullTextFailed => text('全文获取失败', 'Full text failed');
  String get incompleteContentHint =>
      text('该订阅源可能只提供摘要。', 'This feed may only provide a summary.');
  String get linkCopied => text('链接已复制', 'Link copied');
  String get selectionCopied => text('选中内容已复制', 'Selection copied');
  String get markSelection => text('标记', 'Mark');
  String get selectionMarked => text('已标记选中内容', 'Selection marked');
  String get articleHighlights => text('文章标记', 'Highlights');
  String get contentNotFound => text('未找到内容', 'Content not found');
  String get markRead => text('标记已读', 'Mark read');
  String get markUnread => text('标记未读', 'Mark unread');
  String get removeFavorite => text('取消收藏', 'Remove favorite');
  String get removeLater => text('移除稍后读', 'Remove later');
  String get recommendationsEmpty => text(
      '添加订阅后，这里会出现推荐内容。', 'Recommendations will appear after you add feeds.');
  String get recommendationsReason => text(
        '基于你的收藏、稍后读、来源和分类生成。',
        'Based on your favorites, read-later list, sources, and categories.',
      );
  String get noNovelUpdates => text('还没有小说更新。', 'No novel updates yet.');
  String get noMovieContent => text('还没有电影资讯。', 'No movie content yet.');

  String signedInAs(String? email) => text('已登录：$email', 'Signed in as $email');
  String readerFontSize(double size) => text('阅读字号：${size.toStringAsFixed(0)}',
      'Reader font size: ${size.toStringAsFixed(0)}');
  String refreshOption(int minutes) {
    final labels = {
      15: text('15 分钟', '15 minutes'),
      30: text('30 分钟', '30 minutes'),
      60: text('1 小时', '1 hour'),
      180: text('3 小时', '3 hours'),
      360: text('6 小时', '6 hours'),
      720: text('12 小时', '12 hours'),
      1440: text('每天', 'Daily'),
    };
    return labels[minutes] ?? text('$minutes 分钟', '$minutes minutes');
  }

  String refreshComplete(int failed) {
    if (failed == 0) return text('刷新完成', 'Refresh complete');
    return text(
        '刷新完成，$failed 个来源失败', 'Refresh complete, $failed source(s) failed');
  }

  String refreshFailed(Object? error) =>
      text('刷新失败：$error', 'Refresh failed: $error');
  String failedToLoadCategories(Object error) =>
      text('分类加载失败：$error', 'Failed to load categories: $error');
  String failedToLoadContent(Object error) =>
      text('内容加载失败：$error', 'Failed to load content: $error');
  String failedToLoadFeeds(Object error) =>
      text('订阅加载失败：$error', 'Failed to load feeds: $error');
  String failedToLoadSavedItems(Object error) =>
      text('收藏内容加载失败：$error', 'Failed to load saved items: $error');
  String searchFailed(Object error) =>
      text('搜索失败：$error', 'Search failed: $error');
  String readerFailed(Object error) =>
      text('阅读器加载失败：$error', 'Reader failed: $error');
  String saveFailed(Object error) => text('保存失败：$error', 'Save failed: $error');
  String feedDetectionFailed(Object error) =>
      text('订阅检测失败：$error', 'Feed detection failed: $error');
  String loginFailed(Object error) =>
      text('登录失败：$error', 'Login failed: $error');
  String registrationFailed(Object error) =>
      text('注册失败：$error', 'Registration failed: $error');
  String syncFailed(Object error) => text('同步失败：$error', 'Sync failed: $error');
  String importFailed(Object error) =>
      text('导入失败：$error', 'Import failed: $error');
  String exportFailed(Object error) =>
      text('导出失败：$error', 'Export failed: $error');
  String recommendationsFailed(Object error) =>
      text('推荐加载失败：$error', 'Recommendations failed: $error');
  String failedToLoadNovels(Object error) =>
      text('小说加载失败：$error', 'Failed to load novels: $error');
  String failedToLoadMovies(Object error) =>
      text('电影资讯加载失败：$error', 'Failed to load movies: $error');
  String synced(int pushed, int pulled) => text(
      '已同步 $pushed 个变更，拉取 $pulled 个事件',
      'Synced $pushed change(s), pulled $pulled event(s)');
  String importComplete(int success, int failed) => text(
      '导入完成：新增 $success 个，失败 $failed 个',
      'Import complete: $success added, $failed failed');
  String detectedItems(int count) =>
      text('检测到 $count 条内容', 'Detected $count item(s)');
  String lastRefresh(String date) => text('上次刷新：$date', 'Last refresh: $date');
  String deleteFeedMessage(String title) =>
      text('删除“$title”及其本地文章？', 'Delete "$title" and its local articles?');
  String latestChapter(String chapter, String date) =>
      text('最新：$chapter | $date', 'Latest: $chapter | $date');
  String rating(String value) => text('评分：$value', 'Rating: $value');
  String release(String value) => text('上映：$value', 'Release: $value');

  String categoryLabel(String category) {
    if (!isZh) return category;
    return switch (category) {
      'All' => all,
      'News' => '新闻',
      'Articles' => '文章',
      'WeChat' => '公众号',
      'Novels' => '小说',
      'Movies' => '电影',
      'Other' => '其他',
      _ => category,
    };
  }

  String contentTypeLabel(ContentType? type) {
    if (type == null) return anyType;
    if (!isZh) return type.name;
    return switch (type) {
      ContentType.article => '文章',
      ContentType.news => '新闻',
      ContentType.wechat => '公众号',
      ContentType.novel => '小说',
      ContentType.movie => '电影',
      ContentType.other => '其他',
    };
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'zh'].contains(locale.languageCode.toLowerCase());
  }

  @override
  Future<AppStrings> load(Locale locale) {
    final languageCode =
        locale.languageCode.toLowerCase() == 'zh' ? 'zh' : 'en';
    return SynchronousFuture(AppStrings(Locale(languageCode)));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension AppStringsContext on BuildContext {
  AppStrings get t => AppStrings.of(this);
}
