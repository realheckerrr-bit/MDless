import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MdlessPluginPermission { messages, network, storage, notifications, microphone }

extension MdlessPluginPermissionLabel on MdlessPluginPermission {
  String get label => switch (this) {
    MdlessPluginPermission.messages => 'Messages',
    MdlessPluginPermission.network => 'Network',
    MdlessPluginPermission.storage => 'Storage',
    MdlessPluginPermission.notifications => 'Notifications',
    MdlessPluginPermission.microphone => 'Microphone',
  };
}

enum MdlessPluginSurface { chat, message, composer, settings }

enum MdlessPluginEventType { appStarted, chatOpened, messageReceived, messageSent, composerOpened, pluginActionInvoked }

class MdlessPluginAction {
  const MdlessPluginAction({required this.id, required this.label, required this.icon, required this.surface, this.command = 'showStatus'});

  final String id;
  final String label;
  final IconData icon;
  final MdlessPluginSurface surface;
  /// An allowlisted native MDless operation. Manifests never execute code.
  final String command;
}

class MdlessPluginEvent {
  const MdlessPluginEvent({required this.type, this.chatId, this.messageId, this.payload = const {}});

  final MdlessPluginEventType type;
  final int? chatId;
  final int? messageId;
  final Map<String, dynamic> payload;
}

typedef MdlessPluginListener = Future<void> Function(MdlessPluginEvent event);

class MdlessPlugin {
  MdlessPlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
    this.version = '1.0.0',
    this.author = 'MDless',
    this.permissions = const {},
    this.actions = const [],
    this.enabled = true,
    this.listener,
    this.builtIn = true,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final Color accent;
  final String version;
  final String author;
  final Set<MdlessPluginPermission> permissions;
  final List<MdlessPluginAction> actions;
  final MdlessPluginListener? listener;
  final bool builtIn;
  bool enabled;
}

class PluginEngine extends ChangeNotifier {
  PluginEngine() : plugins = [
    MdlessPlugin(
      id: 'focus-mode',
      name: 'Focus mode',
      description: 'Hide distractions and keep one chat in view.',
      icon: '◒',
      accent: const Color(0xFF6750A4),
      permissions: {MdlessPluginPermission.messages},
      actions: [MdlessPluginAction(id: 'focus-chat', label: 'Focus this chat', icon: Icons.center_focus_strong_rounded, surface: MdlessPluginSurface.chat, command: 'focusChat')],
    ),
    MdlessPlugin(
      id: 'quick-translate',
      name: 'Quick translate',
      description: 'Add translation actions to message menus.',
      icon: '文',
      accent: const Color(0xFF246A9C),
      permissions: {MdlessPluginPermission.messages, MdlessPluginPermission.network},
      actions: [MdlessPluginAction(id: 'translate-message', label: 'Translate message', icon: Icons.translate_rounded, surface: MdlessPluginSurface.message, command: 'translateMessage')],
    ),
    MdlessPlugin(
      id: 'link-inspector',
      name: 'Link inspector',
      description: 'Preview links before opening them.',
      icon: '↗',
      accent: const Color(0xFF006B5F),
      permissions: {MdlessPluginPermission.messages, MdlessPluginPermission.network},
      actions: [MdlessPluginAction(id: 'inspect-link', label: 'Inspect link', icon: Icons.link_rounded, surface: MdlessPluginSurface.message, command: 'inspectLink')],
    ),
    MdlessPlugin(
      id: 'emoji-reactions',
      name: 'Emoji reactions',
      description: 'Bring expressive reactions to every chat.',
      icon: '☺',
      accent: const Color(0xFF8D5A00),
      permissions: {MdlessPluginPermission.messages},
      actions: [MdlessPluginAction(id: 'add-reaction', label: 'Add reaction', icon: Icons.emoji_emotions_rounded, surface: MdlessPluginSurface.message, command: 'addReaction')],
    ),
  ];

  final List<MdlessPlugin> plugins;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final plugin in plugins) {
      plugin.enabled = prefs.getBool('plugin:${plugin.id}') ?? plugin.enabled;
    }
    for (final key in prefs.getKeys().where((key) => key.startsWith('plugin-manifest:'))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final manifest = jsonDecode(raw);
        if (manifest is Map<String, dynamic> && plugins.every((plugin) => plugin.id != manifest['id'])) {
          plugins.add(_fromManifest(manifest, builtIn: false));
        }
      } catch (_) {
        // Ignore a stale or malformed local manifest; it must not block login.
      }
    }
    notifyListeners();
  }

  Future<void> installManifestJson(String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('A plugin manifest must be a JSON object.');
    final manifest = Map<String, dynamic>.from(decoded);
    final plugin = _fromManifest(manifest, builtIn: false);
    if (plugin.id.isEmpty || plugin.name.isEmpty) throw const FormatException('Plugin id and name are required.');
    if (plugin.builtIn) throw const FormatException('Built-in plugins cannot be installed over local manifests.');
    final existing = plugins.indexWhere((item) => item.id == plugin.id);
    if (existing >= 0 && plugins[existing].builtIn) throw const FormatException('That id belongs to an MDless built-in plugin.');
    if (existing >= 0) plugins[existing] = plugin; else plugins.add(plugin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plugin-manifest:${plugin.id}', jsonEncode(manifestFor(plugin)));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final index = plugins.indexWhere((plugin) => plugin.id == id);
    if (index < 0 || plugins[index].builtIn) return;
    plugins.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('plugin-manifest:$id');
    await prefs.remove('plugin:$id');
    notifyListeners();
  }

  Map<String, dynamic> manifestFor(MdlessPlugin plugin) => {
        'id': plugin.id,
        'name': plugin.name,
        'description': plugin.description,
        'version': plugin.version,
        'author': plugin.author,
        'icon': plugin.icon,
        'accent': '#${plugin.accent.value.toRadixString(16).padLeft(8, '0')}',
        'permissions': plugin.permissions.map((permission) => permission.name).toList(),
        'actions': plugin.actions.map((action) => {
              'id': action.id,
              'label': action.label,
              'icon': _iconName(action.icon),
              'surface': action.surface.name,
              'command': action.command,
            }).toList(),
      };

  List<MdlessPluginAction> actionsFor(MdlessPluginSurface surface) => [
    for (final plugin in plugins)
      if (plugin.enabled) ...plugin.actions.where((action) => action.surface == surface),
  ];

  Future<void> dispatch(MdlessPluginEvent event) async {
    for (final plugin in plugins) {
      if (plugin.enabled && plugin.listener != null) await plugin.listener!(event);
    }
  }

  void toggle(String id) {
    final plugin = plugins.firstWhere((item) => item.id == id);
    plugin.enabled = !plugin.enabled;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('plugin:$id', plugin.enabled));
    notifyListeners();
  }

  MdlessPlugin _fromManifest(Map<String, dynamic> manifest, {required bool builtIn}) {
    final permissions = <MdlessPluginPermission>{};
    final rawPermissions = manifest['permissions'];
    if (rawPermissions is List) {
      for (final raw in rawPermissions) {
        final value = raw.toString();
        for (final permission in MdlessPluginPermission.values) {
          if (permission.name == value) permissions.add(permission);
        }
      }
    }
    final actions = <MdlessPluginAction>[];
    final rawActions = manifest['actions'];
    if (rawActions is List) {
      for (final raw in rawActions.whereType<Map>()) {
        final id = raw['id']?.toString().trim() ?? '';
        final label = raw['label']?.toString().trim() ?? '';
        final surfaceName = raw['surface']?.toString() ?? MdlessPluginSurface.chat.name;
        final surface = MdlessPluginSurface.values.firstWhere((value) => value.name == surfaceName, orElse: () => MdlessPluginSurface.chat);
        if (id.isNotEmpty && label.isNotEmpty) {
          actions.add(MdlessPluginAction(
            id: id,
            label: label,
            icon: _iconForName(raw['icon']?.toString()),
            surface: surface,
            command: _commandFor(raw['command']?.toString()),
          ));
        }
      }
    }
    return MdlessPlugin(
      id: manifest['id']?.toString().trim() ?? '',
      name: manifest['name']?.toString().trim() ?? '',
      description: manifest['description']?.toString().trim() ?? 'Installed MDless plugin.',
      icon: manifest['icon']?.toString() ?? '✦',
      accent: _parseAccent(manifest['accent']),
      version: manifest['version']?.toString() ?? '1.0.0',
      author: manifest['author']?.toString() ?? 'Local plugin',
      permissions: permissions,
      actions: actions,
      builtIn: builtIn,
    );
  }

  String _commandFor(String? command) {
    const allowed = {
      'focusChat',
      'clearFocus',
      'translateMessage',
      'inspectLink',
      'addReaction',
      'downloadMedia',
      'markRead',
      'muteChat',
      'copyMessage',
    };
    return allowed.contains(command) ? command! : 'showStatus';
  }

  Color _parseAccent(Object? raw) {
    final value = raw?.toString().replaceFirst('#', '');
    final parsed = value == null ? null : int.tryParse(value, radix: 16);
    return parsed == null ? const Color(0xFF6750A4) : Color(parsed);
  }

  IconData _iconForName(String? name) => switch (name) {
        'translate' => Icons.translate_rounded,
        'link' => Icons.link_rounded,
        'emoji' => Icons.emoji_emotions_rounded,
        'focus' => Icons.center_focus_strong_rounded,
        'settings' => Icons.settings_rounded,
        'search' => Icons.search_rounded,
        'download' => Icons.download_rounded,
        _ => Icons.bolt_rounded,
      };

  String _iconName(IconData icon) => switch (icon) {
        Icons.translate_rounded => 'translate',
        Icons.link_rounded => 'link',
        Icons.emoji_emotions_rounded => 'emoji',
        Icons.center_focus_strong_rounded => 'focus',
        Icons.settings_rounded => 'settings',
        Icons.search_rounded => 'search',
        Icons.download_rounded => 'download',
        _ => 'bolt',
      };
}
