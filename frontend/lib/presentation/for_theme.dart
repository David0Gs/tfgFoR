// Definicion centralizada de estilo visual de la aplicacion. Agrupa colores,
// espaciados, radios, tamaños, tipografias, decoraciones y estilos de botones.

import 'package:flutter/material.dart';

/// Paleta principal de colores usada por la interfaz.
class ForColors {
  const ForColors._();

  // Base global: afecta al color de fondo principal de la app, la escena 3D,
  // las miniaturas del visor y transparencias reutilizadas en overlays.
  static const Color transparent = Colors.transparent;
  static const Color background = Color.fromARGB(255, 0, 0, 0);
  static const Color sceneBackground = background;
  static const Color thumbnailBackground = Color.fromARGB(255, 0, 0, 0);

  // Capas oscuras: afectan a pantallas modales, bloqueos visuales,
  // fondos semitransparentes y sombras generales de paneles.
  static const Color overlay = Color(0x8A000000);
  static const Color overlayMedium = Color(0x80000000);
  static const Color overlayHeavy = Color(0xB3000000);
  static const Color overlayStrong = Color(0xD9000000);
  static const Color shadow = Color(0x66000000);

  // Paneles: afectan a tarjetas de jugador, dialogos, barras flotantes,
  // botones, paneles de catalogo y superficies oscuras de la interfaz.
  static const Color panelActive = Color(0xE61A1A1A);
  static const Color panel = Color(0xE61B120D);
  static const Color panelSoft = Color(0xB32B1A12);
  static const Color panelDark = Color(0xFF111111);
  static const Color panelMuted = Color(0xDD212121);
  static const Color iconButtonOverlay = Color(0x33161410);

  // Dorados y bordes: afectan a contornos, botones, iconos principales,
  // titulos de paneles, avisos destacados y marcos de dialogos.
  static const Color border = Color(0xFFE6C28B);
  static const Color borderSoft = Color(0x66FFE7B3);
  static const Color borderMuted = Color(0x3DFFFFFF);
  static const Color borderSubtle = Color(0x1FFFFFFF);
  static const Color gold = Color(0xFFFFC107);
  static const Color goldLight = Color(0xFFFFE7B3);
  static const Color goldPale = Color(0xFFFDE68A);

  // Tonos pergamino: afectan sobre todo al dialogo de creditos y textos
  // largos sobre fondos oscuros con estilo de documento antiguo.
  static const Color parchment = Color(0xFFF8EAD2);
  static const Color parchmentDark = Color(0xFFD7C0A0);

  // Dialogo de creditos: controla el marco externo y el degradado del
  // contenedor que abre los agradecimientos.
  static const Color dialogFrame = Color(0xFFFFF1C9);
  static const Color dialogGradientTop = Color(0xFFF2DFBF);
  static const Color dialogGradientMid = Color(0xFFE2C08A);
  static const Color dialogGradientBottom = Color(0xFFB37A3F);

  // Panel interno de creditos: controla el fondo oscuro y los fundidos
  // superior/inferior del texto con scroll automatico.
  static const Color creditsGradientTop = Color(0xFF080808);
  static const Color creditsGradientMid = Color(0xFF16110D);
  static const Color creditsGradientBottom = Color(0xFF24180F);
  static const Color creditsTopFadeEnd = Color(0x00080808);
  static const Color creditsBottomFadeStart = Color(0x0024180F);

  // Texto comun: afecta a legibilidad, estados desactivados, ayudas,
  // subtitulos y texto sobre botones o paneles oscuros.
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xB3FFFFFF);
  static const Color textSoft = Color(0x99FFFFFF);
  static const Color textDisabled = Color(0x61FFFFFF);
  static const Color textFaint = Color(0x8AFFFFFF);
  static const Color textDark = Color(0xFF000000);

  // Estados y avisos: afecta a errores, alertas de desconexion y entradas
  // informativas como monumentos o problemas del visor 3D.
  static const Color dangerPanel = Color(0xFF7F1D1D);
  static const Color dangerBorder = Color(0xFFFCA5A5);
  static const Color error = Color(0xFFFF5252);
  static const Color infoOverlay = Color(0x332196F3);
  static const Color infoLight = Color(0xFF40C4FF);

  // Jugadores: define el color identificativo de cada jugador en el tablero,
  // HUD, estadisticas y objetos que necesitan distinguir propietarios.
  static const Color player0 = Color.fromARGB(255, 255, 0, 4); // Rojo
  static const Color player1 = Color.fromARGB(255, 63, 255, 56); // Verde
  static const Color player2 = Color.fromARGB(255, 234, 255, 2); // Amarillo
  static const Color player3 = Color.fromARGB(255, 0, 195, 255); // Azul
  static const Color player4 = Color.fromARGB(255, 255, 72, 173); // Magenta
  static const Color playerDefault = Color.fromARGB(255, 108, 100, 100); // Gris

  static Color getPlayerColor(int playerId) {
    switch (playerId) {
      case 0:
        return player0;
      case 1:
        return player1;
      case 2:
        return player2;
      case 3:
        return player3;
      case 4:
        return player4;
      default:
        return playerDefault;
    }
  }
}

/// Utilidades para convertir colores Flutter a formatos usados por Three.js.
extension ForColorHex on Color {
  String get rgbHex {
    final int rgb = toARGB32() & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}

/// Espaciados reutilizables para separar elementos de interfaz.
class ForSpacing {
  const ForSpacing._();

  // Escala general: separaciones basicas usadas en formularios, paneles,
  // dialogos, listas y controles de la interfaz.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  // Separaciones especificas: ajustan huecos concretos de toolbar,
  // filas compactas, mensajes con gif, dialogos y creditos.
  static const double toolbarGap = 5;
  static const double compactGap = 6;
  static const double messageGap = 10;
  static const double dialogGap = 18;
  static const double creditsSpacer = 14;
}

/// Radios de borde reutilizables para botones, paneles y modales.
class ForRadius {
  const ForRadius._();

  // Bordes redondeados: afectan a botones, tarjetas, paneles, dialogos,
  // miniaturas, chips tipo "Bot" y superficies interactivas.
  static const double button = 16;
  static const double compactButton = 8;
  static const double panel = 12;
  static const double contentPanel = 22;
  static const double dialog = 28;
  static const double pill = 999;
}

/// Tamaños fijos o maximos usados por componentes concretos.
class ForSizes {
  const ForSizes._();

  // Iconos y botones: controla el tamano de iconos, botones de toolbar
  // y rellenos verticales de botones principales o de mercado.
  static const double icon = 32;
  static const double toolbarButtonHeight = 42;
  static const double menuButtonHorizontalPadding = 20;
  static const double menuButtonCompactHorizontalPadding = 14;
  static const double menuButtonVerticalPadding = 16;
  static const double menuButtonCompactVerticalPadding = 12;
  static const double marketButtonVerticalPadding = 8;

  // Catalogo y dialogos online/locales: afecta al ancho/alto de catalogos,
  // leaderboard, union remota y selector de jugadores locales.
  static const double catalogWidth = 540;
  static const double catalogHeight = 360;
  static const double leaderboardWidth = 420;
  static const double leaderboardEmptyHeight = 160;
  static const double leaderboardErrorHeight = 180;
  static const double remoteJoinDialogWidth = 420;
  static const double localPlayerDialogMaxWidth = 420;
  static const double playerKindDropdownWidth = 160;

  // HUD de jugadores: afecta al ancho de la columna de jugadores, tarjetas,
  // bordes de jugador activo, sombras e insignia de bot.
  static const double playersHudWidth = 140;
  static const double playerPanelWidth = 250;
  static const double playerCardVerticalPadding = 10;
  static const double playerActiveBorderWidth = 2.2;
  static const double playerDefaultBorderWidth = 1;
  static const double playerActiveShadowBlur = 12;
  static const double playerActiveShadowSpread = 1;
  static const double playerBotBadgeVerticalPadding = 3;
  static const double playerBotIconSize = 12;

  // Alertas: afecta al borde, sombra e icono de avisos importantes como
  // jugadores desconectados.
  static const double alertBorderWidth = 1.4;
  static const double alertShadowBlur = 18;
  static const double alertShadowOffsetY = 8;
  static const double alertIconTopPadding = 2;
  static const double alertIconSize = 28;

  // Miniaturas y mensajes: controla previews 3D de edificios y gifs
  // decorativos en mensajes del tablero.
  static const double thumbnailWidth = 86;
  static const double thumbnailHeight = 68;
  static const double messageGifSize = 34;

  // Dialogo de creditos: afecta al tamano maximo, margenes, marco, sombra,
  // paddings internos, fundidos y area de texto de agradecimientos.
  static const double creditsDialogMaxWidth = 760;
  static const double creditsDialogMaxHeightFactor = 0.8;
  static const double creditsDialogInsetHorizontal = 28;
  static const double creditsDialogInsetVertical = 32;
  static const double creditsDialogFrameWidth = 1.6;
  static const double creditsDialogInnerMargin = 2;
  static const double creditsDialogHeaderTopPadding = 22;
  static const double creditsDialogHeaderBottomPadding = 20;
  static const double contentDialogTitleGap = 2;
  static const double creditsLoadingPadding = 32;
  static const double creditsErrorPadding = 24;
  static const double creditsPanelMaxWidth = 460;
  static const double creditsPanelTopPadding = 88;
  static const double creditsPanelBottomPadding = 44;
  static const double creditsFadeHeight = 34;
  static const double creditsSubtitleBottomPadding = 28;
  static const double creditsShadowBlur = 28;
  static const double creditsShadowOffsetY = 16;
}

/// Estilos de texto reutilizables.
class ForTypography {
  const ForTypography._();

  // Fuente global: se aplica como familia tipografica base en ThemeData.
  static const String fontFamily = 'Roboto';

  // Botones: afecta a botones del menu, toolbar, mercado y acciones de
  // dialogos que reutilizan los estilos globales de Flutter.
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

  // Paneles y textos generales: afecta a titulos de paneles, cuerpos breves,
  // secciones de catalogo, errores y texto auxiliar de la interfaz.
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

  // Catalogo de edificios: afecta a nombres, descripciones, requisitos y
  // estados deshabilitados dentro del panel de construccion.
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

  // HUD y estadisticas de jugadores: afecta a nombre del jugador, lineas
  // de estadisticas, etiqueta "Bot" y textos de ayuda.
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

  // Alertas y estado de partida: afecta a avisos, resumen final, mensajes
  // de desconexion y placa de era actual.
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

  static const TextStyle eraBadge = TextStyle(
    color: ForColors.gold,
    fontSize: 13,
    fontWeight: FontWeight.bold,
  );

  // Creditos: afecta al texto del panel de agradecimientos, incluyendo
  // titulo principal, subtitulo, secciones, etiquetas, nombres y parrafos.
  static const TextStyle creditsHero = TextStyle(
    color: ForColors.goldLight,
    fontSize: 25,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 1.2,
  );

  static const TextStyle creditsSubtitle = TextStyle(
    color: ForColors.goldPale,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.4,
    letterSpacing: 1.6,
  );

  static const TextStyle creditsSection = TextStyle(
    color: ForColors.goldPale,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.8,
  );

  static const TextStyle creditsEntryLabel = TextStyle(
    color: ForColors.parchmentDark,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const TextStyle creditsEntryBody = TextStyle(
    color: ForColors.parchment,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  static const TextStyle creditsParagraph = TextStyle(
    color: ForColors.parchment,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.7,
  );
}

/// Estilos de botones compartidos por menu, toolbar y dialogos.
class ForButtonStyles {
  const ForButtonStyles._();

  // Botones de icono: afecta a botones circulares o cuadrados pequenos,
  // especialmente el cierre del dialogo de creditos.
  static ButtonStyle icon() {
    return IconButton.styleFrom(
      backgroundColor: ForColors.iconButtonOverlay,
      foregroundColor: ForColors.goldLight,
    );
  }

  // Boton principal del menu: afecta a las acciones grandes de la pantalla
  // inicial como iniciar partida o abrir modos.
  static ButtonStyle menuPrimary({bool compact = false}) {
    return ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: compact
            ? ForSizes.menuButtonCompactHorizontalPadding
            : ForSizes.menuButtonHorizontalPadding,
        vertical: compact
            ? ForSizes.menuButtonCompactVerticalPadding
            : ForSizes.menuButtonVerticalPadding,
      ),
      backgroundColor: ForColors.panelSoft,
      foregroundColor: ForColors.text,
      disabledForegroundColor: ForColors.textDisabled,
      textStyle: ForTypography.menuButton,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ForRadius.button),
        side: const BorderSide(color: ForColors.border),
      ),
    );
  }

  // Botones del tablero: afecta a toolbar y acciones compactas durante
  // una partida.
  static ButtonStyle toolbar() {
    return ElevatedButton.styleFrom(
      minimumSize: const Size(0, ForSizes.toolbarButtonHeight),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: ForColors.panelSoft,
      foregroundColor: ForColors.text,
      disabledForegroundColor: ForColors.textDisabled,
      textStyle: ForTypography.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ForRadius.compactButton),
        side: const BorderSide(color: ForColors.border),
      ),
    );
  }

  // Botones del mercado de parcelas: afecta a cada opcion comprable de
  // la barra de escrituras.
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

/// Tema Material global de la aplicacion Flutter.
class ForTheme {
  const ForTheme._();

  // Tema Material global: conecta esta paleta con Flutter y define como
  // se ven botones, dialogos, snackbars y fondo general por defecto.
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
            borderRadius: BorderRadius.circular(ForRadius.compactButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ForColors.goldLight,
          side: const BorderSide(color: ForColors.border),
          textStyle: ForTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ForRadius.compactButton),
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
          borderRadius: BorderRadius.circular(ForRadius.panel),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ForColors.panelDark,
        contentTextStyle: TextStyle(color: ForColors.text),
      ),
    );
  }
}
