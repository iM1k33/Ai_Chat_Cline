import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/models/model_parameters.dart';
import 'package:aichatcline/features/providers/services/provider_detector.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/settings/ui/widgets/pin_pad.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.modelCatalogController,
    this.onOpenLogs,
    this.onResetAppData,
  });

  final SettingsController controller;
  final ModelCatalogController modelCatalogController;
  final VoidCallback? onOpenLogs;
  final Future<void> Function()? onResetAppData;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
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
  final FocusNode _apiKeyFocusNode = FocusNode();
  bool _revealBusy = false;
  bool _showApiKey = false;
  bool _isAutoUpdatingBaseUrlFromApiKey = false;

  @override
  void initState() {
    super.initState();
    final SettingsController controller = widget.controller;

    _apiKeyController = TextEditingController(text: controller.apiKey);
    _apiKeyController.addListener(_syncBaseUrlFromApiKeyInputIfNeeded);
    _baseUrlController = TextEditingController(
      text: controller.settings.baseUrl ?? '',
    );
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
    _baseUrlController.dispose();
    _modelIdController.dispose();
    _systemPromptController.dispose();
    _temperatureController.dispose();
    _maxTokensController.dispose();
    _topPController.dispose();
    _frequencyPenaltyController.dispose();
    _presencePenaltyController.dispose();
    _modelSearchController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  void _syncBaseUrlFromApiKeyInputIfNeeded() {
    if (_isAutoUpdatingBaseUrlFromApiKey) {
      return;
    }

    final String candidate = _apiKeyController.text.trim();
    if (candidate.isEmpty) {
      return;
    }

    final detected = ProviderDetector.tryDetectByApiKey(candidate);
    if (detected == null) {
      return;
    }

    if (_baseUrlController.text.trim() == detected.baseUrl) {
      return;
    }

    _isAutoUpdatingBaseUrlFromApiKey = true;
    _baseUrlController.text = detected.baseUrl;
    _isAutoUpdatingBaseUrlFromApiKey = false;
  }

  void _syncControllersFromState() {
    if (!mounted) {
      return;
    }

    final SettingsController controller = widget.controller;
    final AppSettings settings = controller.settings;
    final ModelParameters params = settings.modelParameters;

    _setTextIfDifferent(_apiKeyController, controller.apiKey);
    _setTextIfDifferent(_baseUrlController, settings.baseUrl ?? '');
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

  Future<void> _showRevealApiKeyDialog() async {
    if (_revealBusy) {
      return;
    }
    setState(() {
      _revealBusy = true;
    });

    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return _PinRevealDialog(verifyPin: widget.controller.verifyPin);
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _revealBusy = false;
    });

    if (verified == true) {
      setState(() {
        _showApiKey = true;
      });
      final String key = widget.controller.apiKey;
      if (key.trim().isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: key));
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('API key copied')));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _apiKeyFocusNode.requestFocus();
      });
    }
  }

  Future<void> _clearApiKeyWithPinFlow() async {
    if (_revealBusy) {
      return;
    }
    setState(() {
      _revealBusy = true;
    });

    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return _PinRevealDialog(
          verifyPin: widget.controller.verifyPin,
          title: 'Confirm PIN',
          prompt: 'Enter your 4-digit PIN to clear API key',
        );
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _revealBusy = false;
    });

    if (verified != true) {
      return;
    }

    final bool confirmed = await _showClearApiKeyConfirmation();
    if (!confirmed) {
      return;
    }

    await widget.controller.clearApiKey(keepPin: true);
    if (!mounted) {
      return;
    }

    _apiKeyController.clear();
    setState(() {
      _showApiKey = false;
    });
  }

  Future<bool> _showClearApiKeyConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          key: const Key('confirm_clear_api_dialog'),
          title: const Text('Clear API key?'),
          content: const Text(
            'This will remove the saved API key and reset validation state. Chat history, statistics, and logs will be kept.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<bool> _showResetAppDataConfirmation() async {
    final TextEditingController textController = TextEditingController();

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          bool canConfirm = false;

          return StatefulBuilder(
            builder:
                (
                  BuildContext dialogContext,
                  void Function(void Function()) setDialogState,
                ) {
                  return AlertDialog(
                    key: const Key('confirm_reset_app_data_dialog'),
                    title: const Text('Reset app data?'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'This will permanently delete API key, PIN, settings, chats, statistics, and logs. This cannot be undone.',
                          ),
                          const SizedBox(height: 12),
                          const Text('Type RESET to confirm'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: textController,
                            autofocus: true,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (String value) {
                              setDialogState(() {
                                canConfirm =
                                    value.trim().toUpperCase() == 'RESET';
                              });
                            },
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'RESET',
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: canConfirm
                            ? () => Navigator.of(dialogContext).pop(true)
                            : null,
                        child: const Text('Reset all data'),
                      ),
                    ],
                  );
                },
          );
        },
      );

      return confirmed ?? false;
    } finally {
      textController.dispose();
    }
  }

  Future<void> _resetAppDataWithPinFlow() async {
    if (_revealBusy || widget.onResetAppData == null) {
      return;
    }

    setState(() {
      _revealBusy = true;
    });

    final Future<void> Function() resetAppData = widget.onResetAppData!;
    final NavigatorState navigator = Navigator.of(context);

    final bool? verified = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _PinRevealDialog(
          verifyPin: widget.controller.verifyPin,
          title: 'Confirm PIN',
          prompt: 'Enter your 4-digit PIN to reset all app data',
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (verified != true) {
      setState(() {
        _revealBusy = false;
      });
      return;
    }

    final bool confirmed = await _showResetAppDataConfirmation();

    if (!mounted) {
      return;
    }

    if (!confirmed) {
      setState(() {
        _revealBusy = false;
      });
      return;
    }

    setState(() {
      _revealBusy = false;
      _showApiKey = false;
    });

    navigator.popUntil((Route<dynamic> route) => route.isFirst);

    await WidgetsBinding.instance.endOfFrame;

    try {
      await resetAppData();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to reset app data')));
    }
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
              focusNode: _apiKeyFocusNode,
              obscureText: !_showApiKey,
              readOnly: false,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (String value) async {
                await controller.saveApiKey(value);
              },
              decoration: const InputDecoration(
                labelText: 'API key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: _showRevealApiKeyDialog,
                  child: const Text('Reveal API key (PIN)'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: const Key('settings_clear_api_button'),
                  onPressed: _clearApiKeyWithPinFlow,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear API key'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'BASE_URL',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) async {
                await controller.updateBaseUrl(value);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () async {
                  await controller.updateBaseUrl(_baseUrlController.text);
                },
                child: const Text('Save BASE_URL'),
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
                        await controller.saveApiKey(_apiKeyController.text);
                        await controller.updateBaseUrl(_baseUrlController.text);
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
            if (widget.onResetAppData != null) ...<Widget>[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const Key('settings_reset_app_data_button'),
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _revealBusy ? null : _resetAppDataWithPinFlow,
                icon: const Icon(Icons.warning_amber_outlined),
                label: const Text('Reset app data'),
              ),
            ],
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

class _PinRevealDialog extends StatefulWidget {
  const _PinRevealDialog({
    required this.verifyPin,
    this.title = 'Reveal API key',
    this.prompt = 'Enter your 4-digit PIN',
  });

  final Future<bool> Function(String pin) verifyPin;
  final String title;
  final String prompt;

  @override
  State<_PinRevealDialog> createState() => _PinRevealDialogState();
}

class _PinRevealDialogState extends State<_PinRevealDialog> {
  static const int _maxAttempts = 5;

  String _pin = '';
  int _attemptsLeft = _maxAttempts;
  bool _isChecking = false;
  String? _error;

  bool get _enabled => !_isChecking && _attemptsLeft > 0;

  void _onDigit(String digit) {
    if (!_enabled || _pin.length >= 4) {
      return;
    }
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _onBackspace() {
    if (!_enabled || _pin.isEmpty) {
      return;
    }
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_pin.length != 4 || !_enabled) {
      return;
    }
    setState(() {
      _isChecking = true;
    });
    final bool ok = await widget.verifyPin(_pin);
    if (!mounted) {
      return;
    }
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isChecking = false;
      _pin = '';
      _attemptsLeft = _attemptsLeft > 0 ? _attemptsLeft - 1 : 0;
      _error = _attemptsLeft > 0
          ? 'Incorrect PIN. Attempts left: $_attemptsLeft'
          : 'Too many attempts. Close and try later.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.prompt),
            const SizedBox(height: 12),
            Text('●' * _pin.length),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            PinPad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              enabled: _enabled,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isChecking
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ResetAppDataConfirmationDialog extends StatefulWidget {
  const _ResetAppDataConfirmationDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_ResetAppDataConfirmationDialog> createState() =>
      _ResetAppDataConfirmationDialogState();
}

class _ResetAppDataConfirmationDialogState
    extends State<_ResetAppDataConfirmationDialog> {
  bool _canConfirm = false;

  void _handleChanged(String value) {
    setState(() {
      _canConfirm = value.trim().toUpperCase() == 'RESET';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('confirm_reset_app_data_dialog'),
      title: const Text('Reset app data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This will permanently delete API key, PIN, settings, chats, statistics, and logs. This cannot be undone.',
          ),
          const SizedBox(height: 12),
          const Text('Type RESET to confirm'),
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: _handleChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'RESET',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Reset all data'),
        ),
      ],
    );
  }
}
