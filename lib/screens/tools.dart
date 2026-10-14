import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../ai.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------------------------------------------------------------------
// Shared scaffold
// ---------------------------------------------------------------------------

class ToolScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const ToolScaffold(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskyStore>();
    final live = store.aiProvider == 'http';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ProviderBadge(
              text: live ? 'Live API' : 'Demo mode', live: live),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(subtitle,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? TaskyColors.inkSoftDark
                      : TaskyColors.inkSoft)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class OutputCard extends StatelessWidget {
  final String output;
  final VoidCallback? onUseInAssistant;

  const OutputCard({super.key, required this.output, this.onUseInAssistant});

  @override
  Widget build(BuildContext context) {
    return TaskyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(output, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: output));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard.')));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String> _runProvider(
    BuildContext context, String prompt, String demoFallback) async {
  final store = context.read<TaskyStore>();
  final provider = buildProvider(
    providerId: store.aiProvider,
    apiKey: store.apiKey,
    baseUrl: store.baseUrl,
    model: store.model,
    tone: store.aiTone,
  );
  if (provider is DemoAiEngine) return demoFallback;
  final reply = await provider.generate(
      prompt, AiContext(userName: store.userName, tasks: store.tasks));
  return reply.text;
}

// ---------------------------------------------------------------------------
// Writing Assistant
// ---------------------------------------------------------------------------

class WritingTool extends StatefulWidget {
  const WritingTool({super.key});

  @override
  State<WritingTool> createState() => _WritingToolState();
}

class _WritingToolState extends State<WritingTool> {
  final _topic = TextEditingController();
  String _type = 'Email';
  String _tone = 'Friendly';
  String? _output;
  bool _busy = false;

  final _types = ['Email', 'Message', 'Caption', 'Report', 'Note', 'Business copy'];
  final _tones = ['Friendly', 'Professional', 'Casual', 'Persuasive', 'Concise'];

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  String _demoWrite() {
    final topic = _topic.text.trim().isEmpty ? 'your topic' : _topic.text.trim();
    final name = context.read<TaskyStore>().userName;
    switch (_type) {
      case 'Email':
        return 'Subject: $topic\n\nHi there,\n\nI hope you\'re well. I\'m writing about $topic.\n\n${_tone == 'Professional' ? 'I would appreciate your guidance on the best way forward.' : 'Would love your thoughts when you have a moment!'}\n\nThanks so much,\n$name';
      case 'Message':
        return 'Hi! Quick note about $topic — ${_tone == 'Casual' ? 'let me know what you think whenever!' : 'please let me know your thoughts at your convenience.'} Thanks! 🙏';
      case 'Caption':
        return 'Option 1: $topic ✨\n\nOption 2: POV: $topic 💡\n\nOption 3: Everything you need to know about $topic 👇\n\n#${topic.split(' ').first} #tips #fyp';
      case 'Report':
        return 'REPORT: $topic\n\n1. Executive summary\n   Key findings on $topic at a glance.\n\n2. Background\n   Context and objectives.\n\n3. Findings\n   • Point one\n   • Point two\n\n4. Recommendations\n   • Next step one\n   • Next step two';
      case 'Note':
        return 'NOTE — $topic\n\n• Key point one\n• Key point two\n• Follow-up: ...';
      default:
        return '$topic — done right.\n\nLooking for $_tone copy that converts? Here\'s your draft:\n\n${_tone == 'Persuasive' ? 'Stop settling. ' : ''}$topic, crafted for people who want results without the hassle.\n\n👉 Try it today — you\'ll feel the difference.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Writing Assistant',
      subtitle: 'Draft emails, messages, captions, reports, notes, and business copy.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: _types
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'Email'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _tone,
                  decoration: const InputDecoration(labelText: 'Tone'),
                  items: _tones
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: (v) => setState(() => _tone = v ?? 'Friendly'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _topic,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'What is it about?',
                hintText: 'e.g. asking for a refund'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_topic.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tell me the topic first.')));
                      return;
                    }
                    setState(() => _busy = true);
                    final out = await _runProvider(
                      context,
                      'Write a ${_tone.toLowerCase()} ${_type.toLowerCase()} about: ${_topic.text.trim()}',
                      _demoWrite(),
                    );
                    if (mounted) setState(() {
                      _output = out;
                      _busy = false;
                    });
                    context.read<TaskyStore>().addActivity(
                        'Writing: $_type generated', icon: 'sparkles');
                    await context.read<TaskyStore>().persist();
                  },
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Generate'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            OutputCard(output: _output!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Research Assistant
// ---------------------------------------------------------------------------

class ResearchTool extends StatefulWidget {
  const ResearchTool({super.key});

  @override
  State<ResearchTool> createState() => _ResearchToolState();
}

class _ResearchToolState extends State<ResearchTool> {
  final _q = TextEditingController();
  String? _output;
  bool _busy = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _demoResearch() {
    final q = _q.text.trim();
    return 'RESEARCH: $q\n\nOverview\nThe essentials on $q, organized for a quick decision.\n\nKey points\n• Compare at least 3 options before deciding\n• Check recent reviews (last 6 months)\n• Watch for hidden fees or conditions\n\nThings to consider\n• Your budget and must-haves\n• Timing and availability\n• Reputation of the provider\n\nNext steps\n• Shortlist your top 3\n• Verify pricing and availability\n• Decide by end of week\n\nNote: demo mode uses on-device knowledge. Connect an AI API key in Settings → AI for live, up-to-date research.';
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Research Assistant',
      subtitle: 'Ask a question and get an organized brief.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _q,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Research question',
                hintText: 'e.g. 5 affordable hotels in Cebu'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_q.text.trim().isEmpty) return;
                    setState(() => _busy = true);
                    final out = await _runProvider(
                        context, 'Research this: ${_q.text.trim()}', _demoResearch());
                    if (mounted) setState(() {
                      _output = out;
                      _busy = false;
                    });
                    context.read<TaskyStore>().addActivity(
                        'Research: ${_q.text.trim()}', icon: 'sparkles');
                    await context.read<TaskyStore>().persist();
                  },
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Research'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            OutputCard(output: _output!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Planning Assistant
// ---------------------------------------------------------------------------

class PlanningTool extends StatefulWidget {
  const PlanningTool({super.key});

  @override
  State<PlanningTool> createState() => _PlanningToolState();
}

class _PlanningToolState extends State<PlanningTool> {
  final _details = TextEditingController();
  String _kind = 'Daily schedule';
  String? _output;
  bool _busy = false;

  final _kinds = [
    'Daily schedule',
    'Trip plan',
    'Study plan',
    'Project plan',
    'Shopping plan'
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _demoPlan() {
    final d = _details.text.trim().isEmpty ? 'your goal' : _details.text.trim();
    switch (_kind) {
      case 'Trip plan':
        return 'TRIP PLAN: $d\n\n• Book flights & accommodation\n• Check ID / passport validity\n• Pack: clothes, chargers, toiletries, meds\n• Download offline maps\n• Arrange airport transport\n• Share itinerary with family\n• Set a daily budget';
      case 'Study plan':
        return 'STUDY PLAN: $d\n\n• Day 1–2: Core concepts (2h focused sessions)\n• Day 3–4: Practice problems\n• Day 5: Review mistakes & flashcards\n• Day 6: Mock test under time pressure\n• Day 7: Light review & rest\n\nTip: 25-min focus blocks with 5-min breaks.';
      case 'Project plan':
        return 'PROJECT PLAN: $d\n\n1. Define the goal & success criteria\n2. Break into tasks (assign owners + dates)\n3. Milestone 1: first draft / prototype\n4. Review & feedback round\n5. Milestone 2: polished version\n6. Launch & retrospective';
      case 'Shopping plan':
        return 'SHOPPING PLAN: $d\n\n• Set a budget first\n• List must-haves vs nice-to-haves\n• Compare 3 stores / sellers\n• Check reviews & return policy\n• Buy must-haves, sleep on the rest';
      default:
        return 'DAILY SCHEDULE: $d\n\n• 07:00 — Morning routine & #1 priority\n• 09:00 — Deep work (90 min)\n• 12:00 — Lunch & reset\n• 13:30 — Messages & meetings\n• 15:30 — Second work block\n• 18:00 — Wind down & plan tomorrow';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Planning Assistant',
      subtitle: 'Generate schedules, trip plans, study plans, and more.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _kind,
            decoration: const InputDecoration(labelText: 'Plan type'),
            items: _kinds
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (v) => setState(() => _kind = v ?? 'Daily schedule'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _details,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'e.g. 3-day Cebu trip, ₱15k budget'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final out = await _runProvider(
                        context,
                        'Create a ${_kind.toLowerCase()} for: ${_details.text.trim()}',
                        _demoPlan());
                    if (mounted) setState(() {
                      _output = out;
                      _busy = false;
                    });
                    context.read<TaskyStore>().addActivity(
                        'Plan created: $_kind', icon: 'sparkles');
                    await context.read<TaskyStore>().persist();
                  },
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create plan'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            OutputCard(output: _output!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summarizer
// ---------------------------------------------------------------------------

class SummarizerTool extends StatefulWidget {
  const SummarizerTool({super.key});

  @override
  State<SummarizerTool> createState() => _SummarizerToolState();
}

class _SummarizerToolState extends State<SummarizerTool> {
  final _text = TextEditingController();
  String? _fileName;
  String? _output;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) return;
      final content = String.fromCharCodes(bytes);
      setState(() {
        _text.text = content;
        _fileName = f.name;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn\'t read that file. Try pasting the text.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Summarizer',
      subtitle: 'Paste text or pick a .txt / .md document for a concise summary.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName ?? 'Pick a document (.txt, .md)'),
            onPressed: _pickFile,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            maxLines: 8,
            decoration: const InputDecoration(
                labelText: 'Text to summarize',
                hintText: 'Paste an article, notes, or document text…',
                alignLabelWithHint: true),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (_text.text.trim().length < 40) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Add a bit more text to summarize.')));
                      return;
                    }
                    setState(() => _busy = true);
                    final out = await _runProvider(
                      context,
                      'Summarize this concisely:\n\n${_text.text.trim()}',
                      DemoAiEngine.summarizeText(_text.text.trim()),
                    );
                    if (mounted) setState(() {
                      _output = out;
                      _busy = false;
                    });
                    context.read<TaskyStore>().addActivity(
                        'Summary generated', icon: 'summarize');
                    await context.read<TaskyStore>().persist();
                  },
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Summarize'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            OutputCard(output: _output!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content Assistant
// ---------------------------------------------------------------------------

class ContentTool extends StatefulWidget {
  const ContentTool({super.key});

  @override
  State<ContentTool> createState() => _ContentToolState();
}

class _ContentToolState extends State<ContentTool> {
  final _niche = TextEditingController();
  String _kind = 'TikTok ideas';
  String? _output;
  bool _busy = false;

  final _kinds = [
    'TikTok ideas',
    'Instagram captions',
    'Hooks',
    'Short scripts',
    'Content calendar'
  ];

  @override
  void dispose() {
    _niche.dispose();
    super.dispose();
  }

  String _demoContent() {
    final n = _niche.text.trim().isEmpty ? 'your business' : _niche.text.trim();
    switch (_kind) {
      case 'Instagram captions':
        return 'IG CAPTIONS for $n:\n\n1. $n, but make it effortless ✨\n2. Your sign to try $n today 💡\n3. Small step, big glow-up: $n 🌿\n\n#${n.split(' ').first} #reels #tips';
      case 'Hooks':
        return 'HOOKS for $n:\n\n1. "Stop doing $n wrong — do this instead"\n2. "I tried $n for 7 days, here\'s what happened"\n3. "The $n mistake almost everyone makes"\n4. "POV: you finally found $n that works"\n5. "3 $n tips I wish I knew sooner"';
      case 'Short scripts':
        return 'SHORT SCRIPT — $n (30s)\n\n[0-3s] Hook: "This changed my $n game."\n[3-15s] Show the problem, then the fix in action.\n[15-25s] Quick demo / transformation.\n[25-30s] CTA: "Follow for part 2!"';
      case 'Content calendar':
        return '7-DAY CONTENT CALENDAR — $n\n\nMon: Educational tip\nTue: Behind the scenes\nWed: Customer / demo spotlight\nThu: Myth vs fact\nFri: Trending format + $n\nSat: Q&A / reply to comments\nSun: Rest or repost winner';
      default:
        final ideas = [
          'POV: the problem your product solves (3-sec hook)',
          'Day in the life + your product in action',
          'Before/after transformation',
          'Myth vs fact about $n',
          'Reply to a comment with a demo',
          'Unboxing / first impressions',
          'Quick tip series (Part 1 of 7)',
        ];
        final buf = StringBuffer('7 TIKTOK IDEAS for $n:\n\n');
        for (var i = 0; i < ideas.length; i++) {
          buf.writeln('${i + 1}. ${ideas[i]}');
        }
        return buf.toString().trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ToolScaffold(
      title: 'Content Assistant',
      subtitle: 'Ideas, captions, hooks, scripts, and content calendars.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _kind,
            decoration: const InputDecoration(labelText: 'Content type'),
            items: _kinds
                .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                .toList(),
            onChanged: (v) => setState(() => _kind = v ?? 'TikTok ideas'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _niche,
            decoration: const InputDecoration(
                labelText: 'Niche / topic',
                hintText: 'e.g. beauty products, online shop'),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final out = await _runProvider(
                        context,
                        'Generate ${_kind.toLowerCase()} about: ${_niche.text.trim()}',
                        _demoContent());
                    if (mounted) setState(() {
                      _output = out;
                      _busy = false;
                    });
                    context.read<TaskyStore>().addActivity(
                        'Content generated: $_kind', icon: 'sparkles');
                    await context.read<TaskyStore>().persist();
                  },
            child: _busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Generate'),
          ),
          if (_output != null) ...[
            const SizedBox(height: 16),
            OutputCard(output: _output!),
          ],
        ],
      ),
    );
  }
}

/// Maps a tool id from quick actions to its page.
Widget toolPageFor(String toolId) {
  switch (toolId) {
    case 'write':
      return const WritingTool();
    case 'research':
      return const ResearchTool();
    case 'plan':
      return const PlanningTool();
    case 'summarize':
      return const SummarizerTool();
    default:
      return const ContentTool();
  }
}
