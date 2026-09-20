import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tdlib/tdlib.dart';

enum TdAuthState { unavailable, waitingParameters, waitingPhone, waitingCode, waitingPassword, waitingRegistration, waitingEmailAddress, waitingEmailCode, waitingOtherDeviceConfirmation, ready, error }

class TdlibGateway {
  TdlibGateway();

  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  int? _clientId;
  Timer? _receiver;
  int _sequence = 0;
  TdAuthState authState = TdAuthState.unavailable;
  String? error;

  Stream<Map<String, dynamic>> get updates => _updates.stream;
  bool get isAvailable => _clientId != null;
  bool get isAuthenticated => authState == TdAuthState.ready;

  Future<void> initialize({required int apiId, required String apiHash}) async {
    if (apiId == 0 || apiHash.isEmpty) {
      authState = TdAuthState.unavailable;
      error = 'Build with TELEGRAM_API_ID and TELEGRAM_API_HASH, or enter them in Settings.';
      return;
    }
    try {
      // A reconnect must not leave an old receiver/client alive. This also
      // makes retrying after a failed initialization deterministic.
      if (_clientId != null) {
        _receiver?.cancel();
        TdPlugin.instance.tdJsonClientDestroy(_clientId!);
        _clientId = null;
        for (final pending in _pending.values) {
          if (!pending.isCompleted) {
            pending.completeError(StateError('TDLib client was reinitialized.'));
          }
        }
        _pending.clear();
      }

      // The tdlib Flutter package ships libtdjson.so under jniLibs, but its
      // Android plugin does not call System.loadLibrary. Open the packaged
      // ABI library explicitly instead of looking only in the Flutter process
      // symbol table (which causes an undefined td_json_client_create symbol).
      await TdPlugin.initialize(Platform.isAndroid ? 'libtdjson.so' : null);
      _clientId = TdPlugin.instance.tdJsonClientCreate();
      _receiver = Timer.periodic(const Duration(milliseconds: 120), (_) => _receive());

      // Android's process working directory is read-only. TDLib expects real
      // filesystem paths, so keep its database and downloaded files inside
      // the app-private support directory instead of using relative paths.
      final supportDirectory = await getApplicationSupportDirectory();
      final databaseDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}mdless_tdlib',
      );
      final filesDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}mdless_files',
      );
      await databaseDirectory.create(recursive: true);
      await filesDirectory.create(recursive: true);

      await request({
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': databaseDirectory.path,
        'files_directory': filesDirectory.path,
        'database_encryption_key': '',
        'use_file_database': true,
        'use_chat_info_database': true,
        'use_message_database': true,
        'use_secret_chats': true,
        'api_id': apiId,
        'api_hash': apiHash,
        'system_language_code': 'en',
        'device_model': 'MDless Mobile',
        'system_version': 'Android/iOS',
        'application_version': '0.1.0',
        'enable_storage_optimizer': true,
      });
      await request({'@type': 'checkDatabaseEncryptionKey', 'encryption_key': ''});
      authState = TdAuthState.waitingPhone;
    } catch (exception) {
      error = exception.toString();
      authState = TdAuthState.error;
    }
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> payload) {
    final clientId = _clientId;
    if (clientId == null) return Future.error(StateError('TDLib is not initialized.'));
    final extra = 'mdless-${_sequence++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;
    TdPlugin.instance.tdJsonClientSend(clientId, jsonEncode({...payload, '@extra': extra}));
    return completer.future.timeout(const Duration(seconds: 20), onTimeout: () {
      _pending.remove(extra);
      throw TimeoutException('TDLib request timed out: ${payload['@type']}');
    });
  }

  Future<void> sendPhone(String phone) async {
    authState = TdAuthState.waitingCode;
    await request({'@type': 'setAuthenticationPhoneNumber', 'phone_number': phone, 'settings': {'@type': 'phoneNumberAuthenticationSettings', 'allow_flash_call': false, 'allow_missed_call': false, 'is_current_phone_number': true, 'allow_sms_retriever_api': false}});
  }

  Future<void> sendCode(String code) async {
    await request({'@type': 'checkAuthenticationCode', 'code': code});
  }

  Future<void> sendPassword(String password) async {
    await request({'@type': 'checkAuthenticationPassword', 'password': password});
  }

  Future<void> registerUser({required String firstName, required String lastName}) async {
    await request({'@type': 'registerUser', 'first_name': firstName, 'last_name': lastName});
  }

  Future<void> sendEmailAddress(String email) async {
    await request({'@type': 'setAuthenticationEmailAddress', 'email_address': email});
  }

  Future<void> sendEmailCode(String code) async {
    await request({'@type': 'checkAuthenticationEmailCode', 'code': {'@type': 'emailAddressAuthenticationCode', 'code': code}});
  }

  Future<List<Map<String, dynamic>>> loadChats() async {
    await request({'@type': 'loadChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': 100});
    final response = await request({'@type': 'getChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': 100});
    final ids = List<int>.from(response['chat_ids'] ?? const []);
    final chats = <Map<String, dynamic>>[];
    for (final id in ids.take(40)) {
      chats.add(await request({'@type': 'getChat', 'chat_id': id}));
    }
    return chats;
  }

  Future<Map<String, dynamic>> loadCurrentUser() => request({'@type': 'getMe'});

  Future<List<Map<String, dynamic>>> searchContacts(String query) async {
    final response = await request({'@type': 'searchContacts', 'query': query, 'limit': 20});
    final users = <Map<String, dynamic>>[];
    for (final id in List<int>.from(response['user_ids'] ?? const [])) {
      users.add(await request({'@type': 'getUser', 'user_id': id}));
    }
    return users;
  }

  Future<Map<String, dynamic>> searchPublicChat(String username) => request({'@type': 'searchPublicChat', 'username': username.replaceFirst('@', '').trim()});

  Future<Map<String, dynamic>> createPrivateChat(int userId) => request({'@type': 'createPrivateChat', 'user_id': userId, 'force': true});

  Future<void> openChat(int chatId) async {
    await request({'@type': 'openChat', 'chat_id': chatId});
  }

  Future<void> closeChat(int chatId) async {
    await request({'@type': 'closeChat', 'chat_id': chatId});
  }

  Future<void> logOut() async {
    await request({'@type': 'logOut'});
    authState = TdAuthState.waitingPhone;
  }

  Future<void> setChatMuted(int chatId, bool muted) async {
    await request({
      '@type': 'setChatNotificationSettings',
      'chat_id': chatId,
      'notification_settings': {
        '@type': 'chatNotificationSettings',
        'use_default_mute_for': false,
        'mute_for': muted ? 315360000 : 0,
        'use_default_sound': true,
        'sound_id': 0,
        'use_default_show_preview': true,
        'show_preview': true,
        'use_default_mute_stories': true,
        'mute_stories': false,
        'use_default_story_sound': true,
        'story_sound_id': 0,
        'use_default_story_show_preview': true,
        'story_show_preview': true,
        'use_default_disable_pinned_message_notifications': true,
        'disable_pinned_message_notifications': false,
        'use_default_disable_mention_notifications': true,
        'disable_mention_notifications': false,
      },
    });
  }

  Future<List<Map<String, dynamic>>> loadMessages(int chatId) async {
    final response = await request({'@type': 'getChatHistory', 'chat_id': chatId, 'from_message_id': 0, 'offset': 0, 'limit': 50, 'only_local': false});
    return List<Map<String, dynamic>>.from(response['messages'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> searchChatMessages(int chatId, String query) async {
    final response = await request({
      '@type': 'searchChatMessages',
      'chat_id': chatId,
      'query': query,
      'sender_id': null,
      'from_message_id': 0,
      'offset': 0,
      'limit': 50,
      'filter': null,
    });
    return List<Map<String, dynamic>>.from(response['messages'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    final response = await request({
      '@type': 'searchMessages',
      'chat_list': null,
      'query': query,
      'from_message_id': 0,
      'offset': 0,
      'limit': 50,
      'filter': null,
    });
    return List<Map<String, dynamic>>.from(response['messages'] ?? const []);
  }

  Future<void> markMessagesRead(int chatId, List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    await request({'@type': 'viewMessages', 'chat_id': chatId, 'message_ids': messageIds, 'force_read': false});
  }

  Future<void> sendTyping(int chatId) async {
    await request({'@type': 'sendChatAction', 'chat_id': chatId, 'message_thread_id': 0, 'action': {'@type': 'chatActionTyping'}});
  }

  Future<void> sendMessage(int chatId, String text, {int? replyToMessageId, bool disableNotification = false}) async {
    final payload = <String, dynamic>{
      '@type': 'sendMessage',
      'chat_id': chatId,
      'options': {
        '@type': 'messageSendOptions',
        'disable_notification': disableNotification,
        'from_background': false,
        'protect_content': false,
        'update_order_of_installed_sticker_sets': false,
      },
      'input_message_content': {'@type': 'inputMessageText', 'text': {'@type': 'formattedText', 'text': text, 'entities': []}},
    };
    if (replyToMessageId != null) {
      payload['reply_to'] = {'@type': 'inputMessageReplyToMessage', 'message_id': replyToMessageId, 'quote': null, 'checklist_task_id': 0};
    }
    await request(payload);
  }

  Future<void> editMessageText(int chatId, int messageId, String text) async => request({
        '@type': 'editMessageText',
        'chat_id': chatId,
        'message_id': messageId,
        'input_message_content': {'@type': 'inputMessageText', 'text': {'@type': 'formattedText', 'text': text, 'entities': []}},
      });

  Future<void> deleteMessages(int chatId, List<int> messageIds, {bool revoke = true}) async => request({
        '@type': 'deleteMessages',
        'chat_id': chatId,
        'message_ids': messageIds,
        'revoke': revoke,
      });

  Future<void> forwardMessages(int toChatId, int fromChatId, List<int> messageIds) async => request({
        '@type': 'forwardMessages',
        'chat_id': toChatId,
        'from_chat_id': fromChatId,
        'message_ids': messageIds,
        'options': {
          '@type': 'messageSendOptions',
          'disable_notification': false,
          'from_background': false,
          'protect_content': false,
          'update_order_of_installed_sticker_sets': false,
        },
        'send_copy': false,
        'remove_caption': false,
      });

  Future<void> setMessageReaction(int chatId, int messageId, String emoji) async => request({
        '@type': 'setMessageReaction',
        'chat_id': chatId,
        'message_id': messageId,
        'reaction_type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
        'is_big': false,
        'update_recent_reactions': true,
      });

  Future<void> sendLocalFile(int chatId, String path, {String? caption}) async {
    final lowerPath = path.toLowerCase();
    final isImage = lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png') || lowerPath.endsWith('.webp');
    final inputFile = {'@type': 'inputFileLocal', 'path': path};
    final formattedCaption = {'@type': 'formattedText', 'text': caption ?? '', 'entities': []};
    final content = isImage
        ? {'@type': 'inputMessagePhoto', 'photo': inputFile, 'added_sticker_file_ids': <int>[], 'width': 0, 'height': 0, 'caption': formattedCaption, 'self_destruct_time': 0, 'has_spoiler': false}
        : {'@type': 'inputMessageDocument', 'document': inputFile, 'thumbnail': null, 'disable_content_type_detection': false, 'caption': formattedCaption};
    await request({'@type': 'sendMessage', 'chat_id': chatId, 'input_message_content': content});
  }

  Future<String?> downloadFile(int fileId) async {
    await request({'@type': 'downloadFile', 'file_id': fileId, 'priority': 32, 'offset': 0, 'limit': 0, 'synchronous': true});
    for (var attempt = 0; attempt < 60; attempt++) {
      final file = await request({'@type': 'getFile', 'file_id': fileId});
      final local = file['local'];
      if (local is Map && local['is_downloading_completed'] == true && (local['path']?.toString().isNotEmpty ?? false)) {
        return local['path'].toString();
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<Map<String, dynamic>> createCall({required int userId, bool video = false}) => request({
        '@type': 'createCall',
        'user_id': userId,
        'protocol': {'@type': 'callProtocol', 'udp_p2p': true, 'udp_reflector': true, 'min_layer': 65, 'max_layer': 92, 'library_versions': []},
        'is_video': video,
      });

  Future<void> acceptCall(int callId) async => request({'@type': 'acceptCall', 'call_id': callId, 'protocol': {'@type': 'callProtocol', 'udp_p2p': true, 'udp_reflector': true, 'min_layer': 65, 'max_layer': 92, 'library_versions': []}});

  Future<void> discardCall(int callId) async => request({'@type': 'discardCall', 'call_id': callId, 'is_disconnected': false, 'invite_link': false, 'duration': 0, 'is_video': false, 'connection_id': 0});

  void _receive() {
    final clientId = _clientId;
    if (clientId == null) return;
    final raw = TdPlugin.instance.tdJsonClientReceive(clientId, 0.01);
    if (raw == null || raw.isEmpty) return;
    try {
      final update = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final extra = update['@extra']?.toString();
      if (extra != null && _pending.containsKey(extra)) {
        final pending = _pending.remove(extra)!;
        if (update['@type'] == 'error') {
          pending.completeError(StateError('${update['code'] ?? 'TDLib error'}: ${update['message'] ?? 'Unknown Telegram error'}'));
        } else {
          pending.complete(update);
        }
      }
      if (update['@type'] == 'updateAuthorizationState') {
        final type = update['authorization_state']?['@type'];
        authState = switch (type) {
          'authorizationStateWaitTdlibParameters' => TdAuthState.waitingParameters,
          'authorizationStateWaitPhoneNumber' => TdAuthState.waitingPhone,
          'authorizationStateWaitCode' => TdAuthState.waitingCode,
          'authorizationStateWaitPassword' => TdAuthState.waitingPassword,
          'authorizationStateWaitRegistration' => TdAuthState.waitingRegistration,
          'authorizationStateWaitEmailAddress' => TdAuthState.waitingEmailAddress,
          'authorizationStateWaitEmailCode' => TdAuthState.waitingEmailCode,
          'authorizationStateWaitOtherDeviceConfirmation' => TdAuthState.waitingOtherDeviceConfirmation,
          'authorizationStateReady' => TdAuthState.ready,
          _ => authState,
        };
      }
      _updates.add(update);
    } catch (_) {
      // TDLib output is ignored only when it is not valid JSON.
    }
  }

  Future<void> dispose() async {
    _receiver?.cancel();
    if (_clientId != null) TdPlugin.instance.tdJsonClientDestroy(_clientId!);
    await _updates.close();
  }
}
