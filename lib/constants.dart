import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Aurora Premium — design tokens for KACEEPOS 2.0
// ---------------------------------------------------------------------------
// Legacy tokens are preserved (kcBackgroundColor, kcPrimaryColor, ...) so
// existing references continue to work; new tokens layer on top of them.

// === Surface palette ===
// Deep ink base with a faint warm-violet undertone — feels premium and warm
// rather than the typical "tech dark grey".
const kcInkColor = Color(0xFF0E0B16);
const kcInkColorSoft = Color(0xFF181321);
const kcSurfaceColor = Color(0xFF1F1A2C);
const kcSurfaceColorHi = Color(0xFF2A2438);
const kcSurfaceColorLo = Color(0xFF12101A);
const kcStrokeColor = Color(0x1AFFFFFF);
const kcStrokeColorSoft = Color(0x0DFFFFFF);

// === Legacy tokens (kept for backward compatibility) ===
const kcBackgroundColor = kcSurfaceColor;
const kcDarkColor = kcInkColor;
const kcPrimaryColor = Color(0xFFF96349);
const kcSecondaryColor = Color(0xFFDA0041);
const kcPrimaryLightColor = Color(0xFFFFFEFE);
const kcOrangeColor = Color(0xFFF11C00);
const kcPurpleColor = Color(0xFFD64D76);
const kcPurple2Color = Color(0xFFE95C73);

// === Brand accents ===
const kcAccentOrange = kcPrimaryColor;
const kcAccentPink = Color(0xFFFF3D7F);
const kcAccentAmber = Color(0xFFFFB36B);
const kcSuccessColor = Color(0xFF3DD68C);
const kcWarningColor = Color(0xFFFFB547);
const kcDangerColor = Color(0xFFFF5566);

// === Text palette ===
const kcTextPrimary = Color(0xFFFFFFFF);
const kcTextSecondary = Color(0xB3FFFFFF); // 70%
const kcTextMuted = Color(0x80FFFFFF); // 50%
const kcTextFaint = Color(0x4DFFFFFF); // 30%

// === Gradients ===
const kcBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kcAccentOrange, kcAccentPink],
);

const kcBrandGradientSoft = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x33F96349), Color(0x33FF3D7F)],
);

const kcGlassGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
);

const kcAmbientGradient = RadialGradient(
  center: Alignment(-0.7, -0.8),
  radius: 1.4,
  colors: [Color(0x33F96349), Color(0x00000000)],
);

// === Shadows ===
const kcShadowSoft = [
  BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
];

const kcShadowGlow = [
  BoxShadow(color: Color(0x4DF96349), blurRadius: 32, offset: Offset(0, 12)),
];

const kcShadowGlowPink = [
  BoxShadow(color: Color(0x4DFF3D7F), blurRadius: 28, offset: Offset(0, 10)),
];

// === Radii ===
const kcRadiusSm = 12.0;
const kcRadiusMd = 18.0;
const kcRadiusLg = 24.0;
const kcRadiusXl = 32.0;
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
  fontWeight: FontWeight.w300,
  letterSpacing: 0.5,
  color: kcTextPrimary,
);

const kcHeadlineStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 28,
  height: 1.1,
  fontWeight: FontWeight.w300,
  letterSpacing: 0.3,
  color: kcTextPrimary,
);

const kcTitleStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 20,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: kcTextPrimary,
);

const kcBodyStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 14,
  height: 1.4,
  fontWeight: FontWeight.w300,
  color: kcTextSecondary,
);

const kcLabelStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 12,
  height: 1.2,
  fontWeight: FontWeight.w400,
  letterSpacing: 1.2,
  color: kcTextMuted,
);

const kcCaptionStyle = TextStyle(
  fontFamily: 'Kanit',
  fontSize: 11,
  height: 1.2,
  fontWeight: FontWeight.w300,
  letterSpacing: 0.4,
  color: kcTextMuted,
);

// === Legacy text styles (preserved) ===
const appBarStyle = TextStyle(fontWeight: FontWeight.normal, fontSize: 20);
const tableH = TextStyle(
    fontWeight: FontWeight.w500, fontSize: 15, color: Colors.white);
const tableB = TextStyle(
    fontWeight: FontWeight.w200, fontSize: 13, color: Colors.white70);

// === Icons (legacy) ===
const iconA = Icons.shopping_cart;
const iconB = Icons.search;
const iconC = Icons.schedule;
const iconD = Icons.settings;
const iconAdd = Icons.add;
const iconDel = Icons.remove;
