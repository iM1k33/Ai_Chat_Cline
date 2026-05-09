import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.controller,
    required this.exportService,
    required this.shareService,
    this.onOpenSettings,
    this.onOpenStatistics,
  });

  final ChatController controller;
  final ExportService exportService;
  final ShareService shareService;

  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenStatistics;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _messageController;
  final DateFormat _conversationDateFormat = DateFormat('yyyy-MM-dd HH:mm');

  Future<void> _openExportDialog() async {
    final Conversation? conversation = widget.controller.currentConversation;
    if (conversation == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No current conversation to export.'),
        ),
      );
      return;
    }

    ExportFormat selectedFormat = ExportFormat.txt;
    bool includeMetadata = false;

    final bool? shouldExport = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: const Text('Export conversation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Format'),
                  const SizedBox(height: 8),
                  DropdownButton<ExportFormat>(
                    value: selectedFormat,
                    isExpanded: true,
                    items: const <DropdownMenuItem<ExportFormat>>[
                      DropdownMenuItem<ExportFormat>(
                        value: ExportFormat.txt,
                        child: Text('TXT'),
                      ),
                      DropdownMenuItem<ExportFormat>(
                        value: ExportFormat.markdown,
                        child: Text('Markdown'),
                      ),
                      DropdownMenuItem<ExportFormat>(
                        value: ExportFormat.json,
                        child: Text('JSON'),
                      ),
                    ],
                    onChanged: (ExportFormat? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedFormat = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include metadata'),
                    value: includeMetadata,
                    onChanged: (bool? value) {
                      setState(() {
                        includeMetadata = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldExport != true) {
      return;
    }

    try {
      final List<ChatMessage> exportMessages =
          await widget.controller.getCurrentConversationMessagesForExport();

      final String content = widget.exportService.buildConversationExport(
        conversation: conversation,
        messages: exportMessages,
        format: selectedFormat,
        usageRecords: const <UsageRecord>[],
        includeMetadata: includeMetadata,
      );

      final String fileName = widget.exportService.suggestedFileName(
        conversation,
        selectedFormat,
      );

      final file = await widget.shareService.saveExportFile(
        fileName: fileName,
        content: content,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export saved: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export conversation.'),
        ),
      );
    }
  }

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
    if (widget.controller.isSending) {
      return;
    }

    final String value = _messageController.text;
    await widget.controller.sendLocalMessage(value);
    if (value.trim().isNotEmpty) {
      _messageController.clear();
    }
  }

  Future<bool> _showDeleteCurrentConversationConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete conversation?'),
          content: const Text(
            'This will delete the current conversation and all its messages. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<bool> _showDeleteAllConversationsConfirmation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete all conversations?'),
          content: const Text(
            'This will delete all conversations and messages. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete all'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  Future<bool> _showDeleteConversationConfirmation() async {
    return _showDeleteCurrentConversationConfirmation();
  }

  Future<void> _confirmAndDeleteCurrentConversation() async {
    final Conversation? current = widget.controller.currentConversation;
    if (current == null) {
      return;
    }

    final bool confirmed = await _showDeleteCurrentConversationConfirmation();
    if (!confirmed) {
      return;
    }

    await widget.controller.deleteConversation(current.id);
  }

  Future<void> _confirmAndDeleteAllConversations() async {
    final bool confirmed = await _showDeleteAllConversationsConfirmation();
    if (!confirmed) {
      return;
    }

    await widget.controller.deleteAllConversations();
  }

  Future<void> _confirmAndDeleteConversationById(String conversationId) async {
    final bool confirmed = await _showDeleteConversationConfirmation();
    if (!confirmed) {
      return;
    }

    await widget.controller.deleteConversation(conversationId);
  }

  Future<void> _openConversationSwitcher() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  title: const Text('Conversations'),
                  trailing: IconButton(
                    tooltip: 'New chat',
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: () async {
                      Navigator.of(bottomSheetContext).pop();
                      await widget.controller.createNewConversation();
                    },
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.controller.conversations.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Conversation conversation =
                          widget.controller.conversations[index];
                      final bool isSelected =
                          widget.controller.currentConversation?.id ==
                          conversation.id;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Updated ${_conversationDateFormat.format(conversation.updatedAt)}',
                        ),
                        onTap: () async {
                          await widget.controller.selectConversation(
                            conversation.id,
                          );
                          if (bottomSheetContext.mounted) {
                            Navigator.of(bottomSheetContext).pop();
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Delete conversation',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final bool confirmed =
                                await _showDeleteConversationConfirmation();
                            if (!confirmed) {
                              return;
                            }

                            await widget.controller.deleteConversation(
                              conversation.id,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              if (!isWide)
                IconButton(
                  tooltip: 'Conversations',
                  icon: const Icon(Icons.menu),
                  onPressed: _openConversationSwitcher,
                ),
              IconButton(
                tooltip: 'Export conversation',
                icon: const Icon(Icons.download_outlined),
                onPressed: widget.controller.currentConversation == null
                    ? null
                    : _openExportDialog,
              ),
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
                    child: _ConversationSidebar(
                      controller: widget.controller,
                      onDeleteConversation: _confirmAndDeleteConversationById,
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _ActionBar(
                        controller: widget.controller,
                        showCompactNewChat: !isWide,
                        onDeleteCurrentConversation:
                            _confirmAndDeleteCurrentConversation,
                        onDeleteAllConversations:
                            _confirmAndDeleteAllConversations,
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
                        isSending: widget.controller.isSending,
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
    required this.onDeleteCurrentConversation,
    required this.onDeleteAllConversations,
  });

  final ChatController controller;
  final bool showCompactNewChat;
  final Future<void> Function() onDeleteCurrentConversation;
  final Future<void> Function() onDeleteAllConversations;

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
                : onDeleteCurrentConversation,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete current'),
          ),
          OutlinedButton.icon(
            onPressed: onDeleteAllConversations,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Delete all'),
          ),
        ],
      ),
    );
  }
}

class _ConversationSidebar extends StatelessWidget {
  const _ConversationSidebar({
    required this.controller,
    required this.onDeleteConversation,
  });

  final ChatController controller;
  final Future<void> Function(String conversationId) onDeleteConversation;

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
                    onPressed: () => onDeleteConversation(conversation.id),
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
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isSending ? null : onSend,
            child: isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }
}
