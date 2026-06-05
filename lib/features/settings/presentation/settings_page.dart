import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/sync/sync_repository.dart';
import '../../../core/utils/snackbar.dart';
import '../../categories/presentation/category_management_page.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../feeds/data/opml_service.dart';
import '../../feeds/presentation/feed_providers.dart';
import '../../sidebar/presentation/sidebar_management_page.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  SettingsPage({super.key});

  final _apiController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const refreshOptions = [15, 30, 60, 180, 360, 720, 1440];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    if (_apiController.text.isEmpty) _apiController.text = settings.apiBaseUrl;
    if (_emailController.text.isEmpty &&
        (settings.accountEmail?.isNotEmpty ?? false)) {
      _emailController.text = settings.accountEmail!;
    }
    final t = context.t;
    final accountBusy = settings.isAccountBusy;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ThemeMode>(
            initialValue: settings.themeMode,
            decoration: InputDecoration(labelText: t.appearance),
            items: [
              DropdownMenuItem(value: ThemeMode.system, child: Text(t.system)),
              DropdownMenuItem(value: ThemeMode.light, child: Text(t.light)),
              DropdownMenuItem(value: ThemeMode.dark, child: Text(t.dark)),
            ],
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setThemeMode(value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<LanguageMode>(
            initialValue: settings.languageMode,
            decoration: InputDecoration(labelText: t.language),
            items: [
              DropdownMenuItem(
                  value: LanguageMode.system, child: Text(t.systemLanguage)),
              DropdownMenuItem(value: LanguageMode.zh, child: Text(t.chinese)),
              DropdownMenuItem(value: LanguageMode.en, child: Text(t.english)),
            ],
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setLanguageMode(value);
              }
            },
          ),
          const SizedBox(height: 20),
          Text(t.readerFontSize(settings.fontSize)),
          Slider(
            value: settings.fontSize,
            min: 14,
            max: 24,
            divisions: 10,
            label: settings.fontSize.toStringAsFixed(0),
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .setFontSize(value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.refreshMinutes,
            decoration: InputDecoration(labelText: t.refreshFrequency),
            items: refreshOptions
                .map((minutes) => DropdownMenuItem(
                    value: minutes, child: Text(t.refreshOption(minutes))))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setRefreshMinutes(value);
              }
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.aiSummariesAndTags),
            value: settings.aiEnabled,
            onChanged: (value) => ref
                .read(settingsControllerProvider.notifier)
                .setAiEnabled(value),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.syncAccount,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiController,
                    decoration: InputDecoration(
                      labelText: t.apiBaseUrl,
                      prefixIcon: const Icon(Icons.cloud_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (value) => ref
                        .read(settingsControllerProvider.notifier)
                        .setApiBaseUrl(value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: t.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: t.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (settings.authToken?.isNotEmpty ?? false)
                        ? t.signedInAs(settings.accountEmail)
                        : t.notSignedIn,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _connectionStatusText(context, settings),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: settings.apiReachable == false
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            accountBusy ? null : () => _login(context, ref),
                        icon: accountBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(t.login),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            accountBusy ? null : () => _register(context, ref),
                        icon: const Icon(Icons.person_add_alt),
                        label: Text(t.register),
                      ),
                      OutlinedButton.icon(
                        onPressed: accountBusy
                            ? null
                            : () => _checkConnection(context, ref),
                        icon: const Icon(Icons.cloud_done_outlined),
                        label: Text(t.checkConnection),
                      ),
                      OutlinedButton.icon(
                        onPressed: !accountBusy &&
                                (settings.authToken?.isNotEmpty ?? false)
                            ? () => _syncNow(context, ref)
                            : null,
                        icon: const Icon(Icons.sync),
                        label: Text(t.syncNow),
                      ),
                      OutlinedButton.icon(
                        onPressed: !accountBusy &&
                                (settings.authToken?.isNotEmpty ?? false)
                            ? () => ref
                                .read(settingsControllerProvider.notifier)
                                .logout()
                            : null,
                        icon: const Icon(Icons.logout),
                        label: Text(t.logout),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const CategoryManagementPage()),
                  ),
                  icon: const Icon(Icons.category_outlined),
                  label: Text(t.manageCategories),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SidebarManagementPage()),
                  ),
                  icon: const Icon(Icons.view_sidebar_outlined),
                  label: Text(t.manageSidebar),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => _importOpml(context, ref),
                icon: const Icon(Icons.upload_file),
                label: Text(t.importOpml),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportOpml(context, ref),
                icon: const Icon(Icons.download),
                label: Text(t.exportOpml),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(settingsControllerProvider.notifier)
                      .clearCache();
                  ref.invalidate(entriesProvider);
                  if (context.mounted) {
                    showMessage(context, context.t.articleCacheCleared);
                  }
                },
                icon: const Icon(Icons.cleaning_services),
                label: Text(t.clearArticleCache),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.buildCommands,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const SelectableText(
                      'Windows: flutter build windows\nAndroid: flutter build apk --release'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setApiBaseUrl(_apiController.text);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .login(_emailController.text, _passwordController.text);
      if (context.mounted) showMessage(context, context.t.loginComplete);
    } catch (error) {
      if (context.mounted) {
        showMessage(
            context, context.t.loginFailed(_accountError(context, error)));
      }
    }
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setApiBaseUrl(_apiController.text);
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .register(_emailController.text, _passwordController.text);
      if (context.mounted) showMessage(context, context.t.registrationComplete);
    } catch (error) {
      if (context.mounted) {
        showMessage(context,
            context.t.registrationFailed(_accountError(context, error)));
      }
    }
  }

  Future<void> _checkConnection(BuildContext context, WidgetRef ref) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setApiBaseUrl(_apiController.text);
    try {
      await ref.read(settingsControllerProvider.notifier).checkConnection();
      if (context.mounted) showMessage(context, context.t.backendConnected);
    } catch (error) {
      if (context.mounted) showMessage(context, _accountError(context, error));
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setApiBaseUrl(_apiController.text);
    try {
      final result =
          await ref.read(settingsControllerProvider.notifier).syncNow();
      if (context.mounted) {
        showMessage(context, context.t.synced(result.pushed, result.pulled));
      }
    } catch (error) {
      if (context.mounted) {
        showMessage(
            context, context.t.syncFailed(_accountError(context, error)));
      }
    }
  }

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
    try {
      final items = await opmlService.importFromFile();
      if (items.isEmpty) {
        if (context.mounted) showMessage(context, context.t.noFeedsImported);
        return;
      }

      var success = 0;
      var failed = 0;
      for (final item in items) {
        try {
          await ref.read(feedsControllerProvider.notifier).addFeed(
                item.url,
                _normalizeCategory(item.category),
                title: item.title,
              );
          success++;
        } catch (_) {
          failed++;
        }
      }
      if (context.mounted) {
        showMessage(context, context.t.importComplete(success, failed));
      }
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.importFailed(error));
    }
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    try {
      final feeds = await ref.read(feedRepositoryProvider).getFeeds();
      final path = await opmlService.exportToFile(feeds);
      if (context.mounted) {
        showMessage(context,
            path == null ? context.t.exportCanceled : context.t.opmlExported);
      }
    } catch (error) {
      if (context.mounted) showMessage(context, context.t.exportFailed(error));
    }
  }

  String _normalizeCategory(String? category) {
    return defaultCategories.contains(category) ? category! : 'Other';
  }

  String _connectionStatusText(BuildContext context, SettingsState settings) {
    if (settings.apiReachable == true) return context.t.backendConnected;
    if (settings.apiReachable == false) {
      return context.t
          .backendUnavailable(settings.apiBaseUrl, settings.apiStatusCode);
    }
    return context.t.backendNotChecked;
  }

  String _accountError(BuildContext context, Object error) {
    if (error is BackendUnavailableException) {
      return context.t.backendUnavailable(error.baseUrl, error.statusCode);
    }
    if (error is DioException) {
      return context.t.accountRequestFailed(error.response?.statusCode);
    }
    if (error is FormatException) {
      return context.t.unexpectedAccountError;
    }
    if (error is StateError) {
      return error.message;
    }
    return context.t.unexpectedAccountError;
  }
}
