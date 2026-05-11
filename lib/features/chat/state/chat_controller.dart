import 'dart:async';

import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required ChatRepository chatRepository,
    required SettingsController settingsController,
    required ModelCatalogController modelCatalogController,
    required OpenAICompatibleClient aiClient,
    required StatsRepository statsRepository,
    AppLogger? appLogger,
    Future<void> Function()? onAssistantResponseCompleted,
  }) : _chatRepository = chatRepository,
       _settingsController = settingsController,
       _modelCatalogController = modelCatalogController,
       _aiClient = aiClient,
       _statsRepository = statsRepository,
       _appLogger = appLogger,
       _onAssistantResponseCompleted = onAssistantResponseCompleted;

  final ChatRepository _chatRepository;
  final SettingsController _settingsController;
  final ModelCatalogController _modelCatalogController;
  final OpenAICompatibleClient _aiClient;
  final StatsRepository _statsRepository;
  final AppLogger? _appLogger;
  final Future<void> Function()? _onAssistantResponseCompleted;
  final Uuid _uuid = const Uuid();

  List<Conversation> conversations = <Conversation>[];
  Conversation? currentConversation;
  List<ChatMessage> messages = <ChatMessage>[];
  bool isLoading = false;
  bool isSending = false;
  bool isStreaming = false;
  String? streamingMessageId;
  String? error;

  StreamSubscription<ChatCompletionStreamChunk>? _activeStreamSubscription;
  Future<void> Function()? _activeStreamFinalize;
  bool _stopStreamingRequested = false;

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

      await ensureCurrentConversationHasDefaultModel();
    } catch (_) {
      error = 'Failed to load chats';
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    try {
      final DateTime now = DateTime.now();
      final String? selectedModelId = _settingsController
          .settings
          .selectedModelId
          ?.trim();
      final String? resolvedProviderId =
          _settingsController.detectedProvider?.id ??
          _settingsController.settings.selectedProviderId?.trim();
      final Conversation conversation = Conversation(
        id: _uuid.v4(),
        title: 'New chat',
        createdAt: now,
        updatedAt: now,
        selectedModelId: (selectedModelId == null || selectedModelId.isEmpty)
            ? null
            : selectedModelId,
        providerId: (resolvedProviderId == null || resolvedProviderId.isEmpty)
            ? null
            : resolvedProviderId,
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

  Future<void> ensureCurrentConversationHasDefaultModel() async {
    final Conversation? conversation = currentConversation;
    if (conversation == null) {
      return;
    }

    final List<ChatMessage> currentMessages = messages.isNotEmpty
        ? messages
        : await _chatRepository.getMessages(conversation.id);
    if (currentMessages.isNotEmpty) {
      return;
    }

    final String? currentModel = conversation.selectedModelId?.trim();
    final String? currentProvider = conversation.providerId?.trim();
    if ((currentModel?.isNotEmpty ?? false) &&
        (currentProvider?.isNotEmpty ?? false)) {
      return;
    }

    final String? defaultModel = _settingsController.settings.selectedModelId
        ?.trim();
    final String? detectedProviderId = _settingsController.detectedProvider?.id;
    final String? selectedProviderId = _settingsController
        .settings
        .selectedProviderId
        ?.trim();

    final String? nextModel = (currentModel != null && currentModel.isNotEmpty)
        ? currentModel
        : ((defaultModel != null && defaultModel.isNotEmpty)
              ? defaultModel
              : null);
    final String? nextProvider =
        (currentProvider != null && currentProvider.isNotEmpty)
        ? currentProvider
        : ((detectedProviderId != null && detectedProviderId.isNotEmpty)
              ? detectedProviderId
              : ((selectedProviderId != null && selectedProviderId.isNotEmpty)
                    ? selectedProviderId
                    : null));

    if ((nextModel == null || nextModel.isEmpty) &&
        (nextProvider == null || nextProvider.isEmpty)) {
      return;
    }

    final Conversation updated = conversation.copyWith(
      selectedModelId: nextModel,
      providerId: nextProvider,
      updatedAt: DateTime.now(),
    );
    await _chatRepository.upsertConversation(updated);
    currentConversation = updated;
    await _reloadConversations();
    notifyListeners();
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
      await _afterAssistantResponseCompleted();
    } catch (_) {
      error = 'Failed to send message';
      isSending = false;
      notifyListeners();
    }
  }

  Future<void> stopGeneration() async {
    if (!isStreaming) {
      return;
    }

    await _appLogger?.logInfo(
      category: 'chat',
      message: 'Streaming stopped by user',
    );

    _stopStreamingRequested = true;

    final StreamSubscription<ChatCompletionStreamChunk>? subscription =
        _activeStreamSubscription;
    _activeStreamSubscription = null;
    await subscription?.cancel();

    final Future<void> Function()? finalize = _activeStreamFinalize;
    if (finalize != null) {
      await finalize();
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
      final List<ChatMessage> currentMessages = await _chatRepository
          .getMessages(conversation.id);

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
          .where(
            (ChatMessage message) =>
                message.createdAt.isBefore(lastAssistant.createdAt) ||
                message.id == currentMessages[userIndex].id,
          )
          .toList();

      await _sendAssistantCompletion(
        conversation: conversation,
        completionMessages: _buildRequestMessages(historyUpToUser),
        forceNonStreaming: true,
      );

      await _reloadConversations();
      await selectConversation(conversation.id);
      await _afterAssistantResponseCompleted();
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
      final List<ChatMessage> currentMessages = await _chatRepository
          .getMessages(conversation.id);

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
        forceNonStreaming: true,
      );

      await _reloadConversations();
      await selectConversation(conversation.id);
      await _afterAssistantResponseCompleted();
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

    final String currencyCode = _resolveCurrencyCode(
      modelId: modelId,
      provider: provider,
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
          currencyCode: currencyCode,
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
    bool forceNonStreaming = false,
  }) async {
    final String apiKey = _settingsController.apiKey.trim();
    final String? selectedModelId = _resolveModelIdForCurrentConversation(
      conversation,
    );
    final AIProvider? provider = _resolveProviderForCurrentConversation(
      conversation,
    );

    if (provider == null) {
      await _appLogger?.logWarning(
        category: 'chat',
        message: 'Chat request failed: provider is not configured',
      );
      await _insertAssistantError(
        conversation,
        'Error: Provider is not configured. Select OpenRouter or VSEGPT in settings.',
      );
      return;
    }

    if (apiKey.isEmpty) {
      await _appLogger?.logWarning(
        category: 'chat',
        message: 'Chat request failed: API key is missing',
      );
      await _insertAssistantError(
        conversation,
        'Error: API key is missing. Set it in settings.',
        provider: provider,
        modelId: selectedModelId,
      );
      return;
    }

    if (selectedModelId == null || selectedModelId.isEmpty) {
      await _appLogger?.logWarning(
        category: 'chat',
        message: 'Chat request failed: model is not selected',
      );
      await _insertAssistantError(
        conversation,
        'No model selected for this conversation. Choose a model for this chat or set a default model before creating a new chat.',
        provider: provider,
        modelId: selectedModelId,
      );
      return;
    }

    final bool shouldStream =
        _settingsController.settings.modelParameters.streamingEnabled &&
        !forceNonStreaming;

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
      stream: shouldStream,
    );

    final String? lastUserMessageSnippet = _lastUserMessageSnippet(
      completionMessages,
    );
    final String? systemPromptSnippet = _systemPromptSnippet(
      completionMessages,
    );

    final Map<String, dynamic> requestStartMetadata = <String, dynamic>{
      'providerId': provider.id,
      'modelId': selectedModelId,
      'streaming': shouldStream,
      'messagesCount': completionMessages.length,
    };
    _addSnippetIfPresent(
      requestStartMetadata,
      'lastUserMessageSnippet',
      lastUserMessageSnippet,
    );
    _addSnippetIfPresent(
      requestStartMetadata,
      'systemPromptSnippet',
      systemPromptSnippet,
    );

    await _appLogger?.logInfo(
      category: 'api',
      message: 'Chat request started',
      metadata: requestStartMetadata,
    );

    if (shouldStream) {
      await _sendAssistantCompletionStreaming(
        conversation: conversation,
        provider: provider,
        apiKey: apiKey,
        selectedModelId: selectedModelId,
        request: request,
      );
      return;
    }

    isSending = true;
    error = null;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();

    try {
      final ChatCompletionResponse response = await _aiClient
          .createChatCompletion(
            provider: provider,
            apiKey: apiKey,
            request: request,
          );
      stopwatch.stop();

      final String usageModelId = response.model ?? selectedModelId;
      final int promptTokens = response.promptTokens ?? 0;
      final int completionTokens = response.completionTokens ?? 0;
      final double estimatedCost = _calculateEstimatedCost(
        modelId: usageModelId,
        promptTokens: promptTokens,
        completionTokens: completionTokens,
      );

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
        estimatedCost: estimatedCost,
        error: null,
      );

      await _chatRepository.insertMessage(assistantMessage);

      final String currencyCode = _resolveCurrencyCode(
        modelId: usageModelId,
        provider: provider,
      );

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
          estimatedCost: estimatedCost,
          currencyCode: currencyCode,
          responseTimeMs: stopwatch.elapsedMilliseconds,
          error: null,
        ),
      );

      await _chatRepository.upsertConversation(
        conversation.copyWith(updatedAt: DateTime.now()),
      );

      await _appLogger?.logInfo(
        category: 'api',
        message: 'Chat request succeeded',
        metadata: <String, dynamic>{
          'providerId': provider.id,
          'modelId': response.model ?? selectedModelId,
          'streaming': false,
          'promptTokens': response.promptTokens ?? 0,
          'completionTokens': response.completionTokens ?? 0,
          'totalTokens': response.totalTokens ?? 0,
          'responseTimeMs': stopwatch.elapsedMilliseconds,
          'estimatedCost': estimatedCost,
          'currencyCode': currencyCode,
          if (_snippetEnabled)
            'assistantResponseSnippet': _snippetOrNull(response.content),
        },
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

      await _appLogger?.logError(
        category: 'api',
        message: 'Chat request failed',
        metadata: <String, dynamic>{
          'providerId': provider.id,
          'modelId': selectedModelId,
          'streaming': false,
          'error': safeError,
          'errorType': e.runtimeType.toString(),
          'responseTimeMs': stopwatch.elapsedMilliseconds,
          if (_snippetEnabled)
            'lastUserMessageSnippet': _lastUserMessageSnippet(
              completionMessages,
            ),
        },
      );
    } finally {
      isSending = false;
      isStreaming = false;
      streamingMessageId = null;
      _stopStreamingRequested = false;
      notifyListeners();
    }
  }

  Future<void> _sendAssistantCompletionStreaming({
    required Conversation conversation,
    required AIProvider provider,
    required String apiKey,
    required String selectedModelId,
    required ChatCompletionRequest request,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();

    ChatMessage assistantDraft = ChatMessage(
      id: _uuid.v4(),
      conversationId: conversation.id,
      role: ChatMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
      modelId: selectedModelId,
      providerId: provider.id,
      promptTokens: 0,
      completionTokens: 0,
      totalTokens: 0,
      estimatedCost: 0,
      error: null,
    );

    messages = List<ChatMessage>.from(messages)..add(assistantDraft);

    isSending = true;
    isStreaming = true;
    streamingMessageId = assistantDraft.id;
    error = null;
    _stopStreamingRequested = false;
    notifyListeners();

    String resolvedModelId = selectedModelId;
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;
    bool finalized = false;
    final Completer<void> doneCompleter = Completer<void>();

    Future<void> finalize({String? errorText}) async {
      if (finalized) {
        return;
      }
      finalized = true;

      _activeStreamFinalize = null;
      final StreamSubscription<ChatCompletionStreamChunk>? subscription =
          _activeStreamSubscription;
      _activeStreamSubscription = null;
      await subscription?.cancel();

      if (stopwatch.isRunning) {
        stopwatch.stop();
      }

      final int responseTimeMs = stopwatch.elapsedMilliseconds;
      final bool hasUsage =
          promptTokens != null ||
          completionTokens != null ||
          totalTokens != null;

      final int finalPromptTokens = promptTokens ?? 0;
      final int finalCompletionTokens = completionTokens ?? 0;
      final int finalTotalTokens =
          totalTokens ?? (finalPromptTokens + finalCompletionTokens);

      final double estimatedCost = hasUsage
          ? _calculateEstimatedCost(
              modelId: resolvedModelId,
              promptTokens: finalPromptTokens,
              completionTokens: finalCompletionTokens,
            )
          : 0;

      final String currencyCode = _resolveCurrencyCode(
        modelId: resolvedModelId,
        provider: provider,
      );

      final String? normalizedError =
          (errorText == null || errorText.trim().isEmpty)
          ? null
          : errorText.trim();

      String finalContent = assistantDraft.content;
      if (normalizedError != null) {
        finalContent = finalContent.trim().isEmpty
            ? 'Error: $normalizedError'
            : '$finalContent\n\nError: $normalizedError';
      }

      assistantDraft = assistantDraft.copyWith(
        content: finalContent,
        modelId: resolvedModelId,
        providerId: provider.id,
        promptTokens: hasUsage ? finalPromptTokens : 0,
        completionTokens: hasUsage ? finalCompletionTokens : 0,
        totalTokens: hasUsage ? finalTotalTokens : 0,
        estimatedCost: hasUsage ? estimatedCost : 0,
        error: normalizedError,
      );

      try {
        _replaceMessageInMemory(assistantDraft);

        await _chatRepository.insertMessage(assistantDraft);

        await _statsRepository.insertUsageRecord(
          UsageRecord(
            id: _uuid.v4(),
            conversationId: conversation.id,
            messageId: assistantDraft.id,
            providerId: provider.id,
            modelId: resolvedModelId,
            createdAt: DateTime.now(),
            promptTokens: hasUsage ? finalPromptTokens : 0,
            completionTokens: hasUsage ? finalCompletionTokens : 0,
            totalTokens: hasUsage ? finalTotalTokens : 0,
            estimatedCost: hasUsage ? estimatedCost : 0,
            currencyCode: currencyCode,
            responseTimeMs: responseTimeMs,
            error: normalizedError,
          ),
        );

        await _chatRepository.upsertConversation(
          conversation.copyWith(updatedAt: DateTime.now()),
        );

        if (normalizedError == null) {
          final String? assistantSnippet = _snippetOrNull(finalContent);
          await _appLogger?.logInfo(
            category: 'api',
            message: 'Chat request succeeded',
            metadata: <String, dynamic>{
              'providerId': provider.id,
              'modelId': resolvedModelId,
              'streaming': true,
              'promptTokens': hasUsage ? finalPromptTokens : 0,
              'completionTokens': hasUsage ? finalCompletionTokens : 0,
              'totalTokens': hasUsage ? finalTotalTokens : 0,
              'responseTimeMs': responseTimeMs,
              'estimatedCost': hasUsage ? estimatedCost : 0,
              'currencyCode': currencyCode,
              if (_snippetEnabled) 'assistantResponseSnippet': assistantSnippet,
            },
          );
        } else {
          await _appLogger?.logError(
            category: 'api',
            message: 'Chat request failed',
            metadata: <String, dynamic>{
              'providerId': provider.id,
              'modelId': resolvedModelId,
              'streaming': true,
              'error': normalizedError,
              'responseTimeMs': responseTimeMs,
              if (_snippetEnabled)
                'lastUserMessageSnippet': _lastUserMessageSnippet(
                  request.messages,
                ),
            },
          );
        }
      } catch (_) {
        error = 'Failed to finalize streamed response';
      } finally {
        isStreaming = false;
        streamingMessageId = null;
        isSending = false;
        _stopStreamingRequested = false;
        notifyListeners();

        if (!doneCompleter.isCompleted) {
          doneCompleter.complete();
        }
      }
    }

    _activeStreamFinalize = () => finalize();

    try {
      final Stream<ChatCompletionStreamChunk> stream = _aiClient
          .createChatCompletionStream(
            provider: provider,
            apiKey: apiKey,
            request: request,
          );

      _activeStreamSubscription = stream.listen(
        (ChatCompletionStreamChunk chunk) {
          if (_stopStreamingRequested) {
            unawaited(finalize());
            return;
          }

          final String? chunkModel = chunk.model?.trim();
          if (chunkModel != null && chunkModel.isNotEmpty) {
            resolvedModelId = chunkModel;
          }

          if (chunk.promptTokens != null) {
            promptTokens = chunk.promptTokens;
          }
          if (chunk.completionTokens != null) {
            completionTokens = chunk.completionTokens;
          }
          if (chunk.totalTokens != null) {
            totalTokens = chunk.totalTokens;
          }

          if (chunk.delta.isNotEmpty) {
            assistantDraft = assistantDraft.copyWith(
              content: '${assistantDraft.content}${chunk.delta}',
              modelId: resolvedModelId,
              providerId: provider.id,
            );
            _replaceMessageInMemory(assistantDraft);
            notifyListeners();
          }

          if (chunk.isDone) {
            unawaited(finalize());
          }
        },
        onError: (Object e, StackTrace stackTrace) {
          final String safeError = e is AppException
              ? e.message
              : 'Failed to get streamed response from provider';
          unawaited(finalize(errorText: safeError));
        },
        onDone: () {
          unawaited(finalize());
        },
        cancelOnError: false,
      );
    } catch (e) {
      final String safeError = e is AppException
          ? e.message
          : 'Failed to create streamed request';
      await finalize(errorText: safeError);
    }

    await doneCompleter.future;
  }

  Future<void> _afterAssistantResponseCompleted() async {
    try {
      await _onAssistantResponseCompleted?.call();
    } catch (_) {
      // Balance refresh failures must not break chat.
    }
  }

  void _replaceMessageInMemory(ChatMessage updatedMessage) {
    final int index = messages.indexWhere(
      (ChatMessage message) => message.id == updatedMessage.id,
    );
    if (index < 0) {
      return;
    }

    final List<ChatMessage> updatedMessages = List<ChatMessage>.from(messages);
    updatedMessages[index] = updatedMessage;
    messages = updatedMessages;
  }

  String? _resolveModelIdForCurrentConversation(Conversation conversation) {
    final String? conversationModelId = conversation.selectedModelId?.trim();
    if (conversationModelId == null || conversationModelId.isEmpty) {
      return null;
    }

    return conversationModelId;
  }

  AIProvider? _resolveProviderForCurrentConversation(
    Conversation conversation,
  ) {
    final String? conversationProviderId = conversation.providerId?.trim();
    final AIProvider? fromConversation = _providerFromId(
      conversationProviderId,
    );
    if (fromConversation != null) {
      return _withSettingsBaseUrlIfPresent(fromConversation);
    }

    final AIProvider? effective = _settingsController.effectiveProvider();
    if (effective != null) {
      return effective;
    }

    return null;
  }

  AIProvider? _providerFromId(String? providerId) {
    final String? normalized = providerId?.trim();
    return switch (normalized) {
      'openrouter' => AIProvider.openRouter,
      'vsegpt' => AIProvider.vsegpt,
      _ => null,
    };
  }

  AIProvider _withSettingsBaseUrlIfPresent(AIProvider provider) {
    final String? override = _settingsController.settings.baseUrl?.trim();
    if (override == null || override.isEmpty) {
      return provider;
    }

    return AIProvider(
      id: provider.id,
      name: provider.name,
      type: provider.type,
      baseUrl: override,
      apiKeyPrefix: provider.apiKeyPrefix,
      currencyCode: provider.currencyCode,
    );
  }

  double _calculateEstimatedCost({
    required String modelId,
    required int promptTokens,
    required int completionTokens,
  }) {
    final AIModel? model = _modelCatalogController.findModelById(modelId);
    final double? promptPrice = model?.promptPrice;
    final double? completionPrice = model?.completionPrice;

    if (promptPrice == null || completionPrice == null) {
      return 0;
    }

    return (promptTokens * promptPrice) + (completionTokens * completionPrice);
  }

  String _resolveCurrencyCode({
    required String? modelId,
    required AIProvider? provider,
  }) {
    final String? normalizedModelId = modelId?.trim();
    if (normalizedModelId != null && normalizedModelId.isNotEmpty) {
      final AIModel? model = _modelCatalogController.findModelById(
        normalizedModelId,
      );
      final String? modelCurrency = model?.currencyCode?.trim();
      if (modelCurrency != null && modelCurrency.isNotEmpty) {
        return modelCurrency;
      }
    }

    return provider?.currencyCode ?? 'USD';
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

  bool get _snippetEnabled {
    return _appLogger?.includeMessageContentInLogs ??
        _settingsController.settings.includeMessageContentInLogs;
  }

  String? _snippetOrNull(String value) {
    if (!_snippetEnabled) {
      return null;
    }

    return _appLogger?.buildMessageContentSnippet(value) ??
        _shortSnippet(value);
  }

  String _shortSnippet(String value) {
    final String compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 300) {
      return compact;
    }

    return '${compact.substring(0, 300)}...';
  }

  String? _lastUserMessageSnippet(List<ChatCompletionMessage> requestMessages) {
    if (!_snippetEnabled) {
      return null;
    }

    for (int i = requestMessages.length - 1; i >= 0; i--) {
      final ChatCompletionMessage message = requestMessages[i];
      if (message.role == 'user') {
        return _snippetOrNull(message.content);
      }
    }

    return null;
  }

  String? _systemPromptSnippet(List<ChatCompletionMessage> requestMessages) {
    if (!_snippetEnabled) {
      return null;
    }

    for (final ChatCompletionMessage message in requestMessages) {
      if (message.role == 'system' && message.content.trim().isNotEmpty) {
        return _snippetOrNull(message.content);
      }
    }

    return null;
  }

  void _addSnippetIfPresent(
    Map<String, dynamic> metadata,
    String key,
    String? snippet,
  ) {
    if (!_snippetEnabled) {
      return;
    }

    final String? value = snippet?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    metadata[key] = value;
  }
}
