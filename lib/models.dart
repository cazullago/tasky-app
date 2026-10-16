import 'package:flutter/material.dart';

/// VA identifiers — the seven specialized assistants.
class VaIds {
  static const String life = 'life';
  static const String business = 'business';
  static const String creator = 'creator';
  static const String home = 'home';
  static const String reply = 'reply';
  static const String travel = 'travel';
  static const String study = 'study';

  static const List<String> all = [
    life,
    business,
    creator,
    home,
    reply,
    travel,
    study,
  ];
}

/// Input field types for tool forms.
enum FieldType { text, multiline, number, choice, date }

/// One input field on a tool form.
class FieldDef {
  final String key;
  final String label;
  final FieldType type;
  final List<String> options;
  final String hint;

  const FieldDef({
    required this.key,
    required this.label,
    this.type = FieldType.text,
    this.options = const [],
    this.hint = '',
  });
}

/// How a tool is executed.
enum ToolKind {
  /// input form -> generated text result (demo engine or live AI)
  generator,

  /// CRUD list backed by the store
  list,

  /// creates a scheduled local notification (consequential: needs confirm)
  reminder,

  /// countdown timer UI
  timer,

  /// pick an image/file and produce a study note (demo)
  scan,
}

/// A tool offered by a VA.
class ToolDef {
  final String id;
  final String title;
  final String glyph;
  final String blurb;
  final ToolKind kind;
  final List<FieldDef> inputs;
  final bool consequential;

  /// For [ToolKind.list]: backing collection key and item fields.
  final String listKey;
  final List<FieldDef> itemFields;
  final String checkField;

  const ToolDef({
    required this.id,
    required this.title,
    required this.glyph,
    required this.blurb,
    this.kind = ToolKind.generator,
    this.inputs = const [],
    this.consequential = false,
    this.listKey = '',
    this.itemFields = const [],
    this.checkField = '',
  });
}

/// Editable memory field for a VA profile.
class MemoryFieldDef {
  final String key;
  final String label;
  final String hint;
  final FieldType type;
  final List<String> options;

  const MemoryFieldDef({
    required this.key,
    required this.label,
    this.hint = '',
    this.type = FieldType.text,
    this.options = const [],
  });
}

/// Static definition of a virtual assistant.
class VaDef {
  final String id;
  final String title;
  final String noun;
  final String glyph;
  final Color colorA;
  final Color colorB;
  final String tagline;
  final String systemPrompt;
  final List<MemoryFieldDef> memoryFields;
  final List<ToolDef> tools;

  const VaDef({
    required this.id,
    required this.title,
    required this.noun,
    required this.glyph,
    required this.colorA,
    required this.colorB,
    required this.tagline,
    required this.systemPrompt,
    required this.memoryFields,
    required this.tools,
  });

  String displayName(String? customName) =>
      (customName == null || customName.trim().isEmpty)
          ? title
          : customName.trim();

  String subtitle() => 'your $noun assistant';
}

/// One chat message in a VA conversation.
class ChatMsg {
  final String id;
  final String vaId;
  final bool fromUser;
  final String text;
  final DateTime time;
  final String? toolId;

  ChatMsg({
    required this.id,
    required this.vaId,
    required this.fromUser,
    required this.text,
    required this.time,
    this.toolId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vaId': vaId,
        'fromUser': fromUser,
        'text': text,
        'time': time.toIso8601String(),
        'toolId': toolId,
      };

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
        id: j['id'] as String? ?? '',
        vaId: j['vaId'] as String? ?? '',
        fromUser: j['fromUser'] as bool? ?? false,
        text: j['text'] as String? ?? '',
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        toolId: j['toolId'] as String?,
      );
}

/// Per-VA persistent memory profile (rename + editable fields).
class VaProfile {
  final String vaId;
  String customName;
  Map<String, String> fields;

  VaProfile({
    required this.vaId,
    this.customName = '',
    Map<String, String>? fields,
  }) : fields = fields ?? {};

  Map<String, dynamic> toJson() => {
        'vaId': vaId,
        'customName': customName,
        'fields': fields,
      };

  factory VaProfile.fromJson(Map<String, dynamic> j) => VaProfile(
        vaId: j['vaId'] as String? ?? '',
        customName: j['customName'] as String? ?? '',
        fields: Map<String, String>.from(
            (j['fields'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
      );
}

/// A scheduled reminder (local notification).
class ReminderItem {
  final String id;
  final String vaId;
  final String title;
  final String note;
  final DateTime at;

  ReminderItem({
    required this.id,
    required this.vaId,
    required this.title,
    required this.note,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'vaId': vaId,
        'title': title,
        'note': note,
        'at': at.toIso8601String(),
      };

  factory ReminderItem.fromJson(Map<String, dynamic> j) => ReminderItem(
        id: j['id'] as String? ?? '',
        vaId: j['vaId'] as String? ?? VaIds.life,
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Demo-mode local account (NOT a real backend account).
class DemoUser {
  final String id;
  final String name;
  final String email;
  final String passHash;
  final String salt;
  final DateTime createdAt;

  DemoUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passHash,
    required this.salt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'passHash': passHash,
        'salt': salt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DemoUser.fromJson(Map<String, dynamic> j) => DemoUser(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        passHash: j['passHash'] as String? ?? '',
        salt: j['salt'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// OpenAI-compatible provider configuration.
class AiConfig {
  String baseUrl;
  String apiKey;
  String model;
  bool enabled;

  AiConfig({
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.enabled = false,
  });

  bool get configured => apiKey.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'enabled': enabled,
      };

  factory AiConfig.fromJson(Map<String, dynamic>? j) => AiConfig(
        baseUrl: j?['baseUrl'] as String? ?? 'https://api.openai.com/v1',
        apiKey: j?['apiKey'] as String? ?? '',
        model: j?['model'] as String? ?? 'gpt-4o-mini',
        enabled: j?['enabled'] as bool? ?? false,
      );
}

/// App-wide settings.
class AppSettings {
  String themeMode;
  bool voiceInput;

  AppSettings({this.themeMode = 'system', this.voiceInput = true});

  ThemeMode get themeModeValue {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode,
        'voiceInput': voiceInput,
      };

  factory AppSettings.fromJson(Map<String, dynamic>? j) => AppSettings(
        themeMode: j?['themeMode'] as String? ?? 'system',
        voiceInput: j?['voiceInput'] as bool? ?? true,
      );
}
