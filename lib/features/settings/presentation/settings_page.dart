import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/snackbar.dart';
import '../../entries/presentation/entry_providers.dart';
import '../../feeds/data/opml_service.dart';
import '../../feeds/presentation/feed_providers.dart';
import 'settings_provider.dart';

class SettingsPage extends ConsumerWidget {
  SettingsPage({super.key});

  final _apiController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const refreshOptions = <int, String>{
    15: '15 minutes',
    30: '30 minutes',
    60: '1 hour',
    180: '3 hours',
    360: '6 hours',
    720: '12 hours',
    1440: 'Daily',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    if (_apiController.text.isEmpty) _apiController.text = settings.apiBaseUrl;
    if (_emailController.text.isEmpty && (settings.accountEmail?.isNotEmpty ?? false)) {
      _emailController.text = settings.accountEmail!;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<ThemeMode>(
            initialValue: settings.themeMode,
            decoration: const InputDecoration(labelText: 'Appearance'),
            items: const [
              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
            ],
            onChanged: (value) {
              if (value != null) ref.read(settingsControllerProvider.notifier).setThemeMode(value);
            },
          ),
          const SizedBox(height: 20),
          Text('Reader font size: ${settings.fontSize.toStringAsFixed(0)}'),
          Slider(
            value: settings.fontSize,
            min: 14,
            max: 24,
            divisions: 10,
            label: settings.fontSize.toStringAsFixed(0),
            onChanged: (value) => ref.read(settingsControllerProvider.notifier).setFontSize(value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.refreshMinutes,
            decoration: const InputDecoration(labelText: 'Refresh frequency'),
            items: refreshOptions.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
            onChanged: (value) {
              if (value != null) ref.read(settingsControllerProvider.notifier).setRefreshMinutes(value);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('AI summaries and tags'),
            value: settings.aiEnabled,
            onChanged: (value) => ref.read(settingsControllerProvider.notifier).setAiEnabled(value),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sync account', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiController,
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      prefixIcon: Icon(Icons.cloud_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    onSubmitted: (value) => ref.read(settingsControllerProvider.notifier).setApiBaseUrl(value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (settings.authToken?.isNotEmpty ?? false)
                        ? 'Signed in as ${settings.accountEmail}'
                        : 'Not signed in',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _login(context, ref),
                        icon: const Icon(Icons.login),
                        label: const Text('Login'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _register(context, ref),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('Register'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (settings.authToken?.isNotEmpty ?? false) ? () => _syncNow(context, ref) : null,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync now'),
                      ),
                      OutlinedButton.icon(
                        onPressed: (settings.authToken?.isNotEmpty ?? false)
                            ? () => ref.read(settingsControllerProvider.notifier).logout()
                            : null,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ],
              ),
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
                label: const Text('Import OPML'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportOpml(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Export OPML'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(settingsControllerProvider.notifier).clearCache();
                  ref.invalidate(entriesProvider);
                  if (context.mounted) showMessage(context, 'Article cache cleared');
                },
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear article cache'),
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
                  Text('Build commands', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const SelectableText('Windows: flutter build windows\nAndroid: flutter build apk --release'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsControllerProvider.notifier).setApiBaseUrl(_apiController.text);
    try {
      await ref.read(settingsControllerProvider.notifier).login(_emailController.text, _passwordController.text);
      if (context.mounted) showMessage(context, 'Login complete');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Login failed: $error');
    }
  }

  Future<void> _register(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsControllerProvider.notifier).setApiBaseUrl(_apiController.text);
    try {
      await ref.read(settingsControllerProvider.notifier).register(_emailController.text, _passwordController.text);
      if (context.mounted) showMessage(context, 'Registration complete');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Registration failed: $error');
    }
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsControllerProvider.notifier).setApiBaseUrl(_apiController.text);
    try {
      final result = await ref.read(settingsControllerProvider.notifier).syncNow();
      if (context.mounted) showMessage(context, 'Synced ${result.pushed} change(s), pulled ${result.pulled} event(s)');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Sync failed: $error');
    }
  }

  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {
    try {
      final items = await opmlService.importFromFile();
      if (items.isEmpty) {
        if (context.mounted) showMessage(context, 'No feeds imported');
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
      if (context.mounted) showMessage(context, 'Import complete: $success added, $failed failed');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Import failed: $error');
    }
  }

  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {
    try {
      final feeds = await ref.read(feedRepositoryProvider).getFeeds();
      final path = await opmlService.exportToFile(feeds);
      if (context.mounted) showMessage(context, path == null ? 'Export canceled' : 'OPML exported');
    } catch (error) {
      if (context.mounted) showMessage(context, 'Export failed: $error');
    }
  }

  String _normalizeCategory(String? category) {
    return defaultCategories.contains(category) ? category! : 'Other';
  }
}
