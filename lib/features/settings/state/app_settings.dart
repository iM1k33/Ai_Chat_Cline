import 'package:aichatcline/features/providers/models/model_parameters.dart';

enum ThemeModeOption { system, light, dark }

enum LocaleOption { system, en, ru }

class AppSettings {
  const AppSettings({
    this.selectedProviderId,
    this.selectedModelId,
    this.systemPrompt = '',
    this.themeMode = ThemeModeOption.system,
    this.locale = LocaleOption.system,
    this.includeMessageContentInLogs = false,
    this.modelParameters = const ModelParameters(),
  });

  final String? selectedProviderId;
  final String? selectedModelId;
  final String systemPrompt;
  final ThemeModeOption themeMode;
  final LocaleOption locale;
  final bool includeMessageContentInLogs;
  final ModelParameters modelParameters;

  factory AppSettings.defaults() {
    return AppSettings(
      selectedProviderId: null,
      selectedModelId: null,
      systemPrompt: '',
      themeMode: ThemeModeOption.system,
      locale: LocaleOption.system,
      includeMessageContentInLogs: false,
      modelParameters: ModelParameters.defaults(),
    );
  }

  AppSettings copyWith({
    String? selectedProviderId,
    String? selectedModelId,
    String? systemPrompt,
    ThemeModeOption? themeMode,
    LocaleOption? locale,
    bool? includeMessageContentInLogs,
    ModelParameters? modelParameters,
  }) {
    return AppSettings(
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      includeMessageContentInLogs:
          includeMessageContentInLogs ?? this.includeMessageContentInLogs,
      modelParameters: modelParameters ?? this.modelParameters,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selectedProviderId': selectedProviderId,
      'selectedModelId': selectedModelId,
      'systemPrompt': systemPrompt,
      'themeMode': themeModeToString(themeMode),
      'locale': localeToString(locale),
      'includeMessageContentInLogs': includeMessageContentInLogs,
      'modelParameters': modelParameters.toJson(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      selectedProviderId: json['selectedProviderId'] as String?,
      selectedModelId: json['selectedModelId'] as String?,
      systemPrompt: json['systemPrompt'] as String? ?? '',
      themeMode: themeModeFromString(json['themeMode'] as String? ?? 'system'),
      locale: localeFromString(json['locale'] as String? ?? 'system'),
      includeMessageContentInLogs:
          json['includeMessageContentInLogs'] as bool? ?? false,
      modelParameters: ModelParameters.fromJson(
        json['modelParameters'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
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
