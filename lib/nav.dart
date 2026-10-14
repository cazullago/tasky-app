import 'package:flutter/material.dart';

/// Navigation callbacks passed down to tab screens.
class TaskyNav {
  final void Function(int tab) goTab;
  final void Function(String toolId) openTool;
  final void Function(String prefill) askAssistant;

  const TaskyNav({
    required this.goTab,
    required this.openTool,
    required this.askAssistant,
  });
}

/// Opens a full-screen tool page.
void openToolPage(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}
