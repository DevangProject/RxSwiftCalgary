import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────
///  Route Map — design tokens
///
///  These mirror the CSS variables from the HTML prototype so the
///  Flutter screen reads as the same product. If your app already
///  exposes `AppColors` / `AppRadius`, you can delete this file and
///  point the widgets at those instead — the names line up closely.
/// ─────────────────────────────────────────────────────────────

class RouteColors {
  RouteColors._();

  // Teal family (primary)
  static const teal = Color(0xFF1D9E75);
  static const tealLight = Color(0xFFE1F5EE);
  static const tealMid = Color(0xFF5DCAA5);
  static const tealDark = Color(0xFF0F6E56);
  static const tealDarker = Color(0xFF085041);

  // inside class RouteColors, anywhere after the existing colors
  static const primary = teal;
  static const success = greenMid;
  static const accentGreen = greenMid;
  static const danger = red;
  static const cardBorder = borderTertiary;
  static const background = surfaceAlt;
  static const disabledFill = Color(0xFFE3E0D8);

  // Pickup (green)
  static const green = Color(0xFF3B6D11);
  static const greenLight = Color(0xFFEAF3DE);
  static const greenMid = Color(0xFF639922);

  // Drop (blue)
  static const blue = Color(0xFF185FA5);
  static const blueLight = Color(0xFFE6F1FB);
  static const blueMid = Color(0xFF378ADD);

  // Completed (gray)
  static const gray = Color(0xFF5F5E5A);
  static const grayLight = Color(0xFFF1EFE8);
  static const grayMid = Color(0xFF888780);

  // Danger (failed)
  static const red = Color(0xFFA32D2D);
  static const redLight = Color(0xFFFCEBEB);

  // Warning (amber)
  static const amber = Color(0xFF854F0B);
  static const amberLight = Color(0xFFFAEEDA);

  // Neutrals / surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF7F6F2); // background-secondary
  static const borderTertiary = Color(0xFFE7E4DC);
  static const borderSecondary = Color(0xFFD9D6CD);
  static const textPrimary = Color(0xFF1C1B19);
  static const textSecondary = Color(0xFF6E6C66);

  // Map canvas
  static const mapCanvas = Color(0xFFE8F4EF);
  static const mapGridLine = Color(0xFF9FE1CB);
  static const mapRoad = Color(0xFFFFFFFF);
  static const mapBlock = Color(0x59FFFFFF); // ~0.35 white
}
/// Spacing scale (mirrors AppSpacing so the form screens read consistently).
class RouteSpacing {
  RouteSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}


class RouteRadius {
  RouteRadius._();
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const sheet = 24.0;
  static const full = 999.0;
}

class RouteShadows {
  RouteShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const sheet = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, -6),
    ),
  ];

  static const floating = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

/// Convenience text style helpers. Swap `fontFamily` for whatever your
/// app standardises on (the prototype uses a clean sans — Poppins-like).
class RouteText {
  RouteText._();
  static const _family = 'Poppins';


  static TextStyle button(Color color) => TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle appBar(Color color) => TextStyle(
    fontFamily: 'Poppins',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: color,
  );


  static TextStyle display(Color color) => TextStyle(
    fontFamily: _family,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.0,
    color: color,
  );

  static TextStyle title(Color color) => TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: color,
  );

  static TextStyle body(Color color) => TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: color,
  );

  static TextStyle label(Color color) => TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: color,
  );
}