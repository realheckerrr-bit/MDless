import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/chat_customizations.dart';
import 'core/music_player.dart';
import 'core/plugin_engine.dart';
import 'core/tdlib_gateway.dart';

const _bundledTelegramApiId = String.fromEnvironment('TELEGRAM_API_ID');
const _bundledTelegramApiHash = String.fromEnvironment('TELEGRAM_API_HASH');

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
      fontFamily: 'GoogleSansFlex',
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
  AppController() : gateway = TdlibGateway(), plugins = PluginEngine(), music = MusicPlayerController() {
    music.addListener(notifyListeners);
  }

  final TdlibGateway gateway;
  final PluginEngine plugins;
  final MusicPlayerController music;
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
  final searchedMessages = <int, List<MdMessage>>{};

  final customizations = <int, ChatCustomization>{};
  StreamSubscription<Map<String, dynamic>>? _updates;
  int? activeChatId;
  bool darkMode = false;
  bool initialized = false;
  bool connecting = false;
  String search = '';
  String authMessage = 'Sign in with your Telegram account to continue.';
  String emojiStyle = 'Telegram iOS';
  String iconPack = 'Material You';
  int? activeCallId;
  String? activeCallState;
  Map<String, dynamic>? currentUser;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    darkMode = prefs.getBool('dark-mode') ?? false;
    emojiStyle = prefs.getString('emoji-style') ?? 'Telegram iOS';
    iconPack = prefs.getString('icon-pack') ?? 'Material You';
    for (final chat in chats) {
      final accent = prefs.getInt('chat:${chat.id}:accent');
      if (accent != null) customizations[chat.id] = ChatCustomization(accent: Color(accent), compact: prefs.getBool('chat:${chat.id}:compact') ?? false, dottedWallpaper: prefs.getBool('chat:${chat.id}:dots') ?? false);
    }
    _updates = gateway.updates.listen(_handleUpdate);
    await plugins.restore();
    initialized = true;
    notifyListeners();
    final savedApiId = prefs.getString('telegram-api-id') ?? _bundledTelegramApiId;
    final savedApiHash = prefs.getString('telegram-api-hash') ?? _bundledTelegramApiHash;
    if (savedApiId.isNotEmpty && savedApiHash.isNotEmpty) {
      await connect(savedApiId, savedApiHash);
    }
  }

  TdAuthState get authState => gateway.authState;
  bool get signedIn => gateway.isAuthenticated;

  List<ChatPreview> get filteredChats => chats.where((chat) => chat.name.toLowerCase().contains(search.toLowerCase()) || chat.preview.toLowerCase().contains(search.toLowerCase())).toList();
  ChatPreview get activeChat => chats.firstWhere((chat) => chat.id == activeChatId);
  List<MdMessage> get activeMessages => searchedMessages[activeChatId] ?? messages[activeChatId] ?? const [];

  void selectChat(int id) {
    activeChatId = id;
    searchedMessages.remove(id);
    unawaited(plugins.dispatch(MdlessPluginEvent(type: MdlessPluginEventType.chatOpened, chatId: id)));
    notifyListeners();
  }
  void clearChat() { activeChatId = null; notifyListeners(); }
  void setSearch(String value) { search = value; notifyListeners(); }

  Future<void> searchMessages(String query) async {
    final chatId = activeChatId;
    if (chatId == null) return;
    final value = query.trim();
    if (value.isEmpty) {
      searchedMessages.remove(chatId);
      notifyListeners();
      return;
    }
    try {
      final remote = await gateway.searchChatMessages(chatId, value);
      searchedMessages[chatId] = _mapRemoteMessages(remote);
      notifyListeners();
    } catch (exception) {
      authMessage = 'Search error: $exception';
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark-mode', darkMode);
    notifyListeners();
  }

  Future<void> setEmojiStyle(String value) async {
    emojiStyle = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emoji-style', value);
    notifyListeners();
  }

  Future<void> setIconPack(String value) async {
    iconPack = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('icon-pack', value);
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
      if (gateway.authState == TdAuthState.ready) {
        await loadCurrentUser();
        await loadRemoteChats();
      }
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    } finally {
      connecting = false;
    }
    notifyListeners();
  }

  Future<void> authenticatePhone(String phone) async {
    if (!gateway.isAvailable) {
      authMessage = 'This build is not connected to a Telegram API client yet. Open Advanced client setup below, or ship with TELEGRAM_API_ID and TELEGRAM_API_HASH.';
      notifyListeners();
      return;
    }
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

  Future<void> registerUser(String firstName, String lastName) async {
    try {
      await gateway.registerUser(firstName: firstName.trim(), lastName: lastName.trim());
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> authenticateEmailAddress(String email) async {
    try {
      await gateway.sendEmailAddress(email.trim());
    } catch (exception) {
      authMessage = exception.toString().replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  Future<void> authenticateEmailCode(String code) async {
    try {
      await gateway.sendEmailCode(code.trim());
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
        ..addAll(remote.map(_chatPreviewFromRemote));
      notifyListeners();
    } catch (exception) { authMessage = exception.toString(); notifyListeners(); }
  }

  ChatPreview _chatPreviewFromRemote(Map<String, dynamic> chat) {
    final title = (chat['title'] ?? 'Telegram chat').toString();
    final type = chat['type'];
    final typeName = type is Map ? type['@type']?.toString() : null;
    final userId = typeName == 'chatTypePrivate' && type is Map ? type['user_id'] as int? : null;
    return ChatPreview(
      id: chat['id'] as int,
      name: title,
      initials: _initials(title),
      preview: 'Telegram conversation',
      time: '',
      unread: chat['unread_count'] as int? ?? 0,
      color: const Color(0xFFD6C7FF),
      members: switch (typeName) {
        'chatTypeBasicGroup' => 'Group',
        'chatTypeSupergroup' => 'Group or channel',
        _ => null,
      },
      userId: userId,
    );
  }

  Future<bool> startNewChat(String query) async {
    final value = query.trim();
    if (value.isEmpty || !gateway.isAuthenticated) return false;
    try {
      Map<String, dynamic> remoteChat;
      if (value.startsWith('@')) {
        remoteChat = await gateway.searchPublicChat(value);
      } else {
        final users = await gateway.searchContacts(value);
        if (users.isEmpty) {
          authMessage = 'No Telegram contact or username was found.';
          notifyListeners();
          return false;
        }
        final userId = users.first['id'] as int?;
        if (userId == null) return false;
        remoteChat = await gateway.createPrivateChat(userId);
      }
      final chat = _chatPreviewFromRemote(remoteChat);
      chats.removeWhere((item) => item.id == chat.id);
      chats.insert(0, chat);
      selectChat(chat.id);
      await loadActiveMessages();
      return true;
    } catch (exception) {
      authMessage = 'Could not open chat: $exception';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadCurrentUser() async {
    if (!gateway.isAuthenticated) return;
    try {
      currentUser = await gateway.loadCurrentUser();
      notifyListeners();
    } catch (exception) {
      authMessage = 'Profile error: $exception';
      notifyListeners();
    }
  }

  Future<void> logOut() async {
    try {
      await gateway.logOut();
      currentUser = null;
      activeChatId = null;
      chats
        ..clear()
        ..addAll([
          ChatPreview(id: 1, name: 'MD3 Design Club', initials: 'MD', preview: 'Mira: the new motion spec is feeling ✨', time: '09:42', unread: 4, color: const Color(0xFFFFB7A8), members: '8,240 members'),
          ChatPreview(id: 2, name: 'Sasha Volkov', initials: 'SV', preview: 'You: Sounds perfect — see you there!', time: '09:17', unread: 0, color: const Color(0xFFD6C7FF), online: true),
        ]);
      notifyListeners();
    } catch (exception) {
      authMessage = 'Could not sign out: $exception';
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || activeChatId == null) return;
    final value = text.trim();
    if (gateway.authState == TdAuthState.ready) await gateway.sendMessage(activeChatId!, value);
    messages.putIfAbsent(activeChatId!, () => []).add(MdMessage(author: 'You', initials: 'YO', text: value, time: 'now', incoming: false, color: const Color(0xFFD6C7FF)));
    unawaited(plugins.dispatch(MdlessPluginEvent(type: MdlessPluginEventType.messageSent, chatId: activeChatId, payload: {'text': value})));
    notifyListeners();
  }

  Future<void> runPluginAction(MdlessPluginAction action, {int? chatId}) async {
    await plugins.dispatch(MdlessPluginEvent(type: MdlessPluginEventType.chatOpened, chatId: chatId, payload: {'action': action.id}));
    authMessage = 'Plugin action: ${action.label}';
    notifyListeners();
  }

  Future<void> pickAndSendAttachment() async {
    final chatId = activeChatId;
    if (chatId == null || !gateway.isAuthenticated) return;
    final result = await FilePicker.pickFiles(type: FileType.any, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null || path.isEmpty) return;
    final name = result.files.single.name;
    try {
      authMessage = 'Uploading $name…';
      notifyListeners();
      await gateway.sendLocalFile(chatId, path);
      messages.putIfAbsent(chatId, () => []).add(MdMessage(author: 'You', initials: 'YO', text: name, time: 'now', incoming: false, color: const Color(0xFFD6C7FF), mediaName: name, mediaKind: 'document'));
      authMessage = 'Sent $name.';
      notifyListeners();
    } catch (exception) {
      authMessage = 'Upload error: $exception';
      notifyListeners();
    }
  }

  Future<void> loadActiveMessages() async {
    if (!gateway.isAvailable || activeChatId == null || gateway.authState != TdAuthState.ready) return;
    try {
      final remote = await gateway.loadMessages(activeChatId!);
      messages[activeChatId!] = _mapRemoteMessages(remote.reversed, chat: activeChat);
      await gateway.markMessagesRead(activeChatId!, remote.map((message) => message['id']).whereType<int>().toList());
      notifyListeners();
    } catch (_) {}
  }

  List<MdMessage> _mapRemoteMessages(Iterable<Map<String, dynamic>> remote, {ChatPreview? chat}) {
    final conversation = chat ?? activeChat;
    return remote.map((message) {
      final content = message['content'] as Map?;
      final type = content?['@type']?.toString() ?? '';
      final payload = switch (type) {
        'messageAudio' => content?['audio'] as Map?,
        'messageVoiceNote' => content?['voice_note'] as Map?,
        'messagePhoto' => content?['photo'] as Map?,
        'messageVideo' => content?['video'] as Map?,
        'messageDocument' => content?['document'] as Map?,
        'messageAnimation' => content?['animation'] as Map?,
        _ => null,
      };
      final file = type == 'messagePhoto'
          ? ((payload?['sizes'] as List?)?.whereType<Map>().isNotEmpty ?? false ? ((payload!['sizes'] as List).last as Map)['photo'] as Map? : null)
          : payload?[switch (type) {
              'messageAudio' => 'audio',
              'messageVoiceNote' => 'voice',
              'messageVideo' => 'video',
              'messageDocument' => 'document',
              'messageAnimation' => 'animation',
              _ => 'file',
            }] as Map?;
      final fileId = file?['id'] as int?;
      final textContent = content?['text'];
      final caption = content?['caption'];
      final captionText = caption is Map ? caption['text']?.toString() : null;
      final text = type == 'messageText'
          ? (textContent is Map ? textContent['text']?.toString() ?? '' : '')
          : captionText?.isNotEmpty == true
              ? captionText!
              : switch (type) {
                  'messageAudio' => '${payload?['performer'] ?? ''} ${payload?['title'] ?? 'Audio'}'.trim(),
                  'messageVoiceNote' => 'Voice message',
                  'messagePhoto' => 'Photo',
                  'messageVideo' => 'Video',
                  'messageDocument' => payload?['file_name']?.toString() ?? 'Document',
                  'messageAnimation' => 'Animation',
                  _ => 'Telegram attachment',
                };
      final mediaKind = switch (type) {
        'messageAudio' => 'audio',
        'messageVoiceNote' => 'voice',
        'messagePhoto' => 'photo',
        'messageVideo' => 'video',
        'messageDocument' => 'document',
        'messageAnimation' => 'animation',
        _ => null,
      };
      final authorIsMe = message['is_outgoing'] == true;
      return MdMessage(
        telegramId: message['id'] as int?,
        author: authorIsMe ? 'You' : conversation.name,
        initials: authorIsMe ? 'YO' : conversation.initials,
        text: text,
        time: _messageTime(message['date']),
        incoming: !authorIsMe,
        color: conversation.color,
        audioFileId: mediaKind == 'audio' || mediaKind == 'voice' ? fileId : null,
        audioTitle: payload?['title']?.toString(),
        audioPerformer: payload?['performer']?.toString(),
        mediaFileId: fileId,
        mediaKind: mediaKind,
        mediaName: type == 'messageDocument' && payload != null ? payload['file_name']?.toString() : null,
      );
    }).toList();
  }

  String _messageTime(Object? epoch) {
    final seconds = epoch is int ? epoch : 0;
    if (seconds == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void customize(int chatId, ChatCustomization value) { customizations[chatId] = value; SharedPreferences.getInstance().then((prefs) { prefs.setInt('chat:$chatId:accent', value.accent.value); prefs.setBool('chat:$chatId:compact', value.compact); prefs.setBool('chat:$chatId:dots', value.dottedWallpaper); }); notifyListeners(); }

  Future<void> playAudio(MdMessage message) async {
    final fileId = message.audioFileId;
    if (fileId == null || !gateway.isAuthenticated) return;
    try {
      final path = await gateway.downloadFile(fileId);
      if (path != null) await music.playFile(id: fileId, path: path, trackTitle: message.audioTitle ?? message.text, trackPerformer: message.audioPerformer);
    } catch (exception) {
      authMessage = 'Audio error: $exception';
      notifyListeners();
    }
  }

  Future<void> downloadMedia(MdMessage message) async {
    final fileId = message.mediaFileId;
    if (fileId == null || !gateway.isAuthenticated) return;
    try {
      final path = await gateway.downloadFile(fileId);
      authMessage = path == null ? 'Telegram could not download this file.' : 'Downloaded ${message.text} to the app storage.';
      notifyListeners();
    } catch (exception) {
      authMessage = 'Download error: $exception';
      notifyListeners();
    }
  }

  Future<void> startVoiceCall(ChatPreview chat) async {
    final userId = chat.userId;
    if (userId == null || !gateway.isAuthenticated) return;
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      authMessage = 'Microphone permission is required for Telegram calls.';
      notifyListeners();
      return;
    }
    try {
      await gateway.createCall(userId: userId);
      authMessage = 'Calling ${chat.name}…';
    } catch (exception) {
      authMessage = 'Call error: $exception';
    }
    notifyListeners();
  }

  Future<void> acceptActiveCall() async {
    final callId = activeCallId;
    if (callId == null) return;
    try {
      await gateway.acceptCall(callId);
      authMessage = 'Call connected.';
    } catch (exception) {
      authMessage = 'Call error: $exception';
    }
    notifyListeners();
  }

  Future<void> endActiveCall() async {
    final callId = activeCallId;
    if (callId == null) return;
    try {
      await gateway.discardCall(callId);
    } catch (exception) {
      authMessage = 'Call error: $exception';
    }
    activeCallId = null;
    activeCallState = null;
    notifyListeners();
  }

  void _handleUpdate(Map<String, dynamic> update) {
    if (update['@type'] == 'updateCall') {
      final call = update['call'];
      if (call is Map) {
        final state = call['state'];
        activeCallId = call['id'] as int?;
        activeCallState = state is Map ? state['@type']?.toString() : null;
        if (activeCallState == 'callStateDiscarded') {
          activeCallId = null;
          activeCallState = null;
        }
        notifyListeners();
      }
    }
    if (update['@type'] == 'updateAuthorizationState') {
      if (gateway.isAuthenticated) {
        unawaited(loadCurrentUser());
        unawaited(loadRemoteChats());
      }
      notifyListeners();
    }
    if (update['@type'] == 'updateUser') {
      final user = update['user'];
      if (user is Map && user['id'] == currentUser?['id']) {
        currentUser = Map<String, dynamic>.from(user);
        notifyListeners();
      }
    }
    if (update['@type'] == 'updateNewMessage') {
      final chatId = update['chat_id'] as int?;
      final message = update['message'];
      if (chatId != null && message is Map) {
        final conversationIndex = chats.indexWhere((chat) => chat.id == chatId);
        if (conversationIndex >= 0) {
          final conversation = chats[conversationIndex];
          final typedMessage = Map<String, dynamic>.from(message);
          final incoming = typedMessage['is_outgoing'] != true;
          if (activeChatId == chatId) {
            if (incoming) {
              messages.putIfAbsent(chatId, () => []).add(_mapRemoteMessages([typedMessage], chat: conversation).single);
              unawaited(gateway.markMessagesRead(chatId, [typedMessage['id'] as int]));
            }
          } else {
            chats[conversationIndex] = conversation.copyWith(
              preview: _messagePreview(typedMessage),
              time: _messageTime(typedMessage['date']),
              unread: conversation.unread + (incoming ? 1 : 0),
            );
          }
          if (incoming) {
            unawaited(plugins.dispatch(MdlessPluginEvent(type: MdlessPluginEventType.messageReceived, chatId: chatId, messageId: typedMessage['id'] as int?, payload: {'type': _messagePreview(typedMessage)})));
          }
        }
      }
      notifyListeners();
    }
  }

  String _messagePreview(Map<String, dynamic> message) {
    final content = message['content'] as Map?;
    final type = content?['@type']?.toString();
    if (type == 'messageText') {
      final text = content?['text'];
      return text is Map ? text['text']?.toString() ?? 'New message' : 'New message';
    }
    return switch (type) {
      'messagePhoto' => 'Photo',
      'messageVideo' => 'Video',
      'messageAudio' => 'Audio',
      'messageVoiceNote' => 'Voice message',
      'messageDocument' => 'Document',
      'messageAnimation' => 'Animation',
      _ => 'New Telegram message',
    };
  }

  String _initials(String title) => title.split(RegExp(r'\s+')).take(2).map((part) => part.isEmpty ? '' : part[0]).join().toUpperCase();

  @override
  void dispose() { _updates?.cancel(); music.removeListener(notifyListeners); music.dispose(); gateway.dispose(); plugins.dispose(); super.dispose(); }
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
                if (controller.connecting) ...[
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
          FilledButton(onPressed: () => controller.registerUser(firstName.text, lastName.text), child: const Text('Create account')),
        ]);
      case TdAuthState.waitingEmailAddress:
        return _emailStep(controller, false);
      case TdAuthState.waitingEmailCode:
        return _emailStep(controller, true);
      case TdAuthState.waitingOtherDeviceConfirmation:
        return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Confirm this login from your other Telegram device.')));
      case TdAuthState.ready:
        return const Center(child: CircularProgressIndicator());
      case TdAuthState.unavailable:
        return _normalPhoneStep(context, controller);
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Telegram needs a connection to continue.', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => setState(() {}), child: const Text('Try again')),
        ]);
    }
  }

  Widget _normalPhoneStep(BuildContext context, AppController controller) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _sectionTitle(context, 'Sign in to Telegram'),
    const SizedBox(height: 8),
    const Text('Enter your phone number. Telegram will send a sign-in code to your authorized devices or by SMS.'),
    const SizedBox(height: 16),
    TextField(controller: phone, autofocus: true, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+1 555 123 4567', prefixIcon: Icon(Icons.phone_rounded))),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () => controller.authenticatePhone(phone.text), icon: const Icon(Icons.arrow_forward_rounded), label: const Text('Continue')),
    const SizedBox(height: 8),
    TextButton.icon(onPressed: () => _showAdvancedSetup(context, controller), icon: const Icon(Icons.tune_rounded), label: const Text('Advanced client setup')),
  ]);

  Future<void> _showAdvancedSetup(BuildContext context, AppController controller) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Advanced client setup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Most users should only enter their phone number. A Telegram API ID and hash are required by TDLib and are stored locally.'),
          const SizedBox(height: 16),
          TextField(controller: apiId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'API ID', prefixIcon: Icon(Icons.numbers_rounded))),
          const SizedBox(height: 10),
          TextField(controller: apiHash, obscureText: true, decoration: const InputDecoration(labelText: 'API hash', prefixIcon: Icon(Icons.key_rounded))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () { Navigator.pop(dialogContext); controller.connect(apiId.text, apiHash.text); }, child: const Text('Connect')),
        ],
      ),
    );
  }

  Widget _emailStep(AppController controller, bool codeStep) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _sectionTitle(context, codeStep ? 'Email verification code' : 'Telegram email verification'),
    const SizedBox(height: 16),
    TextField(controller: codeStep ? code : phone, keyboardType: codeStep ? TextInputType.number : TextInputType.emailAddress, decoration: InputDecoration(labelText: codeStep ? 'Email code' : 'Email address', prefixIcon: Icon(codeStep ? Icons.password_rounded : Icons.email_rounded))),
    const SizedBox(height: 16),
    FilledButton(onPressed: () => codeStep ? controller.authenticateEmailCode(code.text) : controller.authenticateEmailAddress(phone.text), child: Text(codeStep ? 'Verify email code' : 'Send email code')),
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
      animation: Listenable.merge([controller, controller.plugins, controller.music]),
      builder: (context, _) {
        if (controller.activeChatId != null) return ChatPage(controller: controller, chat: controller.activeChat, onBack: controller.clearChat);
        return Scaffold(
          appBar: AppBar(title: Text(tab == 0 ? 'Messages' : tab == 1 ? 'Saved' : 'Settings', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5)), actions: [if (tab == 0) IconButton(onPressed: () => showNewChatDialog(context, controller), icon: const Icon(Icons.edit_square_rounded), tooltip: 'New chat'), IconButton(onPressed: controller.toggleTheme, icon: Icon(controller.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded))]),
          body: Column(children: [if (controller.activeCallId != null) CallBanner(controller: controller), Expanded(child: IndexedStack(index: tab, children: [ChatsPage(controller: controller), SavedPage(controller: controller), SettingsPage(controller: controller)]))]),
          bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [if (controller.music.hasTrack) MusicMiniPlayer(player: controller.music), NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Chats'), NavigationDestination(icon: Icon(Icons.star_border_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Saved'), NavigationDestination(icon: Icon(Icons.tune_rounded), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings')])]),
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

class MusicMiniPlayer extends StatelessWidget {
  const MusicMiniPlayer({required this.player, super.key});
  final MusicPlayerController player;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: ListTile(
          dense: true,
          onTap: () => showMusicPlayer(context, player),
          leading: const CircleAvatar(child: Icon(Icons.music_note_rounded)),
          title: Text(player.title ?? 'Telegram audio', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(player.performer ?? 'MDless player', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(onPressed: player.toggle, icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
        ),
      );

}

Future<void> showMusicPlayer(BuildContext context, MusicPlayerController player) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MusicPlayerSheet(player: player),
    );

class MusicPlayerSheet extends StatelessWidget {
  const MusicPlayerSheet({required this.player, super.key});
  final MusicPlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = player.duration.inMilliseconds > 0 ? player.duration.inMilliseconds.toDouble() : 1.0;
    final value = player.position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 112, height: 112, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(32)), child: Icon(Icons.music_note_rounded, size: 58, color: scheme.onPrimaryContainer)),
        const SizedBox(height: 20),
        Text(player.title ?? 'Telegram audio', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(player.performer ?? 'MDless player', style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Slider(value: value, max: max, onChanged: player.duration == Duration.zero ? null : (value) => player.seek(Duration(milliseconds: value.round()))),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_durationText(player.position)), Text(_durationText(player.duration))]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => player.seek(player.position - const Duration(seconds: 10)), icon: const Icon(Icons.replay_10_rounded), iconSize: 30),
          const SizedBox(width: 16),
          IconButton.filled(onPressed: player.loading ? null : player.toggle, icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded), iconSize: 34),
          const SizedBox(width: 16),
          IconButton(onPressed: () => player.seek(player.position + const Duration(seconds: 30)), icon: const Icon(Icons.forward_30_rounded), iconSize: 30),
        ]),
      ]),
    ));
  }

  String _durationText(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${value.inHours > 0 ? '${value.inHours}:' : ''}$minutes:$seconds';
  }
}

class CallBanner extends StatelessWidget {
  const CallBanner({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final incoming = controller.activeCallState == 'callStatePending';
    final connected = controller.activeCallState == 'callStateReady' || controller.activeCallState == 'callStateExchangingKeys';
    return Material(
      color: connected ? Theme.of(context).colorScheme.tertiaryContainer : Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(top: false, child: ListTile(
        leading: Icon(connected ? Icons.call_rounded : Icons.ring_volume_rounded),
        title: Text(incoming ? 'Incoming Telegram call' : connected ? 'Telegram call connected' : 'Telegram call connecting…'),
        subtitle: Text(controller.activeCallState ?? 'call'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (incoming) IconButton(onPressed: controller.acceptActiveCall, icon: const Icon(Icons.call_rounded)),
          IconButton(onPressed: controller.endActiveCall, icon: const Icon(Icons.call_end_rounded)),
        ]),
      )),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => Center(child: FilledButton.icon(onPressed: () { controller.selectChat(4); }, icon: const Icon(Icons.star_rounded), label: const Text('Open Saved Messages')));
}

Future<void> showNewChatDialog(BuildContext context, AppController controller) async {
  final query = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New Telegram chat'),
      content: TextField(controller: query, autofocus: true, textInputAction: TextInputAction.search, decoration: const InputDecoration(labelText: 'Username or contact', hintText: '@username')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, query.text), child: const Text('Open chat')),
      ],
    ),
  );
  query.dispose();
  if (value == null || !context.mounted) return;
  final opened = await controller.startNewChat(value);
  if (!opened && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(controller.authMessage)));
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
          if (widget.chat.userId != null) IconButton(onPressed: () => controller.startVoiceCall(widget.chat), icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () => _searchMessages(context), icon: const Icon(Icons.manage_search_rounded)),
          IconButton(onPressed: () => showChatCustomization(context, controller, widget.chat), icon: const Icon(Icons.palette_outlined)),
          IconButton(onPressed: () => showPluginActions(context, controller, widget.chat), icon: const Icon(Icons.more_vert_rounded)),
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
                  onMediaTap: (message) => message.audioFileId != null ? controller.playAudio(message) : controller.downloadMedia(message),
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

  Future<void> _searchMessages(BuildContext context) async {
    final field = TextEditingController();
    final query = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search this chat'),
        content: TextField(controller: field, autofocus: true, textInputAction: TextInputAction.search, decoration: const InputDecoration(hintText: 'Search messages')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, field.text), child: const Text('Search')),
        ],
      ),
    );
    field.dispose();
    if (query != null) await widget.controller.searchMessages(query);
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
  Widget build(BuildContext context) => SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 7, 10, 10), child: Row(children: [IconButton(onPressed: controller.pickAndSendAttachment, icon: const Icon(Icons.add_circle_outline_rounded)), Expanded(child: TextField(controller: controllerText, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'Write a message…', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12))),), const SizedBox(width: 5), IconButton.filled(onPressed: () { controller.send(controllerText.text); onSent(); }, icon: const Icon(Icons.arrow_upward_rounded))])));
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, required this.compact, required this.onMediaTap, super.key});
  final MdMessage message;
  final bool compact;
  final ValueChanged<MdMessage> onMediaTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = message.incoming ? scheme.surfaceContainerHigh : scheme.primaryContainer;
    final content = message.mediaFileId == null
        ? Text(message.text)
        : InkWell(
            onTap: () => onMediaTap(message),
            borderRadius: BorderRadius.circular(14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_mediaIcon(message.mediaKind), color: scheme.primary),
              const SizedBox(width: 10),
              Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(message.mediaName ?? message.audioTitle ?? message.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (message.audioPerformer != null) Text(message.audioPerformer!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ])),
            ]),
          );
    return Align(
      alignment: message.incoming ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(bottom: compact ? 5 : 12),
        child: Row(mainAxisAlignment: message.incoming ? MainAxisAlignment.start : MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (message.incoming) Padding(padding: const EdgeInsets.only(right: 7), child: CircleAvatar(radius: 15, backgroundColor: message.color, child: Text(message.initials, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)))),
          Flexible(child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.only(topLeft: const Radius.circular(20), topRight: const Radius.circular(20), bottomLeft: Radius.circular(message.incoming ? 5 : 20), bottomRight: Radius.circular(message.incoming ? 20 : 5))),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              content,
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(message.time, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                if (message.reactions.isNotEmpty) ...[const SizedBox(width: 8), Text(message.reactions.join('  '), style: const TextStyle(fontSize: 11))],
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  IconData _mediaIcon(String? kind) => switch (kind) {
    'photo' => Icons.image_rounded,
    'video' => Icons.video_file_rounded,
    'document' => Icons.description_rounded,
    'animation' => Icons.gif_box_rounded,
    'voice' => Icons.mic_rounded,
    _ => Icons.audio_file_rounded,
  };
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
  void dispose() { apiId.dispose(); apiHash.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final user = controller.currentUser;
    final displayName = user == null ? 'Telegram account' : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
    final username = user?['usernames'] is Map ? (user?['usernames'] as Map)['active_usernames'] : null;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 36), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        CircleAvatar(radius: 28, child: Text(displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase())),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName.isEmpty ? 'Telegram account' : displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (username is List && username.isNotEmpty) Text('@${username.first}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(user == null ? 'Connected through TDLib' : 'Telegram profile', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        IconButton(onPressed: controller.loadCurrentUser, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh profile'),
      ]))),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Telegram connection', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(controller.authMessage, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        TextField(controller: apiId, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'API ID')),
        const SizedBox(height: 10),
        TextField(controller: apiHash, obscureText: true, decoration: const InputDecoration(labelText: 'API hash')),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => controller.connect(apiId.text, apiHash.text), icon: const Icon(Icons.lock_open_rounded), label: const Text('Reconnect TDLib')),
      ]))),
      const SizedBox(height: 16),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Appearance packs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: controller.emojiStyle, decoration: const InputDecoration(labelText: 'Emoji style'), items: const [DropdownMenuItem(value: 'Telegram iOS', child: Text('Telegram iOS')), DropdownMenuItem(value: 'Google Noto', child: Text('Google Noto')), DropdownMenuItem(value: 'Samsung', child: Text('Samsung'))], onChanged: (value) { if (value != null) controller.setEmojiStyle(value); }),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: controller.iconPack, decoration: const InputDecoration(labelText: 'Icon pack'), items: const [DropdownMenuItem(value: 'Material You', child: Text('Material You')), DropdownMenuItem(value: 'Telegram Classic', child: Text('Telegram Classic')), DropdownMenuItem(value: 'Expressive Rounded', child: Text('Expressive Rounded'))], onChanged: (value) { if (value != null) controller.setIconPack(value); }),
        const SizedBox(height: 8),
        Text('Emoji and icon packs are selected per device and do not change Telegram server data.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]))),
      const SizedBox(height: 16),
      Text('Plugins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ...controller.plugins.plugins.map((plugin) => Card(child: Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [
        SwitchListTile(value: plugin.enabled, onChanged: (_) => controller.plugins.toggle(plugin.id), secondary: CircleAvatar(backgroundColor: plugin.accent, child: Text(plugin.icon)), title: Text(plugin.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${plugin.description}\n${plugin.author} · v${plugin.version}')),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 4, children: [
          ...plugin.permissions.map((permission) => Chip(avatar: const Icon(Icons.lock_outline_rounded, size: 14), label: Text(permission.label), visualDensity: VisualDensity.compact)),
          Chip(avatar: const Icon(Icons.bolt_rounded, size: 14), label: Text('${plugin.actions.length} actions'), visualDensity: VisualDensity.compact),
        ]))),
      ])))),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: const Icon(Icons.extension_rounded), title: const Text('Native plugin SDK'), subtitle: const Text('Plugins declare permissions, actions, and update events. Compiled packages are registered with PluginEngine; untrusted downloaded code is never executed.'))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: controller.logOut, icon: const Icon(Icons.logout_rounded), label: const Text('Log out of Telegram')),
    ]);
  }
}

Future<void> showChatCustomization(BuildContext context, AppController controller, ChatPreview chat) async { final current = controller.customizations[chat.id] ?? const ChatCustomization(); var value = current; await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (context) => StatefulBuilder(builder: (context, setState) => Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Customize ${chat.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 18), const Text('Accent color'), const SizedBox(height: 8), Wrap(spacing: 10, children: [Color(0xFF6750A4), Color(0xFF006B5F), Color(0xFF246A9C), Color(0xFF8D5A00), Color(0xFFBA1A1A)].map((color) => InkWell(onTap: () => setState(() => value = value.copyWith(accent: color)), borderRadius: BorderRadius.circular(99), child: CircleAvatar(radius: 18, backgroundColor: color, child: value.accent == color ? const Icon(Icons.check, color: Colors.white, size: 18) : null))).toList()), SwitchListTile(contentPadding: EdgeInsets.zero, value: value.compact, onChanged: (v) => setState(() => value = value.copyWith(compact: v)), title: const Text('Compact messages')), SwitchListTile(contentPadding: EdgeInsets.zero, value: value.dottedWallpaper, onChanged: (v) => setState(() => value = value.copyWith(dottedWallpaper: v)), title: const Text('Soft dot wallpaper')), FilledButton(onPressed: () { controller.customize(chat.id, value); Navigator.pop(context); }, child: const Text('Save chat style'))])))); }

Future<void> showPluginActions(BuildContext context, AppController controller, ChatPreview chat) async {
  final actions = controller.plugins.actionsFor(MdlessPluginSurface.chat);
  if (actions.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enable a chat plugin in Settings first.')));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ListTile(title: Text('Plugin actions', style: TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('Actions provided by enabled MDless plugins')),
      ...actions.map((action) => ListTile(leading: Icon(action.icon), title: Text(action.label), onTap: () { Navigator.pop(context); controller.runPluginAction(action, chatId: chat.id); })),
      const SizedBox(height: 12),
    ])),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({required this.chat, super.key});
  final ChatPreview chat;
  @override
  Widget build(BuildContext context) => CircleAvatar(radius: 25, backgroundColor: chat.color, child: Text(chat.initials, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF241B2B))));
}

class ChatPreview {
  ChatPreview({required this.id, required this.name, required this.initials, required this.preview, required this.time, required this.unread, required this.color, this.members, this.online = false, this.userId});
  final int id;
  final String name;
  final String initials;
  final String preview;
  final String time;
  final int unread;
  final Color color;
  final String? members;
  final bool online;
  final int? userId;

  ChatPreview copyWith({String? preview, String? time, int? unread}) => ChatPreview(
        id: id,
        name: name,
        initials: initials,
        preview: preview ?? this.preview,
        time: time ?? this.time,
        unread: unread ?? this.unread,
        color: color,
        members: members,
        online: online,
        userId: userId,
      );
}

class MdMessage {
  MdMessage({required this.author, required this.initials, required this.text, required this.time, required this.incoming, required this.color, this.reactions = const [], this.telegramId, this.audioFileId, this.audioTitle, this.audioPerformer, this.mediaFileId, this.mediaKind, this.mediaName});
  final String author;
  final String initials;
  final String text;
  final String time;
  final bool incoming;
  final Color color;
  final List<String> reactions;
  final int? telegramId;
  final int? audioFileId;
  final String? audioTitle;
  final String? audioPerformer;
  final int? mediaFileId;
  final String? mediaKind;
  final String? mediaName;
}
