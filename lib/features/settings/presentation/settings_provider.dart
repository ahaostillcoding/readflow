import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/sync/sync_repository.dart';
import '../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  return SyncRepository(ref.watch(appDatabaseProvider), ref.watch(dioProvider));
});

final settingsControllerProvider = StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(
    ref.watch(settingsRepositoryProvider),
    ref.watch(syncRepositoryProvider),
  );
});

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.fontSize = 16,
    this.refreshMinutes = 60,
    this.aiEnabled = true,
    this.apiBaseUrl = 'http://localhost:8000',
    this.accountEmail,
    this.authToken,
    this.loaded = false,
  });

  final ThemeMode themeMode;
  final double fontSize;
  final int refreshMinutes;
  final bool aiEnabled;
  final String apiBaseUrl;
  final String? accountEmail;
  final String? authToken;
  final bool loaded;

  SettingsState copyWith({
    ThemeMode? themeMode,
    double? fontSize,
    int? refreshMinutes,
    bool? aiEnabled,
    String? apiBaseUrl,
    String? accountEmail,
    String? authToken,
    bool? loaded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontSize: fontSize ?? this.fontSize,
      refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      accountEmail: accountEmail ?? this.accountEmail,
      authToken: authToken ?? this.authToken,
      loaded: loaded ?? this.loaded,
    );
  }
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repository, this._syncRepository) : super(const SettingsState()) {
    load();
  }

  final SettingsRepository _repository;
  final SyncRepository _syncRepository;

  Future<void> load() async {
    final settings = await _repository.getAll();
    state = SettingsState(
      themeMode: _parseTheme(settings['theme_mode']),
      fontSize: double.tryParse(settings['font_size'] ?? '') ?? 16,
      refreshMinutes: int.tryParse(settings['refresh_minutes'] ?? '') ?? 60,
      aiEnabled: settings['ai_enabled'] != 'false',
      apiBaseUrl: settings['api_base_url'] ?? 'http://localhost:8000',
      accountEmail: settings['account_email'],
      authToken: settings['auth_token'],
      loaded: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _repository.setValue('theme_mode', mode.name);
  }

  Future<void> setFontSize(double size) async {
    state = state.copyWith(fontSize: size);
    await _repository.setValue('font_size', size.toStringAsFixed(0));
  }

  Future<void> setRefreshMinutes(int minutes) async {
    state = state.copyWith(refreshMinutes: minutes);
    await _repository.setValue('refresh_minutes', minutes.toString());
  }

  Future<void> setAiEnabled(bool enabled) async {
    state = state.copyWith(aiEnabled: enabled);
    await _repository.setValue('ai_enabled', enabled.toString());
  }

  Future<void> setApiBaseUrl(String baseUrl) async {
    final value = baseUrl.trim().isEmpty ? 'http://localhost:8000' : baseUrl.trim();
    state = state.copyWith(apiBaseUrl: value);
    await _repository.setValue('api_base_url', value);
  }

  Future<void> login(String email, String password) async {
    final token = await _syncRepository.login(baseUrl: state.apiBaseUrl, email: email, password: password);
    await _saveAccount(email, token);
  }

  Future<void> register(String email, String password) async {
    final token = await _syncRepository.register(baseUrl: state.apiBaseUrl, email: email, password: password);
    await _saveAccount(email, token);
  }

  Future<SyncResult> syncNow() {
    final token = state.authToken;
    if (token == null || token.isEmpty) {
      throw StateError('Login before syncing.');
    }
    return _syncRepository.sync(baseUrl: state.apiBaseUrl, token: token);
  }

  Future<void> logout() async {
    state = state.copyWith(accountEmail: '', authToken: '');
    await _repository.setValue('account_email', '');
    await _repository.setValue('auth_token', '');
  }

  Future<void> clearCache() {
    return _repository.clearEntries();
  }

  Future<void> _saveAccount(String email, String token) async {
    state = state.copyWith(accountEmail: email.trim(), authToken: token);
    await _repository.setValue('account_email', email.trim());
    await _repository.setValue('auth_token', token);
  }

  ThemeMode _parseTheme(String? value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
