import 'package:aichatcline/app/app_theme.dart';
import 'package:aichatcline/features/chat/ui/chat_screen.dart';
import 'package:flutter/material.dart';

class AIChatApp extends StatelessWidget {
  const AIChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const ChatScreen(),
    );
  }
}