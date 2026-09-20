import 'package:flutter/material.dart';

class ChatCustomization {
  const ChatCustomization({
    this.accent = const Color(0xFF6750A4),
    this.compact = false,
    this.dottedWallpaper = false,
  });

  final Color accent;
  final bool compact;
  final bool dottedWallpaper;

  ChatCustomization copyWith({Color? accent, bool? compact, bool? dottedWallpaper}) => ChatCustomization(
    accent: accent ?? this.accent,
    compact: compact ?? this.compact,
    dottedWallpaper: dottedWallpaper ?? this.dottedWallpaper,
  );
}
