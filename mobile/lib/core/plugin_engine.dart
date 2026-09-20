import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MdlessPlugin {
  MdlessPlugin({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final Color accent;
  bool enabled;
}

class PluginEngine extends ChangeNotifier {
  PluginEngine() : plugins = [
    MdlessPlugin(id: 'focus-mode', name: 'Focus mode', description: 'Hide distractions and keep one chat in view.', icon: '◒', accent: const Color(0xFF6750A4)),
    MdlessPlugin(id: 'quick-translate', name: 'Quick translate', description: 'Add translation actions to message menus.', icon: '文', accent: const Color(0xFF246A9C)),
    MdlessPlugin(id: 'link-inspector', name: 'Link inspector', description: 'Preview links before opening them.', icon: '↗', accent: const Color(0xFF006B5F)),
    MdlessPlugin(id: 'emoji-reactions', name: 'Emoji reactions', description: 'Bring expressive reactions to every chat.', icon: '☺', accent: const Color(0xFF8D5A00)),
  ];

  final List<MdlessPlugin> plugins;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final plugin in plugins) {
      plugin.enabled = prefs.getBool('plugin:${plugin.id}') ?? plugin.enabled;
    }
    notifyListeners();
  }

  void toggle(String id) {
    final plugin = plugins.firstWhere((item) => item.id == id);
    plugin.enabled = !plugin.enabled;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('plugin:$id', plugin.enabled));
    notifyListeners();
  }
}
