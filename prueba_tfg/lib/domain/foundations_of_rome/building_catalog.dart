import 'entities/building.dart';
import 'value_objects/building_type.dart';

var costes = [2, 3, 4, 6, 8, 10]; // Ejemplo de costes crecientes

const List<String> idsMonumentos = [
  "Panteon",
  "ForoRomano",
  "CircoMaximo",
  "TemploVulcano",
  "TemploMinerva",
  "TorreMaravillas",
  "TemploMarte",
  "TemploNeptuno",
  "Faro",
  "TorreObservacion",
  "TemploJupiter",
  "Coliseo",
  "BodegaReal",
  "Regia",
  "EstatuaRomulo",
  "TemploVenus",
  "TemploApolo",
  "ArcoTriunfo",
  "PuertoImperial",
];

final Set<String> conjuntoIdsMonumentos = Set<String>.unmodifiable(idsMonumentos);

final List<Edificio> catalogoEdificios = [
  // ====== RESIDENCIALES ======
  // A.a - 2 x Domus: 1x1
  Edificio(
    id: "DomusI",
    name: "Domus I",
    description: "+1 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),
  Edificio(
    id: "DomusII",
    name: "Domus II",
    description: "+1 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // A.b - 2 x Domus máxima: 1x2
  Edificio(
    id: "DomusMaximaI",
    name: "Domus Máxima I",
    description: "+2 Población",

    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),
  Edificio(
    id: "DomusMaximaII",
    name: "Domus Máxima II",
    description: "+2 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // A.c - 1 x Insula tipo A: 2x2 (L)
  Edificio(
    id: "InsulaL",

    name: "Insula L",
    description: "+4 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [-1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
      ],
    ],
    rotationNames: [
      "L - Izquierda y Arriba",
      "L - Derecha y Arriba",
      "L - Derecha y Abajo",
      "L - Izquierda y Abajo",
    ],
  ),

  // A.d - 1 x Insula tipo B: 1x3
  Edificio(
    id: "Insula",
    name: "Insula",
    description: "+4 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // A.e - 1 x Gran Insula tipo A: 2x2
  Edificio(
    id: "GranInsulaCuadrada",
    name: "Gran Insula Cuadrada",
    description: "+6 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
        [-1, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [-1, 0],
        [-1, -1],
      ],
    ],
    rotationNames: [
      "Bloque 2x2 Arriba Derecha",
      "Bloque 2x2 Abajo Derecha",
      "Bloque 2x2 Abajo Izquierda",
      "Bloque 2x2 Arriba Izquierda",
    ],
  ),

  // A.f - 1 x Gran Insula tipo B: 1x4
  Edificio(
    id: "GranInsulaRecta",
    name: "Gran Insula Recta",
    description: "+6 Población",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [-3, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
        [0, -3],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),

  // ====== COMERCIALES ======
  // B.a - 2 x Panadería: 1x1
  Edificio(
    id: "PanaderiaI",
    name: "Panadería I",
    description: "+1 Moneda al recaudar",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),
  Edificio(
    id: "PanaderiaII",

    name: "Panadería II",
    description: "+1 Monedas al recaudar",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // B.b - 2 x Alfarería: 1x2
  Edificio(
    id: "AlfareriaI",
    name: "Alfarería I",
    description: "+1 Monedas al recaudar / +2 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),
  Edificio(
    id: "AlfareriaII",
    name: "Alfarería II",

    description: "+1 Monedas al recaudar / +2 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // B.c - 1 x Foro artesano tipo A: 2x2 (L)
  Edificio(
    id: "ForoArtesanoL",
    name: "Foro Artesano L",
    description: "+2 Monedas al recaudar / +3 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [-1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
      ],
    ],
    rotationNames: [
      "L - Izquierda y Arriba",
      "L - Derecha y Arriba",
      "L - Derecha y Abajo",
      "L - Izquierda y Abajo",
    ],
  ),

  // B.d - 1 x Foro artesano tipo B: 1x3
  Edificio(
    id: "ForoArtesano",
    name: "Foro Artesano",
    description: "+2 Monedas al recaudar / +3 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // B.e - 1 x Fundición tipo A: 2x2
  Edificio(
    id: "FundicionCuadrada",
    name: "Fundición Cuadrada",
    description: "+3 Monedas al recaudar / +5 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
        [-1, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [-1, 0],
        [-1, -1],
      ],
    ],
    rotationNames: [
      "Bloque 2x2 Arriba Derecha",
      "Bloque 2x2 Abajo Derecha",
      "Bloque 2x2 Abajo Izquierda",
      "Bloque 2x2 Arriba Izquierda",
    ],
  ),

  // B.f - 1 x Fundición tipo B: 1x4
  Edificio(
    id: "FundicionRecta",
    name: "Fundición Recta",
    description: "+3 Monedas al recaudar / +5 Gloria final partida",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [-3, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
        [0, -3],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),

  // ====== CIVICOS ======
  // C.a - 1 x Fuente: 1x1
  Edificio(
    id: "Fuente",
    name: "Fuente",
    description: "+1 Gloria por cada edificio adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // C.b - 1 x Biblioteca: 1x1
  Edificio(
    id: "Biblioteca",
    name: "Biblioteca",
    description: "+1 Gloria por cada 2 ciudadanos en edificios adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // C.c - 1 x Biblioteca VIP: 1x2
  Edificio(
    id: "BibliotecaVIP",
    name: "Biblioteca VIP",
    description: "+1 Gloria por cada ciudadano en edificios adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // C.d - 1 x Fuente majestuosa: 1x2
  Edificio(
    id: "FuenteMajestuosa",
    name: "Fuente Majestuosa",
    description: "+1 Gloria por cada edificio adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // C.e - 1 x Jardín lujoso: 1x2
  Edificio(
    id: "JardinLujoso",
    name: "Jardín Lujoso",
    description: "+3 Gloria por cada edificio municipal adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // C.f - 1 x Mercado: 1x2
  Edificio(
    id: "Mercado",
    name: "Mercado",
    description:
        "+2 Gloria por cada moneda en edificios comerciales adyacentes.",
    type: TipoEdificio.civic,
    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // C.g - 1 x Mercadillo: 1x1
  Edificio(
    id: "Mercadillo",
    name: "Mercadillo",
    description: "+1 Gloria por cada edificio comercial adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // C.h - 1 x Jardín: 1x1
  Edificio(
    id: "Jardin",
    name: "Jardín",
    description: "+2 Gloria por cada edificio municipal adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Posición Única"],
  ),

  // ====== MONUMENTOS ======
  // a. El Panteón: 1x3 horizontal
  Edificio(
    id: "Panteon",
    name: "El Panteón",
    description:
        "+3 Gloria por cada edificio municipal adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // b. Foro Romano: 1x3 horizontal
  Edificio(
    id: "ForoRomano",
    name: "Foro Romano",
    description:
        "+2 Gloria por cada moneda en edificios comerciales adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),

  // c. Circo Máximo: 1x3 horizontal
  Edificio(
    id: "CircoMaximo",
    name: "Circo Máximo",
    description:
        "+1 Gloria por cada ciudadano en edificios residenciales adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),

  // d. Templo de Vulcano: 2x3 T
  Edificio(
    id: "TemploVulcano",
    name: "Templo de Vulcano",
    description:
        "+1 Moneda + (1 Moneda por cada edificio adyacente).",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [-1, 0],
        [1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [0, -1],
        [0, 1],
        [-1, 0],
      ],
      [
        [0, 0],
        [-1, 0],
        [1, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [0, 1],
        [1, 0],
      ],
    ],
    rotationNames: ["T - Arriba", "T - Izquierda", "T - Abajo", "T - Derecha"],
  ),

  // e. Templo de Minerva: 2x3 U
  Edificio(
    id: "TemploMinerva",
    name: "Templo de Minerva",
    description:
        "+2 Población (+1 Población por cada ciudadano en edificios adyacentes).",
    type: TipoEdificio.residential,

    rotations: [
      // Forma U (5 casillas), con hueco orientable
      // [
      //   [0, 0],
      //   [0, 1],
      //   [1, 1],
      //   [2, 1],
      //   [2, 0],
      // ],
      // [
      //   [0, 0],
      //   [1, 0],
      //   [2, 0],
      //   [0, 1],
      //   [2, 1],
      // ],
      // [
      //   [0, 0],
      //   [0, 1],
      //   [0, 2],
      //   [1, 0],
      //   [1, 2],
      // ],
      // [
      //   [0, 0],
      //   [0, 1],
      //   [0, 2],
      //   [-1, 0],
      //   [-1, 2],
      // ],
      [
        [0, 0],
        [0, 1],
        [-1, 0],
        [-2, 0],
        [-2, 1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, 1],
        [0, 2],
        [1, 2],
      ],
      [
        [0, 0],
        [0, -1],
        [1, 0],
        [2, 0],
        [2, -1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, -1],
        [0, -2],
        [-1, -2],
      ],
    ],

    // rotationNames: ["U - Arriba", "U - Abajo", "U - Derecha", "U - Izquierda"],
    rotationNames: ["U - Abajo", "U - Derecha", "U - Arriba", "U - Izquierda"],
  ),
  // f. Torre de las Maravillas: 1x1
  Edificio(
    id: "TorreMaravillas",
    name: "Torre de las Maravillas",
    description: "+3 Gloria.",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Única"],
  ),

  // g. Templo de Marte: 2x2 L
  Edificio(
    id: "TemploMarte",
    name: "Templo de Marte",
    description:
        "+5 Población.",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [-1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
      ],
    ],
    rotationNames: [
      "L - Izquierda y Arriba",
      "L - Derecha y Arriba",
      "L - Derecha y Abajo",
      "L - Izquierda y Abajo",
    ],
  ),

  // h. Templo de Neptuno: 2x2 L
  Edificio(
    id: "TemploNeptuno",
    name: "Templo de Neptuno",
    description:
        "+1 Moneda y +5 Gloria.",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [-1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, -1],
      ],
      [
        [0, 0],
        [1, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
      ],
    ],
    rotationNames: [
      "L - Izquierda y Arriba",
      "L - Derecha y Arriba",
      "L - Derecha y Abajo",
      "L - Izquierda y Abajo",
    ],
  ),

  // i. Faro: 1x1
  Edificio(
    id: "Faro",
    name: "Faro",
    description:
        "+2 Gloria por cada moneda en edificios comerciales adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Única"],
  ),

  // j. Torre de Observación: 1x1
  Edificio(
    id: "TorreObservacion",
    name: "Torre de Observación",
    description:
        "+1 Gloria por cada ciudadanos en edificios residenciales adyacentes.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
      ],
    ],
    rotationNames: ["Única"],
  ),

  // k. Templo de Júpiter: 2x2 bloque
  Edificio(
    id: "TemploJupiter",
    name: "Templo de Júpiter",
    description:
        "+5 Gloria por cada moneda en edificios comerciales adyacentes. Cuando se construye, cada jugador con al menos un edificio adyacente a este monumento gana +2 Gloria.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
        [-1, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [-1, 0],
        [-1, -1],
      ],
    ],
    rotationNames: [
      "Bloque 2x2 Arriba Derecha",
      "Bloque 2x2 Abajo Derecha",
      "Bloque 2x2 Abajo Izquierda",
      "Bloque 2x2 Arriba Izquierda",
    ],
  ),

  // l. Coliseo: 2x2 bloque
  Edificio(
    id: "Coliseo",
    name: "Coliseo",
    description:
        "+1 Gloria por cada ciudadano en edificios residenciales adyacentes. Cuando se construye, cada jugador con al menos un edificio adyacente a este monumento gana +3 Monedas.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
        [-1, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [-1, 0],
        [-1, -1],
      ],
    ],
    rotationNames: [
      "Bloque 2x2 Arriba Derecha",
      "Bloque 2x2 Abajo Derecha",
      "Bloque 2x2 Abajo Izquierda",
      "Bloque 2x2 Arriba Izquierda",
    ],
  ),

  // m. Bodega Real: 2x3 bloque
  Edificio(
    id: "BodegaReal",
    name: "Bodega Real",
    description: "+4 Monedas, +8 Gloria.",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [0, 1],
        [1, 1],
        [2, 1],
      ],

      [
        [0, 0],
        [1, 0],
        [0, 1],
        [1, 1],
        [0, 2],
        [1, 2],
      ],

      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [0, 1],
        [-1, 1],
        [-2, 1],
      ],

      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
        [0, -2],
        [1, -2],
      ],
    ],
    rotationNames: [
      "Bloque 2x3 Horizontal (Derecha)",
      "Bloque 2x3 Vertical (Abajo)",
      "Bloque 2x3 Horizontal (Izquierda)",
      "Bloque 2x3 Vertical (Arriba)",
    ],
  ),

  // n. Regia: 2x3 bloque
  Edificio(
    id: "Regia",
    name: "Regia",
    description: "+9 Población.",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [0, 1],
        [1, 1],
        [2, 1],
      ],

      [
        [0, 0],
        [1, 0],
        [0, 1],
        [1, 1],
        [0, 2],
        [1, 2],
      ],

      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [0, 1],
        [-1, 1],
        [-2, 1],
      ],

      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
        [0, -2],
        [1, -2],
      ],
    ],
    rotationNames: [
      "Bloque 2x3 Horizontal (Derecha)",
      "Bloque 2x3 Vertical (Abajo)",
      "Bloque 2x3 Horizontal (Izquierda)",
      "Bloque 2x3 Vertical (Arriba)",
    ],
  ),

  // o. Estatua de Rómulo: 2x2 bloque
  Edificio(
    id: "EstatuaRomulo",
    name: "Estatua de Rómulo",
    description:
        "+2 Gloria por cada edificio adyacente.",
    type: TipoEdificio.civic,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [0, -1],
        [1, -1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [-1, 0],
        [0, 1],
        [-1, 1],
      ],
      [
        [0, 0],
        [0, -1],
        [-1, 0],
        [-1, -1],
      ],
    ],
    rotationNames: [
      "Bloque 2x2 Arriba Derecha",
      "Bloque 2x2 Abajo Derecha",
      "Bloque 2x2 Abajo Izquierda",
      "Bloque 2x2 Arriba Izquierda",
    ],
  ),

  // p. Templo de Venus: 1x2
  Edificio(
    id: "TemploVenus",
    name: "Templo de Venus",
    description:
        "+4 Población.",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // q. Templo de Apolo: 1x2
  Edificio(
    id: "TemploApolo",
    name: "Templo de Apolo",
    description:
        "+2 Monedas, +2 Gloria.",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
      ],

      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [-1, 0],
      ],

      [
        [0, 0],
        [0, -1],
      ],
    ],
    rotationNames: [
      "Horizontal (Derecha)",
      "Vertical (Abajo)",
      "Horizontal (Izquierda)",
      "Vertical (Arriba)",
    ],
  ),

  // r. Arco del Triunfo: 1x4
  Edificio(
    id: "ArcoTriunfo",
    name: "Arco del Triunfo",
    description:
        "+7 Población.",
    type: TipoEdificio.residential,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [-3, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
        [0, -3],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),

  // s. Puerto Imperial: 1x4
  Edificio(
    id: "PuertoImperial",
    name: "Puerto Imperial",
    description:
        "+3 Monedas, +7 Gloria.",
    type: TipoEdificio.commercial,

    rotations: [
      [
        [0, 0],
        [1, 0],
        [2, 0],
        [3, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ],
      [
        [0, 0],
        [-1, 0],
        [-2, 0],
        [-3, 0],
      ],
      [
        [0, 0],
        [0, -1],
        [0, -2],
        [0, -3],
      ],
    ],
    rotationNames: [
      "Horizontal Derecha",
      "Vertical Abajo",
      "Horizontal Izquierda",
      "Vertical Arriba",
    ],
  ),
];

final Map<String, Edificio> catalogoEdificiosPorId =
    Map<String, Edificio>.unmodifiable(<String, Edificio>{
      for (final Edificio building in catalogoEdificios) building.id: building,
    });

Edificio? buscarEdificioPorId(String value) {
  return catalogoEdificiosPorId[value.trim()];
}
