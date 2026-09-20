import 'dart:async';
import 'dart:convert';

import 'package:tdlib/tdlib.dart';

enum TdAuthState { unavailable, waitingParameters, waitingPhone, waitingCode, waitingPassword, ready, error }

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

  Future<void> initialize({required int apiId, required String apiHash}) async {
    if (apiId == 0 || apiHash.isEmpty) {
      authState = TdAuthState.unavailable;
      error = 'Build with TELEGRAM_API_ID and TELEGRAM_API_HASH, or enter them in Settings.';
      return;
    }
    try {
      await TdPlugin.initialize();
      _clientId = TdPlugin.instance.tdJsonClientCreate();
      _receiver = Timer.periodic(const Duration(milliseconds: 120), (_) => _receive());
      await request({
        '@type': 'setTdlibParameters',
        'use_test_dc': false,
        'database_directory': 'mdless_tdlib',
        'files_directory': 'mdless_files',
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

  Future<List<Map<String, dynamic>>> loadMessages(int chatId) async {
    final response = await request({'@type': 'getChatHistory', 'chat_id': chatId, 'from_message_id': 0, 'offset': 0, 'limit': 50, 'only_local': false});
    return List<Map<String, dynamic>>.from(response['messages'] ?? const []);
  }

  Future<void> sendMessage(int chatId, String text) async {
    await request({'@type': 'sendMessage', 'chat_id': chatId, 'input_message_content': {'@type': 'inputMessageText', 'text': {'@type': 'formattedText', 'text': text, 'entities': []}}});
  }

  void _receive() {
    final clientId = _clientId;
    if (clientId == null) return;
    final raw = TdPlugin.instance.tdJsonClientReceive(clientId, 0.01);
    if (raw == null || raw.isEmpty) return;
    try {
      final update = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final extra = update['@extra']?.toString();
      if (extra != null && _pending.containsKey(extra)) {
        _pending.remove(extra)!.complete(update);
      }
      if (update['@type'] == 'updateAuthorizationState') {
        final type = update['authorization_state']?['@type'];
        authState = switch (type) {
          'authorizationStateWaitTdlibParameters' => TdAuthState.waitingParameters,
          'authorizationStateWaitPhoneNumber' => TdAuthState.waitingPhone,
          'authorizationStateWaitCode' => TdAuthState.waitingCode,
          'authorizationStateWaitPassword' => TdAuthState.waitingPassword,
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
