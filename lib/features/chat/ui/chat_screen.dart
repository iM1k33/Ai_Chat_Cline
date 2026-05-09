import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.controller,
    this.onOpenSettings,
    this.onOpenStatistics,
  });

  final ChatController controller;

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenStatistics;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String value = _messageController.text;
    await widget.controller.sendLocalMessage(value);
    if (value.trim().isNotEmpty) {
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final bool isWide = MediaQuery.of(context).size.width >= 800;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.controller.currentConversation?.title ?? 'AI Chat',
            ),
            actions: [
              IconButton(
                tooltip: 'Statistics',
                icon: const Icon(Icons.analytics_outlined),
                onPressed: widget.onOpenStatistics,
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: widget.onOpenSettings,
              ),
            ],
          ),
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 280,
                    child: _ConversationSidebar(controller: widget.controller),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _ActionBar(
                        controller: widget.controller,
                        showCompactNewChat: !isWide,
                      ),
                      if (widget.controller.error != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            widget.controller.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _MessageList(
                          messages: widget.controller.messages,
                          isLoading: widget.controller.isLoading,
                        ),
                      ),
                      _ChatInputBar(
                        controller: _messageController,
                        onSend: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.showCompactNewChat,
  });

  final ChatController controller;
  final bool showCompactNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (showCompactNewChat)
            FilledButton.tonalIcon(
              onPressed: controller.createNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New chat'),
            ),
          FilledButton.tonalIcon(
            onPressed: controller.currentConversation == null
                ? null
                : () => controller.deleteConversation(
                    controller.currentConversation!.id,
                  ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete current'),
          ),
          OutlinedButton.icon(
            onPressed: controller.deleteAllConversations,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Delete all'),
          ),
        ],
      ),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  const _ConversationSidebar({required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: controller.createNewConversation,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New chat'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.conversations.length,
              itemBuilder: (context, index) {
                final Conversation conversation =
                    controller.conversations[index];
                final bool isSelected =
                    controller.currentConversation?.id == conversation.id;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                  title: Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => controller.selectConversation(conversation.id),
                  trailing: IconButton(
                    tooltip: 'Delete conversation',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        controller.deleteConversation(conversation.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages, required this.isLoading});

  final List<ChatMessage> messages;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (messages.isEmpty) {
      return const Center(
        child: Text('No messages yet. Send a message to start this chat.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final ChatMessage message = messages[index];
        final bool isUser = message.role == ChatMessageRole.user;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isUser ? 'User' : 'Assistant',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy message',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: message.content),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Message copied to clipboard'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message.content),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onSend, child: const Text('Send')),
        ],
      ),
    );
  }
}
