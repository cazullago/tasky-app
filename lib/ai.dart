import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Result of an AI generation. [card] is an optional action card that the
/// UI renders with explicit confirm buttons — nothing is ever executed
/// automatically.
class AiReply {
  final String text;
  final ActionCard? card;
  final bool needsApiKey;

  AiReply(this.text, {this.card, this.needsApiKey = false});
}

class AiContext {
  final String userName;
  final List<TaskItem> tasks;
  AiContext({required this.userName, required this.tasks});
}

abstract class AiProvider {
  String get id;
  String get label;
  String get badge; // shown in UI, e.g. "Demo mode"
  Future<AiReply> generate(String prompt, AiContext ctx);
}

// ---------------------------------------------------------------------------
// Demo / on-device intent engine (default). Clearly labeled as demo.
// ---------------------------------------------------------------------------

class DemoAiEngine implements AiProvider {
  @override
  String get id => 'demo';
  @override
  String get label => 'Tasky Demo AI (on-device)';
  @override
  String get badge => 'Demo mode';

  @override
  Future<AiReply> generate(String prompt, AiContext ctx) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lower = prompt.toLowerCase().trim();

    if (lower.contains('remind me')) return _reminderIntent(prompt);
    if (_startsWithAny(lower, ['add task', 'create task', 'new task', 'todo:'])) {
      return _taskIntent(prompt);
    }
    if (lower.contains('email')) return _emailIntent(prompt, ctx);
    if (lower.startsWith('summarize')) return _summarizeIntent(prompt);
    if (lower.contains('organize') && lower.contains('table')) {
      return _organizeIntent(prompt);
    }
    if (_startsWithAny(lower, ['plan my', 'make a plan', 'create a plan']) ||
        lower.contains('itinerary') ||
        lower.contains('schedule for tomorrow') ||
        lower.contains('checklist for my trip')) {
      return _planIntent(prompt);
    }
    if (_startsWithAny(
            lower, ['find ', 'research ', 'search for ', 'look up ']) ||
        lower.contains('hotels in')) {
      return _researchIntent(prompt);
    }
    if (lower.contains('tiktok') ||
        lower.contains('content ideas') ||
        lower.contains('captions') ||
        lower.contains('hooks') ||
        lower.contains('script')) {
      return _contentIntent(prompt);
    }
    if (lower.contains('delete ') || lower.contains('remove ')) {
      return _deleteIntent(prompt, ctx);
    }
    return _fallback(ctx);
  }

  bool _startsWithAny(String s, List<String> prefixes) =>
      prefixes.any((p) => s.startsWith(p));

  // ---- reminder intent ----

  AiReply _reminderIntent(String prompt) {
    final parsed = _parseReminder(prompt);
    final title = parsed['title'] as String;
    final recurrence = parsed['recurrence'] as String;
    final date = parsed['date'] as DateTime;
    final time = parsed['time'] as String;

    final tmp = TaskItem(id: 'tmp', title: title, dueDate: date);
    tmp.recurrence = recurrence;
    final lines = <String>[
      title,
      tmp.recurrenceLabel(),
      _fmtDate(date),
      _fmtTime(time),
    ];
    return AiReply(
      'I can create ${_recurrencePhrase(recurrence)} reminder for you.',
      card: ActionCard(
        kind: 'reminder',
        title: title,
        lines: lines,
        confirmLabel: 'Confirm Reminder',
        payload: {
          'title': title,
          'recurrence': recurrence,
          'date': date.toIso8601String(),
          'time': time,
        },
      ),
    );
  }

  String _recurrencePhrase(String r) =>
      r == 'none' ? 'a' : r == 'daily' ? 'a daily' : 'a $r';

  Map<String, dynamic> _parseReminder(String prompt) {
    var rest = prompt;
    final idx = prompt.toLowerCase().indexOf('remind me to');
    if (idx >= 0) rest = prompt.substring(idx + 'remind me to'.length).trim();

    String recurrence = 'none';
    final lower = rest.toLowerCase();
    if (lower.contains('every day') || lower.contains('daily')) {
      recurrence = 'daily';
    } else if (lower.contains('every week') || lower.contains('weekly')) {
      recurrence = 'weekly';
    } else if (lower.contains('every month') ||
        lower.contains('monthly') ||
        RegExp(r'on the \d{1,2}(st|nd|rd|th)').hasMatch(lower)) {
      recurrence = 'monthly';
    }
    // strip recurrence words from the title
    rest = rest.replaceAll(
        RegExp(r'\s*(every day|every week|every month|daily|weekly|monthly)\.?',
            caseSensitive: false),
        '');
    rest = rest.replaceAll(
        RegExp(r'\s*on the \d{1,2}(st|nd|rd|th).*', caseSensitive: false), '');

    // time: 9am / 9:30 pm / 14:00
    String time = '09:00';
    final tm = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
            caseSensitive: false)
        .firstMatch(rest);
    final tm24 =
        RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(rest);
    if (tm != null) {
      var h = int.parse(tm.group(1)!);
      final m = tm.group(2) == null ? 0 : int.parse(tm.group(2)!);
      final ap = tm.group(3)!.toLowerCase();
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      time =
          '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      rest = rest.replaceAll(tm.group(0)!, '');
    } else if (tm24 != null) {
      time = tm24.group(0)!;
      rest = rest.replaceAll(tm24.group(0)!, '');
    }

    DateTime date;
    final now = DateTime.now();
    if (lower.contains('tomorrow')) {
      date = DateTime(now.year, now.month, now.day + 1);
      rest = rest.replaceAll(RegExp(r'tomorrow\.?', caseSensitive: false), '');
    } else if (recurrence == 'monthly') {
      final m = RegExp(r'on the (\d{1,2})(st|nd|rd|th)',
              caseSensitive: false)
          .firstMatch(prompt);
      final day = m == null ? 1 : int.parse(m.group(1)!);
      var d = DateTime(now.year, now.month, day);
      if (!d.isAfter(DateTime(now.year, now.month, now.day))) {
        d = DateTime(now.year, now.month + 1, day);
      }
      date = d;
    } else {
      date = DateTime(now.year, now.month, now.day);
    }

    var title = rest.trim().replaceAll(RegExp(r'[.\s]+$'), '');
    if (title.isEmpty) title = 'Reminder';
    title = title[0].toUpperCase() + title.substring(1);
    return {'title': title, 'recurrence': recurrence, 'date': date, 'time': time};
  }

  // ---- task intent ----

  AiReply _taskIntent(String prompt) {
    var title = prompt
        .replaceAll(
            RegExp(r'^(add task|create task|new task|todo:)\s*',
                caseSensitive: false),
            '')
        .trim();
    if (title.isEmpty) title = 'New task';
    return AiReply(
      'Got it — I can add this to your tasks.',
      card: ActionCard(
        kind: 'task',
        title: title,
        lines: [title, 'Personal', 'Medium priority'],
        confirmLabel: 'Add Task',
        payload: {'title': title},
      ),
    );
  }

  // ---- email intent ----

  AiReply _emailIntent(String prompt, AiContext ctx) {
    final lower = prompt.toLowerCase();
    final about = lower.contains('refund')
        ? 'requesting a refund'
        : lower.contains('follow')
            ? 'following up'
            : 'your request';
    final draft =
        'Subject: ${about[0].toUpperCase()}${about.substring(1)}\n\nHi there,\n\nI hope you\'re well. I\'m writing regarding $about. I would appreciate your help resolving this at your earliest convenience.\n\nThank you for your time,\n${ctx.userName}';
    return AiReply(
      'Here\'s a polite draft. Review it, then send when you\'re ready.',
      card: ActionCard(
        kind: 'email',
        title: 'Email draft',
        lines: draft.split('\n'),
        confirmLabel: 'Send Email',
        secondaryLabel: 'Edit',
        payload: {'draft': draft},
      ),
    );
  }

  // ---- summarize intent ----

  AiReply _summarizeIntent(String prompt) {
    var text = prompt.replaceFirst(
        RegExp(r'^summarize(\s+(this|the))?(\s+(text|document))?:?\s*',
            caseSensitive: false),
        '');
    if (text.trim().length < 40) {
      return AiReply(
          'Paste the text you\'d like summarized (or use the Summarizer tool to pick a document), and I\'ll condense it for you.');
    }
    return AiReply(summarizeText(text));
  }

  /// Simple extractive summary used by the Summarizer tool too.
  static String summarizeText(String text) {
    final sentences = text
        .replaceAll('\n', ' ')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().length > 20)
        .toList();
    if (sentences.isEmpty) return 'Not enough text to summarize.';
    final freq = <String, int>{};
    for (final s in sentences) {
      for (final w in s.toLowerCase().split(RegExp(r'\W+'))) {
        if (w.length > 4) freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    int score(String s) {
      var sc = 0;
      for (final w in s.toLowerCase().split(RegExp(r'\W+'))) {
        sc += freq[w] ?? 0;
      }
      return sc;
    }
    final ranked = [...sentences]..sort((a, b) => score(b).compareTo(score(a)));
    final top = ranked.take(3).toList()
      ..sort((a, b) => sentences.indexOf(a).compareTo(sentences.indexOf(b)));
    final words = text.trim().split(RegExp(r'\s+')).length;
    final buf = StringBuffer()
      ..writeln('Summary (${top.length} key points · $words words):\n');
    for (var i = 0; i < top.length; i++) {
      buf.writeln('• ${top[i].trim()}');
    }
    return buf.toString().trim();
  }

  // ---- plan intent ----

  AiReply _planIntent(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('trip') || lower.contains('travel')) {
      return AiReply('Here\'s a trip checklist to start from:\n\n'
          '• Book flights & accommodation\n'
          '• Check passport / ID validity\n'
          '• Pack: clothes, chargers, toiletries, meds\n'
          '• Download offline maps\n'
          '• Arrange airport transport\n'
          '• Share itinerary with family\n\n'
          'Want me to turn this into dated tasks?');
    }
    final now = DateTime.now();
    final when = lower.contains('tomorrow') ? 'tomorrow' : 'today';
    return AiReply('Here\'s a balanced plan for $when:\n\n'
        '• 07:00 — Morning routine & top priority\n'
        '• 09:00 — Deep work block (90 min)\n'
        '• 12:00 — Lunch & reset\n'
        '• 13:30 — Meetings & messages\n'
        '• 15:30 — Second work block\n'
        '• 18:00 — Wind down & plan ${_when(when)}\n\n'
        'Tell me your must-dos and I\'ll fit them in.');
  }

  String _when(String when) => when == 'tomorrow' ? 'today' : 'tomorrow';

  // ---- research intent ----

  AiReply _researchIntent(String prompt) {
    final q = prompt
        .replaceFirst(
            RegExp(r'^(find|research|search for|look up)\s*',
                caseSensitive: false),
            '')
        .trim();
    return AiReply('Here\'s an organized brief on "$q":\n\n'
        'Overview\n"$q" — here\'s what matters most.\n\n'
        'Key points\n• Compare at least 3 options before deciding\n• Check recent reviews (last 6 months)\n• Watch for hidden fees or conditions\n\n'
        'Next steps\n• Shortlist your top 3\n• Verify availability & pricing\n• Book or decide by end of week\n\n'
        'Note: I\'m running in demo mode with on-device knowledge. Connect an AI API key in Settings → AI for live, up-to-date research.');
  }

  // ---- content intent ----

  AiReply _contentIntent(String prompt) {
    final topic = prompt
        .replaceAll(
            RegExp(r'(create|generate|make|give me|7)\s*', caseSensitive: false),
            '')
        .replaceAll(RegExp(r'(tiktok\s*)?(content\s*)?(ideas|idea).*',
            caseSensitive: false), '')
        .trim();
    final niche = topic.isEmpty ? 'your business' : topic;
    final ideas = [
      'POV: the problem your product solves (3-sec hook)',
      'Day in the life + your product in action',
      'Before/after transformation',
      'Myth vs fact about $niche',
      'Reply to a comment with a demo',
      'Unboxing / first impressions',
      'Quick tip series (Part 1 of 7)',
    ];
    final buf = StringBuffer('Here are 7 TikTok ideas for $niche:\n\n');
    for (var i = 0; i < ideas.length; i++) {
      buf.writeln('${i + 1}. ${ideas[i]}');
    }
    return AiReply(buf.toString().trim());
  }

  // ---- organize intent ----

  AiReply _organizeIntent(String prompt) {
    var text = prompt.replaceFirst(
        RegExp(r'^organize\s*(this)?\s*(information|info|data)?\s*(into a table)?\s*:?\s*',
            caseSensitive: false),
        '');
    if (text.trim().isEmpty) {
      return AiReply(
          'Paste the information you want organized (one item per line, e.g. "Name: value"), and I\'ll turn it into a neat table.');
    }
    return AiReply('Here\'s your organized table:\n\n${_toTable(text)}');
  }

  static String _toTable(String text) {
    final rows = <List<String>>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      var parts = t.split(RegExp(r'\s*[:|\-–]\s*'));
      if (parts.length == 1) parts = t.split(RegExp(r'\s{2,}|\t|,'));
      rows.add(parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList());
    }
    if (rows.isEmpty) return '(no rows found)';
    final cols = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final widths = List<int>.filled(cols, 0);
    for (final r in rows) {
      for (var i = 0; i < r.length; i++) {
        if (r[i].length > widths[i]) widths[i] = r[i].length;
      }
    }
    final buf = StringBuffer();
    for (final r in rows) {
      for (var i = 0; i < cols; i++) {
        final cell = i < r.length ? r[i] : '';
        buf.write(cell.padRight(widths[i] + 3));
      }
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  // ---- delete intent (always confirm) ----

  AiReply _deleteIntent(String prompt, AiContext ctx) {
    final lower = prompt.toLowerCase();
    TaskItem? match;
    for (final t in ctx.tasks) {
      if (lower.contains(t.title.toLowerCase())) {
        match = t;
        break;
      }
    }
    if (match == null) {
      return AiReply(
          'Which item should I delete? Tell me its exact title and I\'ll ask you to confirm first.');
    }
    return AiReply(
      'I found this. Please confirm — this can\'t be undone.',
      card: ActionCard(
        kind: 'delete',
        title: match.title,
        lines: [match.title, match.category, match.recurrenceLabel()],
        confirmLabel: 'Confirm Delete',
        secondaryLabel: 'Cancel',
        payload: {'id': match.id},
      ),
    );
  }

  AiReply _fallback(AiContext ctx) => AiReply(
        'I can help with that. Try one of these:\n\n'
        '• "Remind me to pay rent on the 1st every month"\n'
        '• "Write a polite email asking for a refund"\n'
        '• "Plan my schedule for tomorrow"\n'
        '• "Summarize: <paste text>"\n'
        '• "Create 7 TikTok content ideas for my business"\n\n'
        'Or open the AI Tools from the Home tab for guided help.',
      );

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtTime(String hhmm) {
    final parts = hhmm.split(':');
    var h = int.parse(parts[0]);
    final m = parts[1];
    final ap = h >= 12 ? 'PM' : 'AM';
    h = h % 12 == 0 ? 12 : h % 12;
    return '$h:$m $ap';
  }
}

// ---------------------------------------------------------------------------
// HTTP provider stub: OpenAI-compatible endpoint. Never fakes responses.
// ---------------------------------------------------------------------------

class HttpAiProvider implements AiProvider {
  final String apiKey;
  final String baseUrl;
  final String model;
  final String tone;

  HttpAiProvider({
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    this.tone = 'Friendly',
  });

  @override
  String get id => 'http';
  @override
  String get label => 'Custom AI API';
  @override
  String get badge => 'Live API';

  @override
  Future<AiReply> generate(String prompt, AiContext ctx) async {
    if (apiKey.trim().isEmpty) {
      return AiReply(
        'Live AI isn\'t connected yet. Add your API key in Settings → AI to enable real answers. '
        'Until then, switch back to the on-device demo in Settings → AI.',
        needsApiKey: true,
      );
    }
    try {
      final uri = Uri.parse(
          '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'temperature': 0.7,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are Tasky, a friendly and concise AI virtual assistant ($tone tone). '
                          'Help the user organize tasks, write, plan, summarize, and research. '
                          'Keep answers short and scannable. Never claim to have taken real-world '
                          'actions (sending email, payments); instead describe what you would do '
                          'and ask for confirmation.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final choices = j['choices'] as List?;
        final content = choices != null && choices.isNotEmpty
            ? (choices[0]['message']?['content'] as String? ?? '')
            : '';
        if (content.trim().isEmpty) {
          return AiReply(
              'The API returned an empty response. Please try again.');
        }
        return AiReply(content.trim());
      }
      return AiReply(
          'The AI API returned an error (HTTP ${res.statusCode}). Check your API key, base URL, and model in Settings → AI.');
    } catch (e) {
      return AiReply(
          'Couldn\'t reach the AI API. Check your connection and Settings → AI configuration.');
    }
  }
}

/// Builds the active provider from store settings.
AiProvider buildProvider({
  required String providerId,
  required String apiKey,
  required String baseUrl,
  required String model,
  required String tone,
}) {
  if (providerId == 'http') {
    return HttpAiProvider(
        apiKey: apiKey, baseUrl: baseUrl, model: model, tone: tone);
  }
  return DemoAiEngine();
}
