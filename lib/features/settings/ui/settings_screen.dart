import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/models/model_parameters.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.modelCatalogController,
    this.onOpenLogs,
  });

  final SettingsController controller;
  final ModelCatalogController modelCatalogController;
  final VoidCallback? onOpenLogs;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelIdController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _maxTokensController;
  late final TextEditingController _topPController;
  late final TextEditingController _frequencyPenaltyController;
  late final TextEditingController _presencePenaltyController;
  late final TextEditingController _modelSearchController;
  late ThemeModeOption _selectedThemeMode;
  late LocaleOption _selectedLocale;

  @override
  void initState() {
    super.initState();
    final SettingsController controller = widget.controller;

    _apiKeyController = TextEditingController(text: controller.apiKey);
    _modelIdController = TextEditingController(
      text: controller.settings.selectedModelId ?? '',
    );
    _systemPromptController = TextEditingController(
      text: controller.settings.systemPrompt,
    );
    _temperatureController = TextEditingController(
      text: controller.settings.modelParameters.temperature.toString(),
    );
    _maxTokensController = TextEditingController(
      text: controller.settings.modelParameters.maxTokens?.toString() ?? '',
    );
    _topPController = TextEditingController(
      text: controller.settings.modelParameters.topP.toString(),
    );
    _frequencyPenaltyController = TextEditingController(
      text: controller.settings.modelParameters.frequencyPenalty.toString(),
    );
    _presencePenaltyController = TextEditingController(
      text: controller.settings.modelParameters.presencePenalty.toString(),
    );
    _modelSearchController = TextEditingController();
    _selectedThemeMode = controller.settings.themeMode;
    _selectedLocale = controller.settings.locale;

    controller.addListener(_syncControllersFromState);
    widget.modelCatalogController.addListener(_syncControllersFromState);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncControllersFromState);
    widget.modelCatalogController.removeListener(_syncControllersFromState);
    _apiKeyController.dispose();
    _modelIdController.dispose();
    _systemPromptController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _topPController.dispose();
    _frequencyPenaltyController.dispose();
    _presencePenaltyController.dispose();
    _modelSearchController.dispose();
    super.dispose();
  }

  void _syncControllersFromState() {
    if (!mounted) {
      return;
    }

    final SettingsController controller = widget.controller;
    final AppSettings settings = controller.settings;
    final ModelParameters params = settings.modelParameters;

    _setTextIfDifferent(_apiKeyController, controller.apiKey);
    _setTextIfDifferent(_modelIdController, settings.selectedModelId ?? '');
    _setTextIfDifferent(_systemPromptController, settings.systemPrompt);
    _setTextIfDifferent(_temperatureController, params.temperature.toString());
    _setTextIfDifferent(
      _maxTokensController,
      params.maxTokens?.toString() ?? '',
    );
    _setTextIfDifferent(_topPController, params.topP.toString());
    _setTextIfDifferent(
      _frequencyPenaltyController,
      params.frequencyPenalty.toString(),
    );
    _setTextIfDifferent(
      _presencePenaltyController,
      params.presencePenalty.toString(),
    );
    _selectedThemeMode = settings.themeMode;
    _selectedLocale = settings.locale;

    setState(() {});
  }

  void _setTextIfDifferent(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.text = value;
    }
  }

  Future<void> _saveModelParameters() async {
    final SettingsController controller = widget.controller;
    final ModelParameters current = controller.settings.modelParameters;

    final double? parsedTemperature = double.tryParse(
      _temperatureController.text,
    );
    final int? parsedMaxTokens = _maxTokensController.text.trim().isEmpty
        ? null
        : int.tryParse(_maxTokensController.text.trim());
    final double? parsedTopP = double.tryParse(_topPController.text);
    final double? parsedFrequencyPenalty = double.tryParse(
      _frequencyPenaltyController.text,
    );
    final double? parsedPresencePenalty = double.tryParse(
      _presencePenaltyController.text,
    );

    final ModelParameters updated = current.copyWith(
      temperature: parsedTemperature ?? current.temperature,
      maxTokens: parsedMaxTokens,
      topP: parsedTopP ?? current.topP,
      frequencyPenalty: parsedFrequencyPenalty ?? current.frequencyPenalty,
      presencePenalty: parsedPresencePenalty ?? current.presencePenalty,
    );

    await controller.updateModelParameters(updated);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = widget.controller;
    final ModelCatalogController modelCatalogController =
        widget.modelCatalogController;
    final AppSettings settings = controller.settings;
    final ModelParameters params = settings.modelParameters;
    final List<AIModel> filteredModels = modelCatalogController.search(
      _modelSearchController.text,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'API key',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await controller.saveApiKey(value);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await controller.saveApiKey(_apiKeyController.text);
                },
                child: const Text('Save API key'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'API key validated: ${controller.isApiKeyValidated ? 'Yes' : 'No'}',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed:
                    (!controller.hasApiKey || controller.isValidatingApiKey)
                    ? null
                    : () async {
                        await controller.validateCurrentApiKey();
                      },
                child: controller.isValidatingApiKey
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Validate API key'),
              ),
            ),
            if (controller.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  controller.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Detected provider: ${controller.detectedProvider?.name ?? 'Not detected'}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.tonal(
                  onPressed: modelCatalogController.isLoading
                      ? null
                      : () async {
                          await modelCatalogController.loadModels();
                        },
                  child: modelCatalogController.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load models'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    modelCatalogController.lastLoadedAt == null
                        ? 'Models not loaded yet'
                        : 'Loaded: ${modelCatalogController.models.length}',
                  ),
                ),
              ],
            ),
            if (modelCatalogController.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  modelCatalogController.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _modelSearchController,
              decoration: const InputDecoration(
                labelText: 'Search models',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            if (filteredModels.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.builder(
                  itemCount: filteredModels.length,
                  itemBuilder: (BuildContext context, int index) {
                    final AIModel model = filteredModels[index];
                    final bool isSelected =
                        settings.selectedModelId?.trim() == model.id;
                    final String subtitle = <String>[
                      if (model.contextLength != null)
                        'ctx ${model.contextLength}',
                      if (model.promptPrice != null)
                        'prompt ${model.promptPrice}',
                      if (model.completionPrice != null)
                        'completion ${model.completionPrice}',
                      if (model.currencyCode != null) model.currencyCode!,
                    ].join(' • ');

                    return ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(model.name),
                      subtitle: Text(
                        subtitle.isEmpty ? model.id : '${model.id} • $subtitle',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isSelected ? const Icon(Icons.check) : null,
                      onTap: () async {
                        await modelCatalogController.selectModel(model);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelIdController,
              decoration: const InputDecoration(
                labelText: 'Default model for new chats',
                helperText: 'Used when you create a new conversation.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await modelCatalogController.selectModelById(value);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await modelCatalogController.selectModelById(
                    _modelIdController.text,
                  );
                },
                child: const Text('Save model ID'),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _systemPromptController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Global system prompt',
                helperText: 'Applied to all new chat requests.',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) async {
                await controller.updateSystemPrompt(
                  _systemPromptController.text,
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await controller.updateSystemPrompt(
                    _systemPromptController.text,
                  );
                },
                child: const Text('Save system prompt'),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ThemeModeOption>(
              initialValue: _selectedThemeMode,
              decoration: const InputDecoration(
                labelText: 'Theme mode',
                border: OutlineInputBorder(),
              ),
              items: ThemeModeOption.values
                  .map(
                    (value) => DropdownMenuItem<ThemeModeOption>(
                      value: value,
                      child: Text(AppSettings.themeModeToString(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedThemeMode = value;
                  });
                  await controller.updateThemeMode(value);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LocaleOption>(
              initialValue: _selectedLocale,
              decoration: const InputDecoration(
                labelText: 'Locale',
                border: OutlineInputBorder(),
              ),
              items: LocaleOption.values
                  .map(
                    (value) => DropdownMenuItem<LocaleOption>(
                      value: value,
                      child: Text(AppSettings.localeToString(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedLocale = value;
                  });
                  await controller.updateLocale(value);
                }
              },
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include short message snippets in logs'),
              subtitle: const Text(
                'Keeps logs compact by storing up to 300 characters per snippet.',
              ),
              value: settings.includeMessageContentInLogs,
              onChanged: (value) async {
                await controller.updateIncludeMessageContentInLogs(
                  value ?? false,
                );
              },
            ),
            if (widget.onOpenLogs != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onOpenLogs,
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Open logs'),
                ),
              ),
            const Divider(height: 24),
            TextField(
              controller: _temperatureController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Temperature',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxTokensController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max tokens',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topPController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Top-p',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _frequencyPenaltyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Frequency penalty',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _presencePenaltyController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Presence penalty',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Streaming enabled'),
              value: params.streamingEnabled,
              onChanged: (value) async {
                await controller.updateModelParameters(
                  params.copyWith(streamingEnabled: value ?? true),
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _saveModelParameters,
                child: const Text('Save model parameters'),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await controller.resetSettings();
              },
              child: const Text('Reset settings'),
            ),
            if (controller.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
