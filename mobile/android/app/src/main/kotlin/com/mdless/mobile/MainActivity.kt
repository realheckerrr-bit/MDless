package com.mdless.mobile

import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.github.pytgcalls.ConnectionInfo
import io.github.pytgcalls.NTgCalls
import io.github.pytgcalls.media.AudioDescription
import io.github.pytgcalls.media.MediaDescription
import io.github.pytgcalls.media.MediaDevices
import io.github.pytgcalls.media.MediaSource
import io.github.pytgcalls.media.StreamMode
import io.github.pytgcalls.p2p.RTCServer

class MainActivity : FlutterActivity() {
    private lateinit var callChannel: MethodChannel
    private var callEngine: NTgCalls? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        callChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mdless/calls")
        callChannel.setMethodCallHandler(::handleCallMethod)
    }

    private fun handleCallMethod(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getProtocol" -> {
                    val protocol = NTgCalls.getProtocol()
                    result.success(
                        mapOf(
                            "minLayer" to protocol.min_layer,
                            "maxLayer" to protocol.max_layer,
                            "udpP2p" to protocol.udp_p2p,
                            "udpReflector" to protocol.udp_reflector,
                            "libraryVersions" to protocol.library_versions,
                        ),
                    )
                }
                "prepare" -> {
                    prepareCall(call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Missing call parameters"))
                    result.success(null)
                }
                "sendSignalingData" -> {
                    val args = call.arguments as? Map<*, *>
                        ?: throw IllegalArgumentException("Missing signaling parameters")
                    val userId = number(args["userId"], "userId")
                    val data = decodeBytes(args["data"])
                    require(data != null) { "Missing signaling data" }
                    callEngine?.sendSignalingData(userId, data)
                    result.success(null)
                }
                "mute" -> {
                    val userId = number(call.argument<Any>("userId"), "userId")
                    val muted = call.argument<Boolean>("muted") ?: true
                    if (muted) callEngine?.mute(userId) else callEngine?.unmute(userId)
                    result.success(null)
                }
                "stop" -> {
                    val userId = number(call.argument<Any>("userId"), "userId")
                    callEngine?.stop(userId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (exception: Exception) {
            result.error("CALL_ENGINE_ERROR", exception.message ?: exception.javaClass.simpleName, null)
        }
    }

    private fun prepareCall(args: Map<*, *>) {
        val engine = ensureCallEngine()
        val userId = number(args["userId"], "userId")
        val isOutgoing = args["isOutgoing"] == true
        val encryptionKey = decodeBytes(args["encryptionKey"])
            ?: throw IllegalArgumentException("Missing call encryption key")
        val protocol = args["protocol"] as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val versions = (protocol["library_versions"] as? List<*>)
            ?.mapNotNull { it?.toString() }
            ?: emptyList()
        val servers = parseServers(args["servers"] as? List<*>)
        val customParameters = args["customParameters"]?.toString() ?: "{}"
        val allowP2p = args["allowP2p"] == true
        val devices = NTgCalls.getMediaDevices()

        // NTgCalls uses Telegram's user id as the private-call connection key.
        // TDLib's call id remains in Dart for signaling and UI state.
        engine.createP2pCall(userId)
        engine.setStreamSources(
            userId,
            StreamMode.CAPTURE,
            MediaDescription(
                audioDevice(devices, capture = true),
                null,
                null,
                null,
            ),
        )
        engine.setStreamSources(
            userId,
            StreamMode.PLAYBACK,
            MediaDescription(
                audioDevice(devices, capture = false),
                null,
                null,
                null,
            ),
        )
        engine.skipExchange(userId, encryptionKey, isOutgoing)
        engine.connectP2p(userId, servers, versions, allowP2p, customParameters)
    }

    private fun ensureCallEngine(): NTgCalls {
        callEngine?.let { return it }
        return NTgCalls().also { engine ->
            engine.onSignalingData { userId, data ->
                invokeCallEvent(
                    "signalingData",
                    mapOf("userId" to userId, "data" to Base64.encodeToString(data, Base64.NO_WRAP)),
                )
            }
            engine.onConnectionChange { userId, state ->
                invokeCallEvent("connection", connectionEvent(userId, state))
            }
            callEngine = engine
        }
    }

    private fun invokeCallEvent(method: String, arguments: Map<String, Any?>) {
        runOnUiThread { callChannel.invokeMethod(method, arguments) }
    }

    private fun connectionEvent(userId: Long, info: ConnectionInfo): Map<String, Any?> = mapOf(
        "userId" to userId,
        "state" to info.state.name,
        "kind" to info.kind.name,
    )

    private fun audioDevice(devices: MediaDevices, capture: Boolean): AudioDescription {
        val list = if (capture) devices.microphone else devices.speaker
        val input = list.firstOrNull()?.metadata ?: ""
        return AudioDescription(MediaSource.DEVICE, 48000, 2, input, true)
    }

    private fun parseServers(raw: List<*>?): List<RTCServer> = raw.orEmpty().mapNotNull { value ->
        val server = value as? Map<*, *> ?: return@mapNotNull null
        val type = server["type"] as? Map<*, *> ?: return@mapNotNull null
        val typeName = type["@type"]?.toString()
        val id = number(server["id"], "server.id")
        val ipv4 = server["ip_address"]?.toString() ?: ""
        val ipv6 = server["ipv6_address"]?.toString() ?: ""
        val port = number(server["port"], "server.port").toInt()
        when (typeName) {
            "callServerTypeWebrtc" -> RTCServer(
                id,
                ipv4,
                ipv6,
                port,
                type["username"]?.toString() ?: "",
                type["password"]?.toString() ?: "",
                type["supports_turn"] == true,
                type["supports_stun"] == true,
                false,
                null,
            )
            "callServerTypeTelegramReflector" -> RTCServer(
                id,
                ipv4,
                ipv6,
                port,
                "",
                "",
                true,
                false,
                type["is_tcp"] == true,
                decodeBytes(type["peer_tag"]),
            )
            else -> null
        }
    }

    private fun number(value: Any?, name: String): Long = when (value) {
        is Number -> value.toLong()
        is String -> value.toLongOrNull() ?: throw IllegalArgumentException("Invalid $name")
        else -> throw IllegalArgumentException("Missing $name")
    }

    private fun decodeBytes(value: Any?): ByteArray? = when (value) {
        is ByteArray -> value
        is String -> if (value.isEmpty()) byteArrayOf() else Base64.decode(value, Base64.DEFAULT)
        else -> null
    }

    override fun onDestroy() {
        callEngine?.calls()?.keys?.toList()?.forEach { userId ->
            runCatching { callEngine?.stop(userId) }
        }
        callEngine = null
        super.onDestroy()
    }
}
