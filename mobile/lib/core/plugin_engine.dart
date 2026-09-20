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

enum MdlessPluginEventType { appStarted, chatOpened, messageReceived, messageSent, composerOpened }

class MdlessPluginAction {
  const MdlessPluginAction({required this.id, required this.label, required this.icon, required this.surface});

  final String id;
  final String label;
  final IconData icon;
  final MdlessPluginSurface surface;
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
      actions: [MdlessPluginAction(id: 'focus-chat', label: 'Focus this chat', icon: Icons.center_focus_strong_rounded, surface: MdlessPluginSurface.chat)],
    ),
    MdlessPlugin(
      id: 'quick-translate',
      name: 'Quick translate',
      description: 'Add translation actions to message menus.',
      icon: '文',
      accent: const Color(0xFF246A9C),
      permissions: {MdlessPluginPermission.messages, MdlessPluginPermission.network},
      actions: [MdlessPluginAction(id: 'translate-message', label: 'Translate message', icon: Icons.translate_rounded, surface: MdlessPluginSurface.message)],
    ),
    MdlessPlugin(
      id: 'link-inspector',
      name: 'Link inspector',
      description: 'Preview links before opening them.',
      icon: '↗',
      accent: const Color(0xFF006B5F),
      permissions: {MdlessPluginPermission.messages, MdlessPluginPermission.network},
      actions: [MdlessPluginAction(id: 'inspect-link', label: 'Inspect link', icon: Icons.link_rounded, surface: MdlessPluginSurface.message)],
    ),
    MdlessPlugin(
      id: 'emoji-reactions',
      name: 'Emoji reactions',
      description: 'Bring expressive reactions to every chat.',
      icon: '☺',
      accent: const Color(0xFF8D5A00),
      permissions: {MdlessPluginPermission.messages},
      actions: [MdlessPluginAction(id: 'add-reaction', label: 'Add reaction', icon: Icons.emoji_emotions_rounded, surface: MdlessPluginSurface.message)],
    ),
  ];

  final List<MdlessPlugin> plugins;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final plugin in plugins) {
      plugin.enabled = prefs.getBool('plugin:${plugin.id}') ?? plugin.enabled;
    }
    notifyListeners();
  }

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
}
