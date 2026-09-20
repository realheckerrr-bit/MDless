import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/chat_customizations.dart';
import 'core/plugin_engine.dart';
import 'core/tdlib_gateway.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MdlessBootstrap());
}

class MdlessBootstrap extends StatefulWidget {
  const MdlessBootstrap({super.key});

  @override
  State<MdlessBootstrap> createState() => _MdlessBootstrapState();
}

class _MdlessBootstrapState extends State<MdlessBootstrap> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MDless',
      themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: !controller.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : controller.signedIn
              ? MdlessHome(controller: controller)
              : LoginPage(controller: controller),
    ),
  );

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'sans',
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0, centerTitle: false),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, color: scheme.onSurface)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
    );
  }
}

class AppController extends ChangeNotifier {
  AppController() : gateway = TdlibGateway(), plugins = PluginEngine();

  final TdlibGateway gateway;
  final PluginEngine plugins;
  final chats = <ChatPreview>[
    ChatPreview(id: 1, name: 'MD3 Design Club', initials: 'MD', preview: 'Mira: the new motion spec is feeling ✨', time: '09:42', unread: 4, color: Color(0xFFFFB7A8), members: '8,240 members'),
    ChatPreview(id: 2, name: 'Sasha Volkov', initials: 'SV', preview: 'You: Sounds perfect — see you there!', time: '09:17', unread: 0, color: Color(0xFFD6C7FF), online: true),
    ChatPreview(id: 3, name: 'Night Owls', initials: 'NO', preview: 'Lena shared a voice message', time: 'Yesterday', unread: 12, color: Color(0xFFB6DDFF), members: '1,102 members'),
    ChatPreview(id: 4, name: 'Saved Messages', initials: '✦', preview: 'A quiet place for your thoughts', time: 'Mon', unread: 0, color: Color(0xFFA9EDDD)),
    ChatPreview(id: 5, name: 'Mira Chen', initials: 'MC', preview: 'Can you send me that link?', time: 'Sun', unread: 0, color: Color(0xFFF8D891), online: false),
  ];
  final messages = <int, List<MdMessage>>{
    1: [
      MdMessage(author: 'Mira Chen', initials: 'MC', text: 'Good morning, makers. I dropped the updated motion board in the files tab.', time: '09:31', incoming: true, color: Color(0xFFF8D891)),
      MdMessage(author: 'You', initials: 'YO', text: 'The little spring on the navigation rail is so good. It makes the whole thing feel alive.', time: '09:34', incoming: false, color: Color(0xFFD6C7FF), reactions: ['✨ 8']),
      MdMessage(author: 'Sasha Volkov', initials: 'SV', text: 'I’m voting for expressive corners everywhere. Let the cards breathe a little.', time: '09:37', incoming: true, color: Color(0xFFD6C7FF), reactions: ['💜 6']),
      MdMessage(author: 'Mira Chen', initials: 'MC', text: 'Exactly. Less dashboard, more room to think.', time: '09:42', incoming: true, color: Color(0xFFF8D891)),
    ],
    2: [
      MdMessage(author: 'Sasha Volkov', initials: 'SV', text: 'Hey! Are we still on for the tiny gallery opening?', time: '09:12', incoming: true, color: Color(0xFFD6C7FF)),
      MdMessage(author: 'You', initials: 'YO', text: 'Absolutely. I booked us a table around the corner for after.', time: '09:15', incoming: false, color: Color(0xFFD6C7FF)),
    ],
    3: [
      MdMessage(author: 'Lena Ortiz', initials: 'LO', text: 'Anyone awake? I found a beautiful late-night playlist.', time: '23:48', incoming: true, color: Color(0xFFFFB7A8), reactions: ['🎧 12']),
      MdMessage(author: 'You', initials: 'YO', text: 'Always. Send it over.', time: '23:51', incoming: false, color: Color(0xFFD6C7FF)),
    ],
    4: [MdMessage(author: 'You', initials: '✦', text: 'A quiet place for your thoughts.', time: 'Mon', incoming: false, color: Color(0xFFA9EDDD))],
    5: [MdMessage(author: 'Mira Chen', initials: 'MC', text: 'Can you send me that link when you have a second?', time: 'Sun', incoming: true, color: Color(0xFFF8D891))],
  };

  final customizations = <int, ChatCustomization>{};
  StreamSubscription<Map<String, dynamic>>? _updates;
  int? activeChatId;
  bool darkMode = false;
  bool initialized = false;
  bool connecting = false;
  String search = '';
  String authMessage = 'Sign in with your Telegram account to continue.';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool('dark-mode') ?? false;
    for (final chat in chats) {
      final accent = prefs.getInt('chat:${chat.id}:accent');
      if (accent != null) customizations[chat.id] = ChatCustomization(accent: Color(accent), compact: prefs.getBool('chat:${chat.id}:compact') ?? false, dottedWallpaper: prefs.getBool('chat:${chat.id}:dots') ?? false);
    }
    _updates = gateway.updates.listen(_handleUpdate);
    await plugins.restore();
    initialized = true;
    notifyListeners();
    final savedApiId = prefs.getString('telegram-api-id');
    final savedApiHash = prefs.getString('telegram-api-hash');
    if (savedApiId != null && savedApiHash != null && savedApiId.isNotEmpty && savedApiHash.isNotEmpty) {
      await connect(savedApiId, savedApiHash);
    }
  }

  TdAuthState get authState => gateway.authState;
  bool get signedIn => gateway.isAuthenticated;

  List<ChatPreview> get filteredChats => chats.where((chat) => chat.name.toLowerCase().contains(search.toLowerCase()) || chat.preview.toLowerCase().contains(search.toLowerCase())).toList();
  ChatPreview get activeChat => chats.firstWhere((chat) => chat.id == activeChatId);
  List<MdMessage> get activeMessages => messages[activeChatId] ?? const [];

  void selectChat(int id) { activeChatId = id; notifyListeners(); }
  void clearChat() { activeChatId = null; notifyListeners(); }
  void setSearch(String value) { search = value; notifyListeners(); }

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark-mode', darkMode);
    notifyListeners();
  }

  Future<void> connect(String apiIdText, String apiHash) async {
    final apiId = int.tryParse(apiIdText.trim()) ?? 0;
    if (apiId == 0 || apiHash.trim().isEmpty) {
      authMessage = 'Enter a valid Telegram API ID and API hash first.';
      notifyListeners();
      return;
    }
    connecting = true;
    authMessage = 'Starting secure Telegram connection…';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('telegram-api-id', apiId.toString());
      await prefs.setString('telegram-api-hash', apiHash.trim());
      await gateway.initialize(apiId: apiId, apiHash: apiHash.trim());
      authMessage = gateway.error ?? 'TDLib is ready — enter your phone number.';
      if (gateway.authState == TdAuthState.ready) await loadRemoteChats();
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    } finally {
      connecting = false;
    }
    notifyListeners();
  }

  Future<void> authenticatePhone(String phone) async {
    try {
      await gateway.sendPhone(phone.trim());
      authMessage = 'Code sent. Check Telegram or your SMS messages.';
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> authenticateCode(String code) async {
    try {
      await gateway.sendCode(code.trim());
      authMessage = 'Code accepted. Continue with your 2FA password if requested.';
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> authenticatePassword(String password) async {
    try {
      await gateway.sendPassword(password);
      authMessage = 'Signed in. Loading your Telegram chats…';
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> loadRemoteChats() async {
    if (!gateway.isAvailable) return;
    try {
      final remote = await gateway.loadChats();
      if (remote.isEmpty) return;
      chats
        ..clear()
        ..addAll(remote.map((chat) {
          final title = (chat['title'] ?? 'Telegram chat').toString();
          return ChatPreview(id: chat['id'] as int, name: title, initials: _initials(title), preview: 'Telegram conversation', time: '', unread: chat['unread_count'] as int? ?? 0, color: const Color(0xFFD6C7FF));
        }));
      notifyListeners();
    } catch (exception) { authMessage = exception.toString(); notifyListeners(); }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || activeChatId == null) return;
    final value = text.trim();
    if (gateway.authState == TdAuthState.ready) await gateway.sendMessage(activeChatId!, value);
    messages.putIfAbsent(activeChatId!, () => []).add(MdMessage(author: 'You', initials: 'YO', text: value, time: 'now', incoming: false, color: const Color(0xFFD6C7FF)));
    notifyListeners();
  }

  Future<void> loadActiveMessages() async {
    if (!gateway.isAvailable || activeChatId == null || gateway.authState != TdAuthState.ready) return;
    try {
      final remote = await gateway.loadMessages(activeChatId!);
      messages[activeChatId!] = remote.reversed.map((message) => MdMessage(author: message['is_outgoing'] == true ? 'You' : activeChat.name, initials: message['is_outgoing'] == true ? 'YO' : activeChat.initials, text: message['content']?['text']?['text']?.toString() ?? '', time: '', incoming: message['is_outgoing'] != true, color: activeChat.color)).toList();
      notifyListeners();
    } catch (_) {}
  }

  void customize(int chatId, ChatCustomization value) { customizations[chatId] = value; SharedPreferences.getInstance().then((prefs) { prefs.setInt('chat:$chatId:accent', value.accent.value); prefs.setBool('chat:$chatId:compact', value.compact); prefs.setBool('chat:$chatId:dots', value.dottedWallpaper); }); notifyListeners(); }

  void _handleUpdate(Map<String, dynamic> update) {
    if (update['@type'] == 'updateAuthorizationState') {
      if (gateway.isAuthenticated) unawaited(loadRemoteChats());
      notifyListeners();
    }
    if (update['@type'] == 'updateNewMessage') { notifyListeners(); }
  }

  String _initials(String title) => title.split(RegExp(r'\s+')).take(2).map((part) => part.isEmpty ? '' : part[0]).join().toUpperCase();

  @override
  void dispose() { _updates?.cancel(); gateway.dispose(); plugins.dispose(); super.dispose(); }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final apiId = TextEditingController();
  final apiHash = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  final firstName = TextEditingController();
  final lastName = TextEditingController();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      apiId.text = prefs.getString('telegram-api-id') ?? '';
      apiHash.text = prefs.getString('telegram-api-hash') ?? '';
    });
  }

  @override
  void dispose() {
    apiId.dispose(); apiHash.dispose(); phone.dispose(); code.dispose(); password.dispose(); firstName.dispose(); lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final state = controller.authState;
    final hasClient = controller.gateway.isAvailable;
    final needsApi = !hasClient && !controller.connecting;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 78, height: 78,
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(26)),
                  child: Icon(Icons.forum_rounded, size: 42, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 24),
                Text('Welcome to MDless', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
                const SizedBox(height: 8),
                Text('A native Telegram client with your chats, privacy, and plugins on-device.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 28),
                if (needsApi) ...[
                  _sectionTitle(context, 'Connect to Telegram'),
                  const SizedBox(height: 10),
                  Text('Create an API ID and hash at my.telegram.org. They are stored only on this device.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  TextField(controller: apiId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Telegram API ID', prefixIcon: Icon(Icons.numbers_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: apiHash, obscureText: true, decoration: const InputDecoration(labelText: 'Telegram API hash', prefixIcon: Icon(Icons.key_rounded))),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: controller.connecting ? null : () => controller.connect(apiId.text, apiHash.text), icon: const Icon(Icons.lock_open_rounded), label: const Text('Continue securely')),
                ] else if (controller.connecting) ...[
                  const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  Text(controller.authMessage, textAlign: TextAlign.center),
                ] else ...[
                  _authStep(context, controller, state),
                ],
                if (controller.authMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(controller.authMessage, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authStep(BuildContext context, AppController controller, TdAuthState state) {
    switch (state) {
      case TdAuthState.waitingPhone:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle(context, 'Your phone number'),
          const SizedBox(height: 8),
          const Text('Use the international format, for example +1 555 123 4567.'),
          const SizedBox(height: 16),
          TextField(controller: phone, autofocus: true, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_rounded))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => controller.authenticatePhone(phone.text), child: const Text('Send login code')),
        ]);
      case TdAuthState.waitingCode:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle(context, 'Enter the login code'),
          const SizedBox(height: 8),
          const Text('Telegram sent a code to one of your authorized devices or by SMS.'),
          const SizedBox(height: 16),
          TextField(controller: code, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Login code', prefixIcon: Icon(Icons.password_rounded))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => controller.authenticateCode(code.text), child: const Text('Verify code')),
        ]);
      case TdAuthState.waitingPassword:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle(context, 'Two-step verification'),
          const SizedBox(height: 8),
          const Text('Your Telegram account has an additional password.'),
          const SizedBox(height: 16),
          TextField(controller: password, autofocus: true, obscureText: true, decoration: const InputDecoration(labelText: '2FA password', prefixIcon: Icon(Icons.shield_rounded))),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => controller.authenticatePassword(password.text), child: const Text('Sign in')),
        ]);
      case TdAuthState.waitingRegistration:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sectionTitle(context, 'Create your Telegram profile'),
          const SizedBox(height: 16),
          TextField(controller: firstName, autofocus: true, decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 12),
          TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Last name (optional)')),
          const SizedBox(height: 16),
          FilledButton(onPressed: () async { try { await controller.gateway.registerUser(firstName: firstName.text.trim(), lastName: lastName.text.trim()); } catch (exception) { controller.authMessage = exception.toString(); controller.notifyListeners(); } }, child: const Text('Create account')),
        ]);
      case TdAuthState.waitingEmailAddress:
        return _emailStep(controller, false);
      case TdAuthState.waitingEmailCode:
        return _emailStep(controller, true);
      case TdAuthState.waitingOtherDeviceConfirmation:
        return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Confirm this login from your other Telegram device.')));
      case TdAuthState.ready:
        return const Center(child: CircularProgressIndicator());
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Telegram needs a connection to continue.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => setState(() {}), child: const Text('Try again')),
        ]);
    }
  }

  Widget _emailStep(AppController controller, bool codeStep) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _sectionTitle(context, codeStep ? 'Email verification code' : 'Telegram email verification'),
    const SizedBox(height: 16),
    TextField(controller: codeStep ? code : phone, keyboardType: codeStep ? TextInputType.number : TextInputType.emailAddress, decoration: InputDecoration(labelText: codeStep ? 'Email code' : 'Email address', prefixIcon: Icon(codeStep ? Icons.password_rounded : Icons.email_rounded))),
    const SizedBox(height: 16),
    FilledButton(onPressed: () async { try { if (codeStep) { await controller.gateway.sendEmailCode(code.text.trim()); } else { await controller.gateway.sendEmailAddress(phone.text.trim()); } } catch (exception) { controller.authMessage = exception.toString(); controller.notifyListeners(); } }, child: Text(codeStep ? 'Verify email code' : 'Send email code')),
  ]);

  Widget _sectionTitle(BuildContext context, String title) => Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800));
}

class MdlessHome extends StatefulWidget {
  const MdlessHome({required this.controller, super.key});
  final AppController controller;

  @override
  State<MdlessHome> createState() => _MdlessHomeState();
}

class _MdlessHomeState extends State<MdlessHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.plugins]),
      builder: (context, _) {
        if (controller.activeChatId != null) return ChatPage(controller: controller, chat: controller.activeChat, onBack: controller.clearChat);
        return Scaffold(
          appBar: AppBar(title: Text(tab == 0 ? 'Messages' : tab == 1 ? 'Saved' : 'Settings', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)), actions: [IconButton(onPressed: controller.toggleTheme, icon: Icon(controller.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded))]),
          body: IndexedStack(index: tab, children: [ChatsPage(controller: controller), SavedPage(controller: controller), SettingsPage(controller: controller)]),
          bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Chats'), NavigationDestination(icon: Icon(Icons.star_border_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Saved'), NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings')]),
        );
      },
    );
  }
}

class ChatsPage extends StatelessWidget {
  const ChatsPage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => SafeArea(child: Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: TextField(onChanged: controller.setSearch, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search conversations', suffixIcon: Icon(Icons.tune_rounded)))),
    Expanded(child: ListView.separated(padding: const EdgeInsets.fromLTRB(12, 0, 12, 20), itemCount: controller.filteredChats.length, separatorBuilder: (_, __) => const SizedBox(height: 4), itemBuilder: (context, index) { final chat = controller.filteredChats[index]; return ChatTile(chat: chat, onTap: () { controller.selectChat(chat.id); controller.loadActiveMessages(); }); })),
  ]));
}

class SavedPage extends StatelessWidget {
  const SavedPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Center(child: FilledButton.icon(onPressed: () { controller.selectChat(4); }, icon: const Icon(Icons.star_rounded), label: const Text('Open Saved Messages')));
}

class ChatTile extends StatelessWidget {
  const ChatTile({required this.chat, required this.onTap, super.key});
  final ChatPreview chat;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; return ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), tileColor: scheme.surfaceContainerLow, onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), leading: Avatar(chat: chat), title: Row(children: [Expanded(child: Text(chat.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))), Text(chat.time, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))]), subtitle: Row(children: [Expanded(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(chat.preview, maxLines: 1, overflow: TextOverflow.ellipsis))), if (chat.unread > 0) Padding(padding: const EdgeInsets.only(left: 6), child: CircleAvatar(radius: 10, backgroundColor: scheme.primary, child: Text('${chat.unread > 9 ? '9+' : chat.unread}', style: const TextStyle(fontSize: 9, color: Colors.white))))])); }
}

class ChatPage extends StatefulWidget {
  const ChatPage({required this.controller, required this.chat, required this.onBack, super.key});
  final AppController controller;
  final ChatPreview chat;
  final VoidCallback onBack;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final composer = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() { composer.dispose(); scroll.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final prefs = controller.customizations[widget.chat.id] ?? const ChatCustomization();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: widget.onBack, icon: const Icon(Icons.arrow_back_rounded)),
        titleSpacing: 0,
        title: Row(children: [
          Avatar(chat: widget.chat),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.chat.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(widget.chat.online ? 'online now' : (widget.chat.members ?? 'last seen recently'), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: () => showChatCustomization(context, controller, widget.chat), icon: const Icon(Icons.palette_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
            child: CustomPaint(
              painter: prefs.dottedWallpaper ? const DotPatternPainter() : null,
              child: ListView.builder(
                controller: scroll,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
                itemCount: controller.activeMessages.length,
                itemBuilder: (context, index) => MessageBubble(
                  message: controller.activeMessages[controller.activeMessages.length - 1 - index],
                  compact: prefs.compact,
                ),
              ),
            ),
          ),
        ),
        Composer(controller: controller, controllerText: composer, onSent: () {
          composer.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
          });
        }),
      ]),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  const DotPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: .06);
    for (var x = 8.0; x < size.width; x += 16) {
      for (var y = 8.0; y < size.height; y += 16) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotPatternPainter oldDelegate) => false;
}

class Composer extends StatelessWidget {
  const Composer({required this.controller, required this.controllerText, required this.onSent, super.key});
  final AppController controller;
  final TextEditingController controllerText;
  final VoidCallback onSent;
  @override
  Widget build(BuildContext context) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 7, 10, 10), child: Row(children: [IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline_rounded)), Expanded(child: TextField(controller: controllerText, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'Write a message…', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12))),), const SizedBox(width: 5), IconButton.filled(onPressed: () { controller.send(controllerText.text); onSent(); }, icon: const Icon(Icons.arrow_upward_rounded))])));
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, required this.compact, super.key});
  final MdMessage message;
  final bool compact;
  @override
  Widget build(BuildContext context) { final scheme = Theme.of(context).colorScheme; final color = message.incoming ? scheme.surfaceContainerHigh : scheme.primaryContainer; return Align(alignment: message.incoming ? Alignment.centerLeft : Alignment.centerRight, child: Padding(padding: EdgeInsets.only(bottom: compact ? 5 : 12), child: Row(mainAxisAlignment: message.incoming ? MainAxisAlignment.start : MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [if (message.incoming) Padding(padding: const EdgeInsets.only(right: 7), child: CircleAvatar(radius: 15, backgroundColor: message.color, child: Text(message.initials, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800))),), Flexible(child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(message.incoming ? 5 : 20), bottomRight: Radius.circular(message.incoming ? 20 : 5))), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(message.text), const SizedBox(height: 4), Row(mainAxisSize: MainAxisSize.min, children: [Text(message.time, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)), if (message.reactions.isNotEmpty) ...[const SizedBox(width: 8), Text(message.reactions.join('  '), style: const TextStyle(fontSize: 11))]])]))),]))); }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.controller, super.key});
  final AppController controller;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final apiId = TextEditingController();
  final apiHash = TextEditingController();
  final phone = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  @override
  void dispose() { apiId.dispose(); apiHash.dispose(); phone.dispose(); code.dispose(); password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { final controller = widget.controller; return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 36), children: [Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Telegram connection', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(controller.authMessage, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 14), TextField(controller: apiId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'API ID')), const SizedBox(height: 10), TextField(controller: apiHash, obscureText: true, decoration: const InputDecoration(labelText: 'API hash')), const SizedBox(height: 12), FilledButton.icon(onPressed: () => controller.connect(apiId.text, apiHash.text), icon: const Icon(Icons.lock_open_rounded), label: const Text('Initialize TDLib')), const SizedBox(height: 12), TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')), Row(children: [Expanded(child: OutlinedButton(onPressed: () => controller.authenticatePhone(phone.text), child: const Text('Send code'))), const SizedBox(width: 8), Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')))]), const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton(onPressed: () => controller.authenticateCode(code.text), child: const Text('Verify code'))), const SizedBox(width: 8), Expanded(child: TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: '2FA password')))]), const SizedBox(height: 8), OutlinedButton(onPressed: () => controller.authenticatePassword(password.text), child: const Text('Verify password'))]))), const SizedBox(height: 16), Text('Plugins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 8), ...controller.plugins.plugins.map((plugin) => Card(child: SwitchListTile(value: plugin.enabled, onChanged: (_) => controller.plugins.toggle(plugin.id), secondary: CircleAvatar(backgroundColor: plugin.accent, child: Text(plugin.icon)), title: Text(plugin.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(plugin.description)))), const SizedBox(height: 16), Card(child: ListTile(leading: const Icon(Icons.extension_rounded), title: const Text('Native plugin SDK'), subtitle: const Text('Plugins are compiled Flutter packages registered with PluginEngine. This keeps mobile permissions explicit and safe.')))]); }
}

Future<void> showChatCustomization(BuildContext context, AppController controller, ChatPreview chat) async { final current = controller.customizations[chat.id] ?? const ChatCustomization(); var value = current; await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, setState) => Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Customize ${chat.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 18), const Text('Accent color'), const SizedBox(height: 8), Wrap(spacing: 10, children: [Color(0xFF6750A4), Color(0xFF006B5F), Color(0xFF246A9C), Color(0xFF8D5A00), Color(0xFFBA1A1A)].map((color) => InkWell(onTap: () => setState(() => value = value.copyWith(accent: color)), borderRadius: BorderRadius.circular(99), child: CircleAvatar(radius: 18, backgroundColor: color, child: value.accent == color ? const Icon(Icons.check, color: Colors.white, size: 18) : null))).toList()), SwitchListTile(contentPadding: EdgeInsets.zero, value: value.compact, onChanged: (v) => setState(() => value = value.copyWith(compact: v)), title: const Text('Compact messages')), SwitchListTile(contentPadding: EdgeInsets.zero, value: value.dottedWallpaper, onChanged: (v) => setState(() => value = value.copyWith(dottedWallpaper: v)), title: const Text('Soft dot wallpaper')), FilledButton(onPressed: () { controller.customize(chat.id, value); Navigator.pop(context); }, child: const Text('Save chat style'))])))); }

class Avatar extends StatelessWidget {
  const Avatar({required this.chat, super.key});
  final ChatPreview chat;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: 25, backgroundColor: chat.color, child: Text(chat.initials, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF241B2B))));
}

class ChatPreview {
  ChatPreview({required this.id, required this.name, required this.initials, required this.preview, required this.time, required this.unread, required this.color, this.members, this.online = false});
  final int id;
  final String name;
  final String initials;
  final String preview;
  final String time;
  final int unread;
  final Color color;
  final String? members;
  final bool online;
}

class MdMessage {
  MdMessage({required this.author, required this.initials, required this.text, required this.time, required this.incoming, required this.color, this.reactions = const []});
  final String author;
  final String initials;
  final String text;
  final String time;
  final bool incoming;
  final Color color;
  final List<String> reactions;
}
