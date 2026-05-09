import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class ChatController extends ChangeNotifier {
  ChatController({required ChatRepository chatRepository})
    : _chatRepository = chatRepository;

  final ChatRepository _chatRepository;
  final Uuid _uuid = const Uuid();

  List<Conversation> conversations = <Conversation>[];
  Conversation? currentConversation;
  List<ChatMessage> messages = <ChatMessage>[];
  bool isLoading = false;
  String? error;

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
    if (trimmed.isEmpty) {
      return;
    }

    try {
      if (currentConversation == null) {
        await createNewConversation();
      }

      final Conversation baseConversation = currentConversation!;
      final DateTime now = DateTime.now();

      final ChatMessage userMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: baseConversation.id,
        role: ChatMessageRole.user,
        content: trimmed,
        createdAt: now,
      );

      await _chatRepository.insertMessage(userMessage);

      final ChatMessage assistantMessage = ChatMessage(
        id: _uuid.v4(),
        conversationId: baseConversation.id,
        role: ChatMessageRole.assistant,
        content:
            'This is a local placeholder response. API integration is not implemented yet.',
        createdAt: DateTime.now(),
      );

      await _chatRepository.insertMessage(assistantMessage);

      final String updatedTitle = baseConversation.title == 'New chat'
          ? _titleFromUserMessage(trimmed)
          : baseConversation.title;

      final Conversation updatedConversation = baseConversation.copyWith(
        title: updatedTitle,
        updatedAt: DateTime.now(),
      );

      await _chatRepository.upsertConversation(updatedConversation);
      await _reloadConversations();
      await selectConversation(updatedConversation.id);
    } catch (_) {
      error = 'Failed to send local message';
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
