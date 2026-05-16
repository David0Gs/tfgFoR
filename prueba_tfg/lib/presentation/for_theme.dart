import 'package:flutter/material.dart';

class ForColors {
  const ForColors._();

  static const Color transparent = Colors.transparent;
  static const Color background = Color.fromARGB(255, 187, 245, 255);
  static const Color backgroundRaised = Color(0xFF141414);
  static const Color sceneBackground = background;
  static const Color thumbnailBackground = Color.fromARGB(255, 0, 0, 0);
  static const Color overlay = Color(0x8A000000);
  static const Color overlayMedium = Color(0x80000000);
  static const Color overlayHeavy = Color(0xB3000000);
  static const Color overlayStrong = Color(0xD9000000);
  static const Color shadow = Color(0x66000000);

  static const Color panelActive = Color(0xE61A1A1A);
  static const Color panel = Color(0xE61B120D);
  static const Color panelSoft = Color(0xB32B1A12);
  static const Color panelDark = Color(0xFF111111);
  static const Color panelMuted = Color(0xDD212121);
  static const Color panelTranslucent = Color(0x8A000000);
  static const Color iconButtonOverlay = Color(0x33161410);

  static const Color border = Color(0xFFE6C28B);
  static const Color borderSoft = Color(0x66FFE7B3);
  static const Color borderMuted = Color(0x3DFFFFFF);
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldLight = Color(0xFFFFE7B3);
  static const Color goldPale = Color(0xFFFDE68A);
  static const Color parchment = Color(0xFFF8EAD2);
  static const Color parchmentDark = Color(0xFFD7C0A0);
  static const Color dialogFrame = Color(0xFFFFF1C9);
  static const Color dialogGradientTop = Color(0xFFF2DFBF);
  static const Color dialogGradientMid = Color(0xFFE2C08A);
  static const Color dialogGradientBottom = Color(0xFFB37A3F);

  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color textSoft = Color(0x99FFFFFF);
  static const Color textDisabled = Color(0x61FFFFFF);
  static const Color textFaint = Color(0x8AFFFFFF);
  static const Color textDark = Color(0xFF000000);

  static const Color success = Color(0xFF2E7D32);
  static const Color successOverlay = Color(0x992E7D32);
  static const Color danger = Color(0xFFB71C1C);
  static const Color dangerOverlay = Color(0x99B71C1C);
  static const Color dangerPanel = Color(0xFF7F1D1D);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF2196F3);
  static const Color infoOverlay = Color(0x332196F3);
  static const Color infoLight = Color(0xFF40C4FF);

  // Colores de jugadores
  static const Color player0 = Color.fromARGB(255, 255, 0, 4);  // Rojo
  static const Color player1 = Color.fromARGB(255, 63, 255, 56);  // Verde
  static const Color player2 = Color.fromARGB(255, 234, 255, 2);  // Amarillo
  static const Color player3 = Color.fromARGB(255, 34, 144, 255);  // Azul
  static const Color player4 = Color.fromARGB(255, 255, 72, 173);  // Magenta
  static const Color playerDefault = Color.fromARGB(255, 108, 100, 100);  // Gris

  static Color getPlayerColor(int playerId) {
    switch (playerId) {
      case 0:
        return player0;
      case 1:
        return player1;
      case 2:
        return player2;
      case 3:
        return const Color.fromARGB(255, 22, 135, 255);
      case 4:
        return player4;
      default:
        return playerDefault;
    }
  }
}

extension ForColorHex on Color {
  String get rgbHex {
    final int rgb = toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

class ForSpacing {
  const ForSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class ForRadii {
  const ForRadii._();

  static const double button = 16;
  static const double compactButton = 8;
  static const double panel = 12;
  static const double contentPanel = 22;
  static const double dialog = 28;
  static const double pill = 999;
}

class ForSizes {
  const ForSizes._();

  static const double icon = 32;
  static const double smallIcon = 18;
  static const double toolbarButtonHeight = 42;
  static const double menuButtonVerticalPadding = 16;
  static const double marketButtonVerticalPadding = 8;
  static const double catalogWidth = 540;
  static const double catalogHeight = 360;
  static const double playerPanelWidth = 250;
  static const double remoteStatusMaxWidth = 240;
  static const double thumbnailWidth = 86;
  static const double thumbnailHeight = 68;
}

class ForTypography {
  const ForTypography._();

  static const String fontFamily = 'Roboto';

  static const TextStyle menuButton = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle smallButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle panelTitle = TextStyle(
    color: ForColors.gold,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle panelBody = TextStyle(
    color: ForColors.text,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyMuted = TextStyle(color: ForColors.textMuted);

  static const TextStyle errorBody = TextStyle(color: ForColors.error);

  static const TextStyle sectionTitle = TextStyle(
    color: ForColors.text,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle dialogTitle = TextStyle(
    color: ForColors.goldLight,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle dialogSubtitle = TextStyle(
    color: ForColors.parchmentDark,
    fontSize: 13,
    height: 1.35,
  );

  static const TextStyle dialogBody = TextStyle(
    color: ForColors.parchment,
    fontSize: 15,
    height: 1.6,
  );

  static const TextStyle catalogEntryTitle = TextStyle(
    color: ForColors.text,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle catalogEntryTitleDisabled = TextStyle(
    color: ForColors.textFaint,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle catalogEntryBody = TextStyle(
    color: ForColors.textMuted,
    fontSize: 12,
    height: 1.25,
  );

  static const TextStyle catalogEntryBodyDisabled = TextStyle(
    color: ForColors.textDisabled,
    fontSize: 12,
    height: 1.25,
  );

  static const TextStyle playerName = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );

  static const TextStyle playerStatLabel = TextStyle(
    color: ForColors.textSoft,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle playerStatValue = TextStyle(
    color: ForColors.text,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle badge = TextStyle(
    color: ForColors.textMuted,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle helper = TextStyle(
    color: ForColors.textFaint,
    fontSize: 11,
    fontStyle: FontStyle.italic,
  );

  static const TextStyle alertTitle = TextStyle(
    color: ForColors.text,
    fontSize: 16,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle alertBody = TextStyle(
    color: ForColors.text,
    fontSize: 13,
    height: 1.35,
  );
}

class ForButtonStyles {
  const ForButtonStyles._();

  static ButtonStyle icon() {
    return IconButton.styleFrom(
      backgroundColor: ForColors.iconButtonOverlay,
      foregroundColor: ForColors.goldLight,
    );
  }

  /////////////////////////////// AQUI SE ENCUENTRAN LOS BOTONES DEL MENU PRINCIPAL ////////////////////////////////

  static ButtonStyle menuPrimary() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: ForSizes.menuButtonVerticalPadding,
      ),
      backgroundColor: ForColors.panelSoft,
      foregroundColor: ForColors.text,
      disabledForegroundColor: ForColors.textDisabled,
      textStyle: ForTypography.menuButton,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ForRadii.button),
        side: const BorderSide(color: ForColors.border),
      ),
    );
  }

  /////////////////////////////// AQUI SE ENCUENTRAN LOS BOTONES DEL TABLERO ////////////////////////////////

  static ButtonStyle toolbar() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(0, ForSizes.toolbarButtonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: ForColors.panelSoft,
      foregroundColor: ForColors.text,
      disabledForegroundColor: ForColors.textDisabled,
      textStyle: ForTypography.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ForRadii.compactButton),
        side: const BorderSide(color: ForColors.border),
      ),
    );
  }

  static ButtonStyle marketLot() {
    return ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: ForSizes.marketButtonVerticalPadding,
        ),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 0)),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return ForColors.textDisabled;
        }
        if (states.contains(WidgetState.hovered)) {
          return ForColors.textDark;
        }
        return ForColors.text;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.hovered)) {
          return ForColors.gold;
        }
        return ForColors.transparent;
      }),
      textStyle: WidgetStateProperty.all(ForTypography.smallButton),
    );
  }
}

class ForTheme {
  const ForTheme._();

  static ThemeData materialTheme() {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: ForColors.gold,
      brightness: Brightness.dark,
      surface: ForColors.panel,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: ForTypography.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ForColors.background,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ForButtonStyles.toolbar(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ForColors.gold,
          foregroundColor: ForColors.textDark,
          textStyle: ForTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ForRadii.compactButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ForColors.goldLight,
          side: const BorderSide(color: ForColors.border),
          textStyle: ForTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ForRadii.compactButton),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ForColors.goldLight,
          textStyle: ForTypography.button,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ForColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ForRadii.panel),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ForColors.panelDark,
        contentTextStyle: TextStyle(color: ForColors.text),
      ),
    );
  }
}
