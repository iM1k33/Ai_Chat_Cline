import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter/foundation.dart';

class ModelCatalogController extends ChangeNotifier {
  ModelCatalogController({
    required OpenAICompatibleClient aiClient,
    required SettingsController settingsController,
  }) : _aiClient = aiClient,
       _settingsController = settingsController;

  final OpenAICompatibleClient _aiClient;
  final SettingsController _settingsController;

  List<AIModel> models = <AIModel>[];
  bool isLoading = false;
  String? error;
  DateTime? lastLoadedAt;

  AIModel? get selectedModel {
    final String? selectedId = _settingsController.settings.selectedModelId
        ?.trim();
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    for (final AIModel model in models) {
      if (model.id == selectedId) {
        return model;
      }
    }

    return null;
  }

  List<AIModel> search(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<AIModel>.from(models);
    }

    return models.where((AIModel model) {
      return model.id.toLowerCase().contains(normalized) ||
          model.name.toLowerCase().contains(normalized);
    }).toList();
  }

  AIModel? findModelById(String modelId) {
    final String normalized = modelId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    for (final AIModel model in models) {
      if (model.id == normalized) {
        return model;
      }
    }

    return null;
  }

  Future<void> loadModels() async {
    if (!_settingsController.isApiKeyValidated ||
        !_settingsController.hasRecognizedProvider) {
      error = 'Validate API key and detect provider first.';
      notifyListeners();
      return;
    }

    final AIProvider? provider = _settingsController.detectedProvider;
    if (provider == null) {
      error = 'Provider is not configured.';
      notifyListeners();
      return;
    }

    final String apiKey = _settingsController.apiKey.trim();
    if (apiKey.isEmpty) {
      error = 'API key is missing.';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final List<AIModel> fetched = await _aiClient.fetchModels(
        provider: provider,
        apiKey: apiKey,
      );

      fetched.sort((AIModel a, AIModel b) {
        final String aKey = a.name.trim().isEmpty ? a.id : a.name;
        final String bKey = b.name.trim().isEmpty ? b.id : b.name;
        return aKey.toLowerCase().compareTo(bKey.toLowerCase());
      });

      models = fetched;
      lastLoadedAt = DateTime.now();

      final String? selectedModelId = _settingsController.settings.selectedModelId
          ?.trim();
      if (selectedModelId != null && selectedModelId.isNotEmpty) {
        final bool exists = models.any((AIModel model) => model.id == selectedModelId);
        if (!exists) {
          error = 'Previously selected model is not in the loaded list.';
        }
      }
    } on AppException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Failed to load models';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectModel(AIModel model) async {
    await _settingsController.updateSelectedModelId(model.id);
    notifyListeners();
  }

  Future<void> selectModelById(String modelId) async {
    final String normalized = modelId.trim();
    if (normalized.isEmpty) {
      error = 'Model ID cannot be empty.';
      notifyListeners();
      return;
    }

    await _settingsController.updateSelectedModelId(normalized);
    error = null;
    notifyListeners();
  }
}
