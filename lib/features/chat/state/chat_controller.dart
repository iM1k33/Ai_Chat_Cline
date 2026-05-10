import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ChatRepository chatRepository,
    required SettingsController settingsController,
    required OpenAICompatibleClient aiClient,
    required StatsRepository statsRepository,
  }) : _chatRepository = chatRepository,
       _settingsController = settingsController,
       _aiClient = aiClient,
       _statsRepository = statsRepository;

  final ChatRepository _chatRepository;
  final SettingsController _settingsController;
  final OpenAICompatibleClient _aiClient;
  final StatsRepository _statsRepository;
  final Uuid _uuid = const Uuid();

  List<Conversation> conversations = <Conversation>[];
  Conversation? currentConversation;
  List<ChatMessage> messages = <ChatMessage>[];
  bool isLoading = false;
  bool isSending = false;
  String? error;

  ChatMessage? get lastUserMessage {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == ChatMessageRole.user) {
        return messages[i];
      }
    }
    return null;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      conversations = await _chatRepository.getConversations();

      if (conversations.isNotEmpty) {
        await selectConversation(conversations.first.id);
      } else {
        await createNewConversation();
      }
    } catch (_) {
      error = 'Failed to load chats';
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    try {
      final DateTime now = DateTime.now();
      final Conversation conversation = Conversation(
        id: _uuid.v4(),
        title: 'New chat',
        createdAt: now,
        updatedAt: now,
        selectedModelId: null,
        providerId: null,
        systemPrompt: null,
        isPinned: false,
      );

      await _chatRepository.upsertConversation(conversation);
      await _reloadConversations();
      await selectConversation(conversation.id);
    } catch (_) {
      error = 'Failed to create chat';
      notifyListeners();
    }
  }

  Future<void> selectConversation(String conversationId) async {
    try {
      final Conversation? selected = await _chatRepository.getConversationById(
        conversationId,
      );
      if (selected == null) {
        return;
      }

      currentConversation = selected;
      messages = await _chatRepository.getMessages(conversationId);
      isLoading = false;
      error = null;
      notifyListeners();
    } catch (_) {
      error = 'Failed to select chat';
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendLocalMessage(String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty || isSending) {
      return;
    }

    try {
      if (currentConversation == null) {
        await createNewConversation();
      }

      Conversation baseConversation = currentConversation!;
      final DateTime now = DateTime.now();

      final ChatMessage userMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: baseConversation.id,
        role: ChatMessageRole.user,
        content: trimmed,
        createdAt: now,
      );
      await _chatRepository.insertMessage(userMessage);

      final String updatedTitle = baseConversation.title == 'New chat'
          ? _titleFromUserMessage(trimmed)
          : baseConversation.title;

      baseConversation = baseConversation.copyWith(
        title: updatedTitle,
        updatedAt: DateTime.now(),
      );

      await _chatRepository.upsertConversation(baseConversation);
      currentConversation = baseConversation;
      await _reloadConversations();

      messages = await _chatRepository.getMessages(baseConversation.id);
      notifyListeners();

      await _sendAssistantCompletion(
        conversation: baseConversation,
        completionMessages: _buildRequestMessages(messages),
      );

      await _reloadConversations();
      await selectConversation(baseConversation.id);
    } catch (_) {
      error = 'Failed to send message';
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> regenerateLastAssistantResponse() async {
    if (isSending) {
      return;
    }

    final Conversation? conversation = currentConversation;
    if (conversation == null) {
      error = 'Nothing to regenerate.';
      notifyListeners();
      return;
    }

    try {
      final List<ChatMessage> currentMessages = await _chatRepository.getMessages(
        conversation.id,
      );

      int assistantIndex = -1;
      for (int i = currentMessages.length - 1; i >= 0; i--) {
        if (currentMessages[i].role == ChatMessageRole.assistant) {
          assistantIndex = i;
          break;
        }
      }

      if (assistantIndex <= 0) {
        error = 'Nothing to regenerate.';
        notifyListeners();
        return;
      }

      int userIndex = -1;
      for (int i = assistantIndex - 1; i >= 0; i--) {
        if (currentMessages[i].role == ChatMessageRole.user) {
          userIndex = i;
          break;
        }
      }

      if (userIndex < 0) {
        error = 'Nothing to regenerate.';
        notifyListeners();
        return;
      }

      final ChatMessage lastAssistant = currentMessages[assistantIndex];
      await _chatRepository.deleteMessage(lastAssistant.id);

      final List<ChatMessage> refreshed = await _chatRepository.getMessages(
        conversation.id,
      );
      messages = refreshed;
      error = null;
      notifyListeners();

      final List<ChatMessage> historyUpToUser = refreshed
          .where((ChatMessage message) =>
              message.createdAt.isBefore(lastAssistant.createdAt) ||
              message.id == currentMessages[userIndex].id)
          .toList();

      await _sendAssistantCompletion(
        conversation: conversation,
        completionMessages: _buildRequestMessages(historyUpToUser),
      );

      await _reloadConversations();
      await selectConversation(conversation.id);
    } catch (_) {
      error = 'Failed to regenerate response';
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> editLastUserMessageAndResend(String newContent) async {
    if (isSending) {
      return;
    }

    final String trimmed = newContent.trim();
    if (trimmed.isEmpty) {
      error = 'Message cannot be empty.';
      notifyListeners();
      return;
    }

    final Conversation? conversation = currentConversation;
    if (conversation == null) {
      error = 'No user message to edit.';
      notifyListeners();
      return;
    }

    try {
      final List<ChatMessage> currentMessages = await _chatRepository.getMessages(
        conversation.id,
      );

      ChatMessage? latestUser;
      for (int i = currentMessages.length - 1; i >= 0; i--) {
        if (currentMessages[i].role == ChatMessageRole.user) {
          latestUser = currentMessages[i];
          break;
        }
      }

      if (latestUser == null) {
        error = 'No user message to edit.';
        notifyListeners();
        return;
      }

      await _chatRepository.updateMessageContent(latestUser.id, trimmed);
      await _chatRepository.deleteMessagesAfter(
        conversation.id,
        latestUser.createdAt,
      );

      final List<ChatMessage> refreshed = await _chatRepository.getMessages(
        conversation.id,
      );
      messages = refreshed;
      error = null;
      notifyListeners();

      await _sendAssistantCompletion(
        conversation: conversation,
        completionMessages: _buildRequestMessages(refreshed),
      );

      await _reloadConversations();
      await selectConversation(conversation.id);
    } catch (_) {
      error = 'Failed to edit and resend message';
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _chatRepository.deleteConversation(conversationId);
      await _reloadConversations();

      if (conversations.isNotEmpty) {
        await selectConversation(conversations.first.id);
      } else {
        messages = <ChatMessage>[];
        currentConversation = null;
        notifyListeners();
        await createNewConversation();
      }
    } catch (_) {
      error = 'Failed to delete chat';
      notifyListeners();
    }
  }

  Future<void> deleteAllConversations() async {
    try {
      await _chatRepository.deleteAllConversations();
      conversations = <Conversation>[];
      currentConversation = null;
      messages = <ChatMessage>[];
      notifyListeners();
      await createNewConversation();
    } catch (_) {
      error = 'Failed to delete all chats';
      notifyListeners();
    }
  }

  Future<List<ChatMessage>> getCurrentConversationMessagesForExport() async {
    final Conversation? conversation = currentConversation;
    if (conversation == null) {
      return <ChatMessage>[];
    }

    if (messages.isNotEmpty &&
        messages.every(
          (ChatMessage message) => message.conversationId == conversation.id,
        )) {
      return List<ChatMessage>.from(messages);
    }

    return _chatRepository.getMessages(conversation.id);
  }

  Future<void> _insertAssistantError(
    Conversation conversation,
    String text, {
    AIProvider? provider,
    String? modelId,
    int? responseTimeMs,
  }) async {
    final ChatMessage assistantMessage = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversation.id,
      role: ChatMessageRole.assistant,
      content: text,
      createdAt: DateTime.now(),
      modelId: modelId,
      providerId: provider?.id,
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      estimatedCost: 0,
      error: text,
    );

    await _chatRepository.insertMessage(assistantMessage);

    if (provider != null && modelId != null && modelId.trim().isNotEmpty) {
      await _statsRepository.insertUsageRecord(
        UsageRecord(
          id: _uuid.v4(),
          conversationId: conversation.id,
          messageId: assistantMessage.id,
          providerId: provider.id,
          modelId: modelId,
          createdAt: DateTime.now(),
          promptTokens: 0,
          completionTokens: 0,
          totalTokens: 0,
          estimatedCost: 0,
          currencyCode: provider.currencyCode,
          responseTimeMs: responseTimeMs,
          error: text,
        ),
      );
    }

    await _chatRepository.upsertConversation(
      conversation.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<void> _sendAssistantCompletion({
    required Conversation conversation,
    required List<ChatCompletionMessage> completionMessages,
  }) async {
    final String apiKey = _settingsController.apiKey.trim();
    final String? selectedModelId = _settingsController
        .settings
        .selectedModelId
        ?.trim();
    final AIProvider? provider = _resolveProvider();

    if (provider == null) {
      await _insertAssistantError(
        conversation,
        'Error: Provider is not configured. Select OpenRouter or VSEGPT in settings.',
      );
      return;
    }

    if (apiKey.isEmpty) {
      await _insertAssistantError(
        conversation,
        'Error: API key is missing. Set it in settings.',
        provider: provider,
        modelId: selectedModelId,
      );
      return;
    }

    if (selectedModelId == null || selectedModelId.isEmpty) {
      await _insertAssistantError(
        conversation,
        'Error: Model ID is missing. Set it in settings.',
        provider: provider,
        modelId: selectedModelId,
      );
      return;
    }

    final ChatCompletionRequest request = ChatCompletionRequest(
      model: selectedModelId,
      messages: completionMessages,
      temperature: _settingsController.settings.modelParameters.temperature,
      maxTokens: _settingsController.settings.modelParameters.maxTokens,
      topP: _settingsController.settings.modelParameters.topP,
      frequencyPenalty:
          _settingsController.settings.modelParameters.frequencyPenalty,
      presencePenalty:
          _settingsController.settings.modelParameters.presencePenalty,
      stream: false,
    );

    isSending = true;
    error = null;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final ChatCompletionResponse response = await _aiClient.createChatCompletion(
        provider: provider,
        apiKey: apiKey,
        request: request,
      );
      stopwatch.stop();

      final ChatMessage assistantMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: conversation.id,
        role: ChatMessageRole.assistant,
        content: response.content,
        createdAt: DateTime.now(),
        modelId: response.model ?? selectedModelId,
        providerId: response.providerId ?? provider.id,
        promptTokens: response.promptTokens,
        completionTokens: response.completionTokens,
        totalTokens: response.totalTokens,
        estimatedCost: 0,
        error: null,
      );

      await _chatRepository.insertMessage(assistantMessage);

      await _statsRepository.insertUsageRecord(
        UsageRecord(
          id: _uuid.v4(),
          conversationId: conversation.id,
          messageId: assistantMessage.id,
          providerId: response.providerId ?? provider.id,
          modelId: response.model ?? selectedModelId,
          createdAt: DateTime.now(),
          promptTokens: response.promptTokens ?? 0,
          completionTokens: response.completionTokens ?? 0,
          totalTokens: response.totalTokens ?? 0,
          estimatedCost: 0,
          currencyCode: provider.currencyCode,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          error: null,
        ),
      );

      await _chatRepository.upsertConversation(
        conversation.copyWith(updatedAt: DateTime.now()),
      );
    } catch (e) {
      stopwatch.stop();

      final String safeError = e is AppException
          ? e.message
          : 'Failed to get response from provider';

      await _insertAssistantError(
        conversation,
        'Error: $safeError',
        provider: provider,
        modelId: selectedModelId,
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } finally {
      isSending = false;
    }
  }

  AIProvider? _resolveProvider() {
    final AIProvider? detected = _settingsController.detectedProvider;
    if (detected != null) {
      return detected;
    }

    final String? selectedProviderId =
        _settingsController.settings.selectedProviderId;
    return switch (selectedProviderId) {
      'openrouter' => AIProvider.openRouter,
      'vsegpt' => AIProvider.vsegpt,
      _ => null,
    };
  }

  List<ChatCompletionMessage> _buildRequestMessages(
    List<ChatMessage> conversationMessages,
  ) {
    final List<ChatCompletionMessage> requestMessages =
        <ChatCompletionMessage>[];

    final String systemPrompt = _settingsController.settings.systemPrompt
        .trim();
    if (systemPrompt.isNotEmpty) {
      requestMessages.add(
        ChatCompletionMessage(role: 'system', content: systemPrompt),
      );
    }

    for (final ChatMessage message in conversationMessages) {
      if (message.error != null) {
        continue;
      }

      final String? role = switch (message.role) {
        ChatMessageRole.user => 'user',
        ChatMessageRole.assistant => 'assistant',
        ChatMessageRole.system => null,
      };

      if (role != null) {
        requestMessages.add(
          ChatCompletionMessage(role: role, content: message.content),
        );
      }
    }

    return requestMessages;
  }

  Future<void> _reloadConversations() async {
    conversations = await _chatRepository.getConversations();
  }

  String _titleFromUserMessage(String content) {
    if (content.length <= 40) {
      return content;
    }

    return '${content.substring(0, 40)}...';
  }
}
