import 'package:flutter/material.dart';

class AppPalette {
  final Brightness brightness;
  final Color primary;
  final Color sidebar;
  final Color accent;
  final Color onPrimary;
  final Color background;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color borderOutline;
  final Color divider;
  final Color success;
  final Color successBg;
  final Color error;
  final Color errorBg;
  final Color primaryBg;

  /// Green dot — user is active/online.
  final Color presenceActive;

  /// Dark semi-transparent dot — user is away/offline.
  final Color presenceAway;

  /// An @mention of someone in a message, as on web.
  final Color mention;
  final Color mentionBg;

  /// An @channel mention's text, shown on [mentionHighlightBg].
  final Color channelMention;

  /// The yellow behind @channel and @mentions of the signed-in user.
  final Color mentionHighlightBg;

  const AppPalette({
    required this.brightness,
    required this.primary,
    required this.sidebar,
    required this.accent,
    required this.onPrimary,
    required this.background,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.borderOutline,
    required this.divider,
    required this.success,
    required this.successBg,
    required this.error,
    required this.errorBg,
    required this.primaryBg,
    required this.presenceActive,
    required this.presenceAway,
    required this.mention,
    required this.mentionBg,
    required this.channelMention,
    required this.mentionHighlightBg,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    primary: Color(0xFF6458F5),
    sidebar: Color(0xFF4848AD),
    accent: Color(0xFF5CCBBA),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFFFCFBFF),
    textPrimary: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF0A090B),
    textHint: Color(0xFFA3A3A3),
    borderOutline: Color(0xffD0D0FD),
    divider: Color(0xffE5E7EB),
    success: Color(0xFF22C55E),
    successBg: Color(0xFFEFFFF5),
    error: Color(0xFFEF4444),
    errorBg: Color(0xFFFFF1F1),
    primaryBg: Color(0xFFF3EFFF),
    presenceActive: Color(0xFF22C55E),
    presenceAway: Color(0x661E1E1E),
    mention: Color(0xFF1264A3),
    mentionBg: Color(0xFFE8F0FE),
    channelMention: Color(0xFF9A6700),
    mentionHighlightBg: Color(0xFFFFF3B0),
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    primary: Color(0xFF6458F5),
    sidebar: Color(0xFF23234F),
    accent: Color(0xFF5CCBBA),
    onPrimary: Color(0xFFFFFFFF),
    background: Color(0xFF121214),
    textPrimary: Color(0xFFF5F3FF),
    textSecondary: Color(0xFFCFCFD6),
    textHint: Color(0xFF8E8E93),
    borderOutline: Color(0xff3A3A4A),
    divider: Color(0xff2E2E38),
    success: Color(0xFF22C55E),
    successBg: Color(0xFF123626),
    error: Color(0xFFF87171),
    errorBg: Color(0xFF3B1A1A),
    primaryBg: Color(0xFF2A2650),
    presenceActive: Color(0xFF22C55E),
    presenceAway: Color(0x99FFFFFF),
    mention: Color(0xFF6CB6FF),
    mentionBg: Color(0xFF1A3F66),
    channelMention: Color(0xFFF5D90A),
    mentionHighlightBg: Color(0xFF4A3F00),
  );
}
