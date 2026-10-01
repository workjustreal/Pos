import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// A3 Light — design tokens for KACEEPOS 2.0
// ---------------------------------------------------------------------------
// White surfaces, 1px light-grey strokes, and orange used only where the
// customer should look (pay button, totals, the item that was just scanned).
// No glows or shadows — the shadow / gradient tokens are kept for backward
// compatibility but resolve to flat values.

// === Surface palette ===
const kcInkColor = Color(0xFFFFFFFF); // scaffold
const kcInkColorSoft = Color(0xFFFCFCFC); // side panels
const kcSurfaceColor = Color(0xFFFFFFFF); // cards
const kcSurfaceColorHi = Color(0xFFF5F5F5); // chips, pressed rows
const kcSurfaceColorLo = Color(0xFFFAFAFA);
const kcStrokeColor = Color(0xFFEEEEEE);
const kcStrokeColorSoft = Color(0xFFF3F3F3);
const kcStrokeColorStrong = Color(0xFFE2E2E2);

// === Legacy tokens (kept for backward compatibility) ===
const kcBackgroundColor = kcSurfaceColor;
const kcDarkColor = Color(0xFF1A1A1A);
const kcPrimaryColor = Color(0xFFF96349);
const kcSecondaryColor = Color(0xFFDA0041);
const kcPrimaryLightColor = Color(0xFFFFFEFE);
const kcOrangeColor = Color(0xFFF11C00);
const kcPurpleColor = Color(0xFFD64D76);
const kcPurple2Color = Color(0xFFE95C73);

// === Brand accents ===
const kcAccentOrange = kcPrimaryColor;
const kcAccentOrangeDark = Color(0xFFC2410C); // orange text on orange tint
const kcAccentTint = Color(0xFFFFF6F3); // highlighted row / soft orange fill
const kcAccentPink = Color(0xFFFF3D7F);
const kcAccentAmber = Color(0xFFFFB36B);
const kcSuccessColor = Color(0xFF16A34A);
const kcSuccessDotColor = Color(0xFF22C55E);
const kcWarningColor = Color(0xFFD97706);
const kcDangerColor = Color(0xFFDC2626);
const kcDangerTint = Color(0xFFFEF2F2);

// === Text palette ===
const kcTextPrimary = Color(0xFF1A1A1A);
const kcTextSecondary = Color(0xFF666666);
const kcTextMuted = Color(0xFF9A9A9A);
const kcTextFaint = Color(0xFFBDBDBD);

// === Gradients (flat in A3 — kept so ShaderMask / gradient users still work) ===
const kcBrandGradient = LinearGradient(
  colors: [kcAccentOrange, kcAccentOrange],
);

const kcBrandGradientSoft = LinearGradient(
  colors: [kcAccentTint, kcAccentTint],
);

const kcGlassGradient = LinearGradient(
  colors: [kcSurfaceColor, kcSurfaceColor],
);

const kcAmbientGradient = RadialGradient(
  colors: [Color(0x00000000), Color(0x00000000)],
);

// === Shadows (none in A3) ===
const List<BoxShadow> kcShadowSoft = [];
const List<BoxShadow> kcShadowGlow = [];
const List<BoxShadow> kcShadowGlowPink = [];

// === Radii ===
const kcRadiusSm = 10.0;
const kcRadiusMd = 12.0;
const kcRadiusLg = 16.0;
const kcRadiusXl = 24.0;
const kcRadiusPill = 999.0;

// === Spacing ===
const kcSpaceXs = 4.0;
const kcSpaceSm = 8.0;
const kcSpaceMd = 16.0;
const kcSpaceLg = 24.0;
const kcSpaceXl = 32.0;
const kcSpace2xl = 48.0;

// === Text styles ===
const kcDisplayStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 44,
  height: 1.05,
  fontWeight: FontWeight.w500,
  color: kcTextPrimary,
);

const kcHeadlineStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 28,
  height: 1.15,
  fontWeight: FontWeight.w500,
  color: kcTextPrimary,
);

const kcTitleStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 20,
  height: 1.2,
  fontWeight: FontWeight.w500,
  color: kcTextPrimary,
);

const kcBodyStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 15,
  height: 1.4,
  fontWeight: FontWeight.w400,
  color: kcTextPrimary,
);

const kcLabelStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 13,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: kcTextMuted,
);

const kcCaptionStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: kcTextMuted,
);

// === Legacy text styles (preserved) ===
const appBarStyle = TextStyle(fontWeight: FontWeight.normal, fontSize: 20);
const tableH = TextStyle(
    fontWeight: FontWeight.w500, fontSize: 15, color: kcTextPrimary);
const tableB = TextStyle(
    fontWeight: FontWeight.w300, fontSize: 13, color: kcTextSecondary);

// === Icons (legacy) ===
const iconA = Icons.shopping_cart;
const iconB = Icons.search;
const iconC = Icons.schedule;
const iconD = Icons.settings;
const iconAdd = Icons.add;
const iconDel = Icons.remove;
