import 'package:aichatcline/features/providers/models/model_parameters.dart';

enum ThemeModeOption { system, light, dark }

enum LocaleOption { system, en, ru }

class AppSettings {
  const AppSettings({
    this.selectedProviderId,
    this.selectedModelId,
    this.baseUrl,
    this.systemPrompt = '',
    this.themeMode = ThemeModeOption.system,
    this.locale = LocaleOption.system,
    this.includeMessageContentInLogs = false,
    this.modelParameters = const ModelParameters(),
    this.isApiKeyValidated = false,
  });

  final String? selectedProviderId;
  final String? selectedModelId;
  final String? baseUrl;
  final String systemPrompt;
  final ThemeModeOption themeMode;
  final LocaleOption locale;
  final bool includeMessageContentInLogs;
  final ModelParameters modelParameters;
  final bool isApiKeyValidated;

  factory AppSettings.defaults() {
    return AppSettings(
      selectedProviderId: null,
      selectedModelId: null,
      baseUrl: null,
      systemPrompt: '',
      themeMode: ThemeModeOption.system,
      locale: LocaleOption.system,
      includeMessageContentInLogs: false,
      modelParameters: ModelParameters.defaults(),
      isApiKeyValidated: false,
    );
  }

  AppSettings copyWith({
    Object? selectedProviderId = _noValue,
    Object? selectedModelId = _noValue,
    Object? baseUrl = _noValue,
    String? systemPrompt,
    ThemeModeOption? themeMode,
    LocaleOption? locale,
    bool? includeMessageContentInLogs,
    ModelParameters? modelParameters,
    bool? isApiKeyValidated,
  }) {
    return AppSettings(
      selectedProviderId: selectedProviderId == _noValue
          ? this.selectedProviderId
          : selectedProviderId as String?,
      selectedModelId: selectedModelId == _noValue
          ? this.selectedModelId
          : selectedModelId as String?,
      baseUrl: baseUrl == _noValue ? this.baseUrl : baseUrl as String?,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      includeMessageContentInLogs:
          includeMessageContentInLogs ?? this.includeMessageContentInLogs,
      modelParameters: modelParameters ?? this.modelParameters,
      isApiKeyValidated: isApiKeyValidated ?? this.isApiKeyValidated,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selectedProviderId': selectedProviderId,
      'selectedModelId': selectedModelId,
      'baseUrl': baseUrl,
      'systemPrompt': systemPrompt,
      'themeMode': themeModeToString(themeMode),
      'locale': localeToString(locale),
      'includeMessageContentInLogs': includeMessageContentInLogs,
      'modelParameters': modelParameters.toJson(),
      'isApiKeyValidated': isApiKeyValidated,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      selectedProviderId: json['selectedProviderId'] as String?,
      selectedModelId: json['selectedModelId'] as String?,
      baseUrl: json['baseUrl'] as String?,
      systemPrompt: json['systemPrompt'] as String? ?? '',
      themeMode: themeModeFromString(json['themeMode'] as String? ?? 'system'),
      locale: localeFromString(json['locale'] as String? ?? 'system'),
      includeMessageContentInLogs:
          json['includeMessageContentInLogs'] as bool? ?? false,
      modelParameters: ModelParameters.fromJson(
        json['modelParameters'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      isApiKeyValidated: json['isApiKeyValidated'] as bool? ?? false,
    );
  }

  static String themeModeToString(ThemeModeOption value) {
    return switch (value) {
      ThemeModeOption.system => 'system',
      ThemeModeOption.light => 'light',
      ThemeModeOption.dark => 'dark',
    };
  }

  static ThemeModeOption themeModeFromString(String value) {
    return switch (value) {
      'system' => ThemeModeOption.system,
      'light' => ThemeModeOption.light,
      'dark' => ThemeModeOption.dark,
      _ => ThemeModeOption.system,
    };
  }

  static String localeToString(LocaleOption value) {
    return switch (value) {
      LocaleOption.system => 'system',
      LocaleOption.en => 'en',
      LocaleOption.ru => 'ru',
    };
  }

  static LocaleOption localeFromString(String value) {
    return switch (value) {
      'system' => LocaleOption.system,
      'en' => LocaleOption.en,
      'ru' => LocaleOption.ru,
      _ => LocaleOption.system,
    };
  }
}

const Object _noValue = Object();
