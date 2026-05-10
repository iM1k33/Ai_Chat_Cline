import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toJson/fromJson preserves selectedModelId and providerId', () {
    final Conversation original = Conversation(
      id: 'c1',
      title: 'Test chat',
      createdAt: DateTime.parse('2026-05-10T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-10T10:01:00Z'),
      selectedModelId: 'openrouter/gpt-4o-mini',
      providerId: 'openrouter',
      systemPrompt: 'Be concise',
      isPinned: true,
    );

    final Map<String, dynamic> json = original.toJson();
    final Conversation restored = Conversation.fromJson(json);

    expect(restored.selectedModelId, 'openrouter/gpt-4o-mini');
    expect(restored.providerId, 'openrouter');
    expect(restored.systemPrompt, 'Be concise');
    expect(restored.isPinned, isTrue);
  });
}
