import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'seed.dart';

/// Central app state, persisted to a JSON file on device (survives updates).
/// Every mutation goes through [_persist] so nothing is lost.
class AppStore extends ChangeNotifier {
  static const _fileName = 'tasky_v2.json';
  static const _prefsLoadedKey = 'tasky_v2_loaded';

  final Uuid uuid = const Uuid();

  bool _loaded = false;
  bool get loaded => _loaded;

  // ---- profile / session ----
  String userName = 'Friend';
  String userEmail = '';
  String? photoPath;
  String? sessionUserId;

  // ---- per-VA memory ----
  final Map<String, VaProfile> vaProfiles = {};

  // ---- generic collections: key -> list of string-map items ----
  final Map<String, List<Map<String, String>>> collections = {};

  // ---- reminders ----
  final List<ReminderItem> reminders = [];

  // ---- chat history per VA ----
  final Map<String, List<ChatMsg>> chats = {};

  // ---- settings / AI ----
  AppSettings settings = AppSettings();
  AiConfig ai = AiConfig();

  bool _saving = false;
  bool _saveQueued = false;

  VaProfile profileOf(String vaId) =>
      vaProfiles.putIfAbsent(vaId, () => VaProfile(vaId: vaId));

  List<ChatMsg> chatOf(String vaId) =>
      chats.putIfAbsent(vaId, () => <ChatMsg>[]);

  List<Map<String, String>> collectionOf(String key) =>
      collections.putIfAbsent(key, () => <Map<String, String>>[]);

  // ------------------------------------------------------------ persistence
  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      sessionUserId = prefs.getString('tasky_session_v2');
      final file = await _dataFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _fromJson(data);
      }
      // Seed once per install (idempotent: flag inside the JSON).
      final seeded = prefs.getBool('tasky_v2_seeded') ?? false;
      if (!seeded) {
        SeedData.apply(this);
        await prefs.setBool('tasky_v2_seeded', true);
        await _writeNow();
      }
      await prefs.setBool(_prefsLoadedKey, true);
    } catch (e) {
      // Corrupt file or missing storage: start fresh rather than crash.
      debugPrint('Tasky load failed, starting fresh: $e');
      try {
        SeedData.apply(this);
      } catch (_) {}
    }
    _loaded = true;
    notifyListeners();
  }

  void _fromJson(Map<String, dynamic> data) {
    userName = data['userName'] as String? ?? 'Friend';
    userEmail = data['userEmail'] as String? ?? '';
    photoPath = data['photoPath'] as String?;

    final vp = data['vaProfiles'] as Map?;
    if (vp != null) {
      for (final e in vp.entries) {
        vaProfiles['${e.key}'] =
            VaProfile.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
    }
    final coll = data['collections'] as Map?;
    if (coll != null) {
      for (final e in coll.entries) {
        final list = (e.value as List)
            .map((m) => Map<String, String>.from(
                (m as Map).map((k, v) => MapEntry('$k', '$v'))))
            .toList();
        collections['${e.key}'] = list;
      }
    }
    final rems = data['reminders'] as List?;
    if (rems != null) {
      reminders
        ..clear()
        ..addAll(rems.map((m) =>
            ReminderItem.fromJson(Map<String, dynamic>.from(m as Map))));
    }
    final ch = data['chats'] as Map?;
    if (ch != null) {
      for (final e in ch.entries) {
        chats['${e.key}'] = (e.value as List)
            .map((m) =>
                ChatMsg.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
      }
    }
    settings =
        AppSettings.fromJson(data['settings'] as Map<String, dynamic>?);
    ai = AiConfig.fromJson(data['ai'] as Map<String, dynamic>?);
  }

  Map<String, dynamic> _toJson() => {
        'version': 2,
        'userName': userName,
        'userEmail': userEmail,
        'photoPath': photoPath,
        'vaProfiles': vaProfiles.map((k, v) => MapEntry(k, v.toJson())),
        'collections': collections,
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'chats': chats.map((k, v) =>
            MapEntry(k, v.map((m) => m.toJson()).toList())),
        'settings': settings.toJson(),
        'ai': ai.toJson(),
      };

  /// Save (debounced): never throws, never blocks the UI thread badly.
  void persist() {
    if (_saving) {
      _saveQueued = true;
      return;
    }
    _saving = true;
    _writeNow().whenComplete(() {
      _saving = false;
      if (_saveQueued) {
        _saveQueued = false;
        persist();
      }
    });
  }

  Future<void> _writeNow() async {
    try {
      final file = await _dataFile();
      await file.writeAsString(jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('Tasky save failed: $e');
    }
  }

  // ------------------------------------------------------------------ auth
  List<DemoUser> _users = [];

  List<DemoUser> get users => List.unmodifiable(_users);

  void setUsers(List<DemoUser> users) {
    _users = users;
  }

  DemoUser? get currentUser {
    if (sessionUserId == null) return null;
    for (final u in _users) {
      if (u.id == sessionUserId) return u;
    }
    return null;
  }

  Future<void> saveUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'tasky_users_v2', jsonEncode(_users.map((u) => u.toJson()).toList()));
    } catch (e) {
      debugPrint('Tasky saveUsers failed: $e');
    }
  }

  Future<void> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tasky_users_v2');
      if (raw != null) {
        _users = (jsonDecode(raw) as List)
            .map((m) => DemoUser.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList();
      }
    } catch (e) {
      debugPrint('Tasky loadUsers failed: $e');
      _users = [];
    }
  }

  Future<void> setSession(String? userId) async {
    sessionUserId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId == null) {
        await prefs.remove('tasky_session_v2');
      } else {
        await prefs.setString('tasky_session_v2', userId);
      }
    } catch (e) {
      debugPrint('Tasky setSession failed: $e');
    }
    notifyListeners();
  }

  // -------------------------------------------------------------- mutations
  void updateProfile({String? name, String? email, String? photo}) {
    if (name != null) userName = name;
    if (email != null) userEmail = email;
    if (photo != null) photoPath = photo;
    persist();
    notifyListeners();
  }

  void clearPhoto() {
    photoPath = null;
    persist();
    notifyListeners();
  }

  void updateVaProfile(String vaId, {String? customName, Map<String, String>? fields}) {
    final p = profileOf(vaId);
    if (customName != null) p.customName = customName;
    if (fields != null) p.fields = Map<String, String>.from(fields);
    persist();
    notifyListeners();
  }

  void addCollectionItem(String key, Map<String, String> item) {
    final withId = Map<String, String>.from(item)..['id'] = uuid.v4();
    collectionOf(key).add(withId);
    persist();
    notifyListeners();
  }

  void updateCollectionItem(String key, String id, Map<String, String> item) {
    final list = collectionOf(key);
    final i = list.indexWhere((m) => m['id'] == id);
    if (i >= 0) {
      list[i] = Map<String, String>.from(item)..['id'] = id;
      persist();
      notifyListeners();
    }
  }

  void toggleCollectionCheck(String key, String id, String checkField) {
    final list = collectionOf(key);
    final i = list.indexWhere((m) => m['id'] == id);
    if (i >= 0) {
      final cur = list[i][checkField] == 'true';
      list[i][checkField] = (!cur).toString();
      persist();
      notifyListeners();
    }
  }

  void deleteCollectionItem(String key, String id) {
    collectionOf(key).removeWhere((m) => m['id'] == id);
    persist();
    notifyListeners();
  }

  void addReminder(ReminderItem r) {
    reminders.add(r);
    reminders.sort((a, b) => a.at.compareTo(b.at));
    persist();
    notifyListeners();
  }

  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    persist();
    notifyListeners();
  }

  void addChatMsg(ChatMsg m) {
    final list = chatOf(m.vaId);
    list.add(m);
    // Keep history bounded per VA.
    if (list.length > 200) list.removeRange(0, list.length - 200);
    persist();
    notifyListeners();
  }

  void clearChat(String vaId) {
    chats[vaId] = <ChatMsg>[];
    persist();
    notifyListeners();
  }

  void updateSettings(AppSettings s) {
    settings = s;
    persist();
    notifyListeners();
  }

  void updateAi(AiConfig c) {
    ai = c;
    persist();
    notifyListeners();
  }

  /// Wipe demo account + local data (data-deletion request placeholder).
  Future<void> wipeAll() async {
    vaProfiles.clear();
    collections.clear();
    reminders.clear();
    chats.clear();
    _users = [];
    userName = 'Friend';
    userEmail = '';
    photoPath = null;
    settings = AppSettings();
    ai = AiConfig();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      final file = await _dataFile();
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Tasky wipeAll failed: $e');
    }
    notifyListeners();
  }
}
