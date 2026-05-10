import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.controller,
    required this.modelCatalogController,
    required this.exportService,
    required this.shareService,
    required this.providerName,
    this.appLogger,
    this.selectedModelId,
    this.onOpenSettings,
    this.onOpenStatistics,
  });

  final ChatController controller;
  final ModelCatalogController modelCatalogController;
  final ExportService exportService;
  final ShareService shareService;
  final String providerName;
  final AppLogger? appLogger;
  final String? selectedModelId;

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

      final file = await widget.shareService.saveExportFileWithPicker(
        fileName: fileName,
        content: content,
      );

      if (file == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
        return;
      }

      if (!mounted) {
        return;
      }

      if (widget.appLogger != null) {
        await widget.appLogger!.logInfo(
          category: 'export',
          message: 'Conversation export succeeded',
          metadata: <String, dynamic>{
            'conversationId': conversation.id,
            'format': selectedFormat.name,
            'path': file.path,
          },
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export saved: ${file.path}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      if (widget.appLogger != null) {
        await widget.appLogger!.logError(
          category: 'export',
          message: 'Conversation export failed',
          metadata: <String, dynamic>{
            'conversationId': conversation.id,
            'format': selectedFormat.name,
            'errorType': e.runtimeType.toString(),
            'error': e.toString(),
          },
        );
      }

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
    widget.modelCatalogController.addListener(_onCatalogChanged);
  }

  @override
  void dispose() {
    widget.modelCatalogController.removeListener(_onCatalogChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onCatalogChanged() {
    if (mounted) {
      setState(() {});
    }
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

  Future<void> _openEditLastMessageDialog() async {
    final ChatMessage? lastUser = widget.controller.lastUserMessage;
    if (lastUser == null) {
      return;
    }

    final TextEditingController controller = TextEditingController(
      text: lastUser.content,
    );

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit last user message'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Edit your message...',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save & resend'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true) {
      await widget.controller.editLastUserMessageAndResend(controller.text);
    }

    controller.dispose();
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
                    onPressed: widget.controller.isStreaming
                        ? null
                        : () async {
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
                          onPressed: widget.controller.isStreaming
                              ? null
                              : () async {
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
        final Conversation? currentConversation =
            widget.controller.currentConversation;
        final String? conversationModelId =
            currentConversation?.selectedModelId?.trim();
        final String? conversationProviderId =
            currentConversation?.providerId?.trim();

        final String providerStatusText =
            (conversationProviderId != null && conversationProviderId.isNotEmpty)
            ? conversationProviderId
            : widget.providerName;

        final String modelStatusText = () {
          if (conversationModelId != null && conversationModelId.isNotEmpty) {
            return conversationModelId;
          }

          return 'No model selected for this chat';
        }();

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
                        isStreaming: widget.controller.isStreaming,
                        showCompactNewChat: !isWide,
                        onEditLastMessage: _openEditLastMessageDialog,
                        onRegenerateLastResponse:
                            widget.controller.regenerateLastAssistantResponse,
                        onDeleteCurrentConversation:
                            _confirmAndDeleteCurrentConversation,
                        onDeleteAllConversations:
                            _confirmAndDeleteAllConversations,
                      ),
                      _ProviderModelStatusBar(
                        providerName: providerStatusText,
                        modelStatusText: modelStatusText,
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
                          streamingMessageId: widget.controller.streamingMessageId,
                        ),
                      ),
                      _ChatInputBar(
                        controller: _messageController,
                        onSend: _send,
                        onStop: widget.controller.stopGeneration,
                        isSending: widget.controller.isSending,
                        isStreaming: widget.controller.isStreaming,
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
    required this.isStreaming,
    required this.showCompactNewChat,
    required this.onEditLastMessage,
    required this.onRegenerateLastResponse,
    required this.onDeleteCurrentConversation,
    required this.onDeleteAllConversations,
  });

  final ChatController controller;
  final bool isStreaming;
  final bool showCompactNewChat;
  final Future<void> Function() onEditLastMessage;
  final Future<void> Function() onRegenerateLastResponse;
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
              onPressed: isStreaming ? null : controller.createNewConversation,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('New chat'),
            ),
          FilledButton.tonalIcon(
            onPressed: controller.isSending || isStreaming
                ? null
                : onRegenerateLastResponse,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate'),
          ),
          FilledButton.tonalIcon(
            onPressed:
                controller.isSending ||
                    isStreaming ||
                    controller.lastUserMessage == null
                ? null
                : onEditLastMessage,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit last'),
          ),
          FilledButton.tonalIcon(
            onPressed: controller.currentConversation == null || isStreaming
                ? null
                : onDeleteCurrentConversation,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete current'),
          ),
          OutlinedButton.icon(
            onPressed: isStreaming ? null : onDeleteAllConversations,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Delete all'),
          ),
        ],
      ),
    );
  }
}

class _ProviderModelStatusBar extends StatelessWidget {
  const _ProviderModelStatusBar({
    required this.providerName,
    required this.modelStatusText,
  });

  final String providerName;
  final String modelStatusText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Provider: $providerName  •  Model: $modelStatusText',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
                onPressed: controller.isStreaming
                    ? null
                    : controller.createNewConversation,
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
                    onPressed: controller.isStreaming
                        ? null
                        : () => onDeleteConversation(conversation.id),
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
  const _MessageList({
    required this.messages,
    required this.isLoading,
    required this.streamingMessageId,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? streamingMessageId;

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
        final bool isStreamingAssistantMessage =
            !isUser && streamingMessageId == message.id;

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
                if (isUser)
                  Text(message.content)
                else
                  _AssistantMessageContent(
                    content: message.content,
                    isStreaming: isStreamingAssistantMessage,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssistantMessageContent extends StatelessWidget {
  const _AssistantMessageContent({
    required this.content,
    required this.isStreaming,
  });

  final String content;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isStreaming) {
      return Text(content);
    }

    final List<_AssistantMessageSegment> segments =
        _parseAssistantMessageSegments(content);

    if (segments.isEmpty) {
      return Text(content);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (segments[i].isCode)
            _AssistantCodeBlock(
              code: segments[i].content,
              language: segments[i].language,
            )
          else
            MarkdownBody(
              data: segments[i].content,
              shrinkWrap: true,
              selectable: true,
            ),
          if (i < segments.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AssistantCodeBlock extends StatelessWidget {
  const _AssistantCodeBlock({required this.code, this.language});

  final String code;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final String trimmedLanguage = language?.trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trimmedLanguage.isEmpty ? 'Code' : trimmedLanguage,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Copy code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              code,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageSegment {
  const _AssistantMessageSegment.markdown(this.content)
    : isCode = false,
      language = null;

  const _AssistantMessageSegment.code(this.content, {this.language})
    : isCode = true;

  final bool isCode;
  final String content;
  final String? language;
}

List<_AssistantMessageSegment> _parseAssistantMessageSegments(String content) {
  final List<_AssistantMessageSegment> segments =
      <_AssistantMessageSegment>[];
  final List<String> lines = content.split('\n');

  StringBuffer markdownBuffer = StringBuffer();
  StringBuffer codeBuffer = StringBuffer();
  bool inCodeBlock = false;
  String? codeLanguage;
  String? unclosedFenceHeader;

  void flushMarkdown() {
    final String markdownText = markdownBuffer.toString();
    if (markdownText.trim().isNotEmpty) {
      segments.add(_AssistantMessageSegment.markdown(markdownText));
    }
    markdownBuffer = StringBuffer();
  }

  for (final String line in lines) {
    final String trimmedLeft = line.trimLeft();
    if (trimmedLeft.startsWith('```')) {
      if (!inCodeBlock) {
        flushMarkdown();
        inCodeBlock = true;
        codeLanguage = trimmedLeft.substring(3).trim();
        if (codeLanguage.isEmpty) {
          codeLanguage = null;
        }
        unclosedFenceHeader = line;
        codeBuffer = StringBuffer();
      } else {
        segments.add(
          _AssistantMessageSegment.code(
            _trimTrailingLineBreak(codeBuffer.toString()),
            language: codeLanguage,
          ),
        );
        inCodeBlock = false;
        codeLanguage = null;
        unclosedFenceHeader = null;
        codeBuffer = StringBuffer();
      }
      continue;
    }

    if (inCodeBlock) {
      codeBuffer.writeln(line);
    } else {
      markdownBuffer.writeln(line);
    }
  }

  if (inCodeBlock) {
    markdownBuffer.writeln(unclosedFenceHeader ?? '```');
    markdownBuffer.write(codeBuffer.toString());
  }

  flushMarkdown();
  return segments;
}

String _trimTrailingLineBreak(String value) {
  String trimmed = value;
  while (trimmed.endsWith('\n') || trimmed.endsWith('\r')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.isSending,
    required this.isStreaming,
  });

  final TextEditingController controller;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;
  final bool isSending;
  final bool isStreaming;

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
          if (isStreaming)
            FilledButton.tonal(
              onPressed: onStop,
              child: const Text('Stop'),
            )
          else
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
