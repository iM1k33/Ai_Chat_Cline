import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/services/provider_detector.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter/material.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  bool _obscureApiKey = true;
  bool _baseUrlManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: widget.controller.apiKey);
    _baseUrlController = TextEditingController(
      text: widget.controller.settings.baseUrl ?? '',
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  AIProvider? get _previewProvider {
    return ProviderDetector.tryDetectByApiKey(_apiKeyController.text);
  }

  String get _providerLabel {
    final AIProvider? provider = _previewProvider;
    if (provider == null) {
      return 'Unknown provider';
    }

    return provider.name;
  }

  String get _baseUrlLabel {
    final AIProvider? provider = _previewProvider;
    if (provider == null) {
      return 'Provider will be detected from API key';
    }

    return provider.baseUrl;
  }

  Future<void> _validateAndContinue() async {
    await widget.controller.saveAndValidateInitialApiSetup(
      apiKey: _apiKeyController.text,
      baseUrl: _baseUrlController.text,
    );
  }

  void _onApiKeyChanged(String value) {
    final AIProvider? provider = ProviderDetector.tryDetectByApiKey(value);
    if (provider != null && !_baseUrlManuallyEdited) {
      _baseUrlController.text = provider.baseUrl;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final SettingsController controller = widget.controller;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Set up AI provider',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter your API key. The provider and base URL will be detected automatically.',
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: _obscureApiKey,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'API key',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscureApiKey
                                ? 'Show API key'
                                : 'Hide API key',
                            onPressed: () {
                              setState(() {
                                _obscureApiKey = !_obscureApiKey;
                              });
                            },
                            icon: Icon(
                              _obscureApiKey
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        onChanged: _onApiKeyChanged,
                        onSubmitted: (_) async {
                          await _validateAndContinue();
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _baseUrlController,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'BASE_URL',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          _baseUrlManuallyEdited = true;
                        },
                      ),
                      const SizedBox(height: 12),
                      Text('Detected provider: $_providerLabel'),
                      const SizedBox(height: 6),
                      Text('Base URL: $_baseUrlLabel'),
                      if (controller.error != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: controller.isValidatingApiKey
                              ? null
                              : _validateAndContinue,
                          child: controller.isValidatingApiKey
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Validate / Continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
