import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search filters by model id and name', () {
    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );

    final ModelCatalogController controller = ModelCatalogController(
      aiClient: OpenAICompatibleClient(),
      settingsController: settingsController,
    );

    controller.models = <AIModel>[
      const AIModel(id: 'openrouter/gpt-4o', name: 'GPT-4o', providerId: 'openrouter'),
      const AIModel(id: 'openrouter/claude-3.5', name: 'Claude 3.5', providerId: 'openrouter'),
      const AIModel(id: 'vsegpt/yandexgpt', name: 'YandexGPT', providerId: 'vsegpt'),
    ];

    final List<AIModel> byName = controller.search('claude');
    expect(byName.length, 1);
    expect(byName.first.id, 'openrouter/claude-3.5');

    final List<AIModel> byId = controller.search('yandex');
    expect(byId.length, 1);
    expect(byId.first.name, 'YandexGPT');

    final List<AIModel> all = controller.search('');
    expect(all.length, 3);
  });

  test('findModelById returns model on exact id match', () {
    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );

    final ModelCatalogController controller = ModelCatalogController(
      aiClient: OpenAICompatibleClient(),
      settingsController: settingsController,
    );

    controller.models = <AIModel>[
      const AIModel(
        id: 'openrouter/gpt-4o',
        name: 'GPT-4o',
        providerId: 'openrouter',
      ),
    ];

    final AIModel? found = controller.findModelById('openrouter/gpt-4o');
    expect(found, isNotNull);
    expect(found!.name, 'GPT-4o');
  });

  test('findModelById returns null when model is missing', () {
    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );

    final ModelCatalogController controller = ModelCatalogController(
      aiClient: OpenAICompatibleClient(),
      settingsController: settingsController,
    );

    controller.models = <AIModel>[];

    expect(controller.findModelById('missing/model'), isNull);
  });
}
