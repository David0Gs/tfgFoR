# Diagramas Mermaid - Foundations of Rome Digital

Diagramas de arquitectura, flujos y casos de uso en formato Mermaid para visualizar con la extensión "Markdown Preview Mermaid Support".

Para visualizar: `Cmd+Shift+V` en VS Code

---

## 1. Arquitectura General del Monorepo

```mermaid
graph TB
    subgraph frontend["🎮 Frontend"]
        FApp["Aplicación Flutter"]
        FPres["Presentation: Screens & Widgets"]
        FApp3D["Visor 3D con Three.js"]
        FWS["Cliente WebSocket"]
        FPersist["Persistencia Local JSON"]
        FAudio["Audio Service"]
    end
    
    subgraph packages["📦 Packages (for_core)"]
        PCore["Core - Dominio del Juego"]
        PEntities["Entidades: Juego, Jugador,<br/>Edificio, Propiedad"]
        PProtocol["Protocolo Remoto<br/>DTOs Compartidos"]
    end
    
    subgraph server["🖥️ Server"]
        SHttp["HTTP Server"]
        SWS["WebSocket"]
        SRooms["GameRoomManager<br/>GameRoom, PlayerSession"]
        SPersist["Persistencia:<br/>PartidaRepository,<br/>RankingRepository"]
        SLogging["ServerLogger"]
    end
    
    subgraph external["📊 Sistemas Externos"]
        PG["PostgreSQL"]
        SQLite["SQLite Fallback"]
    end
    
    subgraph doc["📄 Documentación"]
        DocInt["Docs Internas"]
        DocTFG["Memoria TFG"]
    end
    
    frontend --> packages
    server --> packages
    frontend -->|WebSocket/HTTP| server
    server --> PG
    server --> SQLite
    
    style frontend fill:#e1f5ff
    style packages fill:#f3e5f5
    style server fill:#e8f5e9
    style external fill:#fff3e0
    style doc fill:#fce4ec
    
    classDef note fill:#ffebee,stroke:#c62828,color:#000
```

**Nota Clave:** El cliente nunca accede directamente a la base de datos. Todo pasa por el servidor.

---

## 2. Flujo de Datos - Partida Local

```mermaid
graph TD
    A["1. Usuario abre app"] --> B["2. main.dart<br/>runFlutterApp"]
    B --> C["3. app_entrypoint.dart<br/>ApplicationConfig"]
    C --> D["4. PantallaMenuPrincipal"]
    D --> E["👆 Iniciar Partida Local"]
    
    E --> F["5. SeleccionJugadoresLocal"]
    F --> G["6. LocalGameConfiguration"]
    G --> H["7. PantallaTablero"]
    
    H --> I["8. Crear JUEGO<br/>(Fuente de Verdad)"]
    I --> J["9. Inicializar:<br/>Jugadores, Tablero<br/>Mazos, Mercado, Monumentos"]
    
    J --> K["10. Visor3D<br/>Carga escena Three.js"]
    K --> L["11. TableroController<br/>Sincroniza Juego ↔ 3D"]
    
    L --> M["Bucle de Juego"]
    
    M --> N["👆 Acción: Comprar,<br/>Construir o Ingresos"]
    N --> O["PantallaTablero<br/>llama Juego.metodo()"]
    O --> P["Juego valida<br/>y actualiza estado"]
    P --> Q["Actualizar Widgets<br/>& Visor 3D"]
    
    Q --> R{"¿Toca Bot?"}
    R -->|Sí| S["LocalBotTurnRunner<br/>decide acción"]
    S --> O
    R -->|No| T{"¿Fin de Era?"}
    
    T -->|Sí| U["Juego genera<br/>Resumen de Era"]
    U --> V["ResumenPartidaDialog"]
    V --> W{"¿Era III?"}
    W -->|Sí| X["✅ Calcular Ranking<br/>& Terminar"]
    W -->|No| M
    T -->|No| M
    
    style I fill:#c8e6c9
    style K fill:#bbdefb
    style M fill:#fff9c4
    style X fill:#ffccbc
    
    classDef zone fill:#f5f5f5,stroke:#666,stroke-width:2px
    class I zone
    class K zone
```

**Tres zonas principales:**
- 🎨 **Interfaz Flutter:** Widgets y screens
- 🎮 **Dominio (Juego):** Motor de reglas (fuente de verdad)
- 🌐 **Visor 3D:** Visualización con Three.js

---

## 3. Flujo de Datos - Acción Remota (Secuencia)

```mermaid
sequenceDiagram
    actor Player as 👤 Jugador
    participant UI as PantallaTablero
    participant Remote as SesionRemotaController
    participant WS as WebSocket
    participant Server as FoundationsServer
    participant Room as GameRoom
    participant Game as Juego<br/>packages
    participant Repo as PartidaRepository
    participant Clients as Otros Clientes
    
    Player->>UI: 👆 Compra/Construye/Ingresos
    Note over UI: Modo remoto: NO modifica Juego localmente
    
    UI->>Remote: ActionRequest
    Note over Remote: requestId = UUID
    
    Remote->>WS: Envía por WebSocket
    WS->>Server: Mensaje JSON
    Server->>Room: Entrega a GameRoom
    
    Room->>Room: ✓ Valida turno, jugador, sessionToken
    Room->>Game: Ejecuta acción
    
    Note over Game: Juego valida reglas
    alt Acción válida
        Game-->>Room: ✓ OK
        Room->>Repo: Guarda evento + snapshot
        Room->>WS: actionAccepted (requestId)
        WS->>Remote: Mensaje confirmación
        Remote->>UI: Actualiza estado
        Room->>Clients: Envía snapshot a todos
        Clients->>Clients: Reconstruyen Juego desde JSON
    else Acción inválida
        Game-->>Room: ✗ GameError
        Room->>WS: actionRejected (requestId, reason)
        WS->>Remote: Mensaje rechazo
        Remote->>UI: Muestra error
    end
    
    UI->>UI: Actualiza HUD, mercado,<br/>tablero y visor 3D
    UI-->>Player: ✅ Resultado

    style Game fill:#c8e6c9
    style Room fill:#b3e5fc
    style Remote fill:#ffe0b2
```

**Flujos:**
- ✅ **Éxito:** `actionAccepted` + snapshot → todos actualizan
- ❌ **Error:** `actionRejected` + motivo → UI muestra error

**El servidor es la autoridad en modo remoto**

---

## 4. Arquitectura - Módulo Frontend

```mermaid
graph TB
    subgraph Entry["🚀 ENTRY POINT"]
        Main["main.dart"]
        AppEntry["app_entrypoint.dart"]
        AppConfig["ApplicationConfig"]
        MaterialApp["MaterialApp<br/>Rutas principales"]
    end
    
    subgraph Presentation["🎨 PRESENTATION"]
        MenuPrincipal["PantallaMenuPrincipal"]
        PantallaTablero["PantallaTablero"]
        Widgets["PlayersHud<br/>DeedMarketBar<br/>BoardToolbar<br/>BuildingCatalogOverlay"]
        Dialogs["ContenidoDialog<br/>RemoteJoinDialog<br/>ResumenPartidaDialog"]
    end
    
    subgraph Application["⚙️ APPLICATION"]
        LocalConfig["LocalGameConfiguration"]
        LocalBotRunner["LocalBotTurnRunner"]
        BotService["FoundationsOfRomeBotService"]
    end
    
    subgraph Infrastructure["🔧 INFRASTRUCTURE"]
        AudioSvc["AudioService"]
        PersistLocal["Persistencia JSON"]
        RemoteCtrl["SesionRemotaController"]
        RemoteStore["RemoteSessionStore"]
    end
    
    subgraph Visor3D_Module["🌐 VISOR 3D"]
        Visor3D["Visor3D"]
        TableroCtrl["TableroController"]
        PlatformFactory["Factory de Plataforma<br/>web/desktop/mobile"]
        ThreeScene["Escena Three.js"]
    end
    
    subgraph Shared["📦 SHARED (packages)"]
        SharedGame["Juego - Motor<br/>Entidades y Reglas"]
        SharedProto["Protocolo Remoto"]
    end
    
    Main --> AppEntry
    AppEntry --> AppConfig
    AppEntry --> MaterialApp
    
    MaterialApp --> MenuPrincipal
    MaterialApp --> PantallaTablero
    
    PantallaTablero --> Widgets
    PantallaTablero --> Dialogs
    PantallaTablero --> LocalConfig
    
    LocalConfig --> LocalBotRunner
    LocalBotRunner --> BotService
    
    PantallaTablero --> RemoteCtrl
    RemoteCtrl --> RemoteStore
    RemoteCtrl -->|WebSocket| Infrastructure
    
    PantallaTablero --> Visor3D
    Visor3D --> TableroCtrl
    TableroCtrl --> PlatformFactory
    PlatformFactory --> ThreeScene
    
    PantallaTablero --> SharedGame
    RemoteCtrl --> SharedProto
    
    style Entry fill:#fff9c4
    style Presentation fill:#e1f5ff
    style Application fill:#f3e5f5
    style Infrastructure fill:#e8f5e9
    style Visor3D_Module fill:#ffe0b2
    style Shared fill:#c8e6c9
```

**Nota:** "La UI no contiene reglas de juego; muestra estado y delega acciones"

---

## 5. Arquitectura - Módulo Server

```mermaid
graph TB
    subgraph Entry_Server["🚀 ENTRY POINT"]
        Start["bin/start_server.dart"]
        EnvFile["Carga .env"]
        Config["ServerConfig"]
        FoundServer["Arranca FoundationsServer"]
    end
    
    subgraph Config_Module["⚙️ CONFIG"]
        EnvParser["env_file.dart"]
        ServerCfg["server_config.dart"]
        CLIArgs["Argumentos CLI<br/>FOR_HOST, FOR_PORT<br/>FOR_DB, FOR_SQLITE_FALLBACK<br/>FOR_ACCESS_TOKEN, FOR_RESTORE_ROOMS"]
    end
    
    subgraph Core_Server["🖥️ FOUNDATIONS SERVER"]
        HttpServer["HTTP Server"]
        WebSocketUpgrade["WebSocket Upgrade"]
        Routes["Rutas:<br/>/health, /leaderboard, /games"]
    end
    
    subgraph Rooms["🎮 ROOMS MANAGEMENT"]
        RoomManager["GameRoomManager"]
        GameRoom["GameRoom"]
        PlayerSession["PlayerSession<br/>alias, sessionToken<br/>reconexión 3min"]
    end
    
    subgraph Persistence["💾 PERSISTENCE"]
        RankRepo["RankingRepository"]
        GameRepo["PartidaRepository"]
        SqliteRank["SqliteRankingRepository"]
        PostgresRank["PostgresRankingRepository"]
        SqliteGame["SqlitePartidaRepository"]
        PostgresGame["PostgresPartidaRepository"]
        SqliteBackup["SqliteBackupSync"]
    end
    
    subgraph Logging["📋 LOGGING"]
        Logger["ServerLogger<br/>info, warning, error"]
    end
    
    subgraph Shared["📦 SHARED"]
        SharedGame["Juego - Validación"]
        SharedProto["Protocolo Remoto"]
    end
    
    subgraph External["🌍 EXTERNOS"]
        Clients["Clientes Flutter<br/>WebSocket/HTTP"]
        PG["PostgreSQL"]
        SQLite_DB["SQLite Fallback"]
    end
    
    Start --> EnvFile
    EnvFile --> Config
    Config --> FoundServer
    
    FoundServer --> HttpServer
    FoundServer --> WebSocketUpgrade
    FoundServer --> Routes
    
    Routes --> RoomManager
    RoomManager --> GameRoom
    GameRoom --> PlayerSession
    
    GameRoom --> SharedGame
    GameRoom --> SharedProto
    GameRoom --> GameRepo
    
    FoundServer --> RankRepo
    FoundServer --> Logger
    
    RankRepo --> SqliteRank
    RankRepo --> PostgresRank
    GameRepo --> SqliteGame
    GameRepo --> PostgresGame
    
    SqliteGame --> SQLite_DB
    PostgresGame --> PG
    SqliteRank --> SQLite_DB
    PostgresRank --> PG
    
    SqliteBackup --> SQLite_DB
    SqliteBackup --> PG
    
    Clients -->|WebSocket| FoundServer
    Clients -->|HTTP| FoundServer
    
    style Entry_Server fill:#fff9c4
    style Core_Server fill:#e1f5ff
    style Rooms fill:#f3e5f5
    style Persistence fill:#c8e6c9
    style Logging fill:#e8f5e9
    style Shared fill:#ffe0b2
    style External fill:#ffccbc
```

**Nota:** "El servidor es la autoridad de la partida remota"

---

## 6. Arquitectura - Módulo Packages (for_core)

```mermaid
graph TB
    subgraph Core_Dom["🎮 CORE / DOMINIO"]
        CoreFile["packages/lib/core.dart"]
        ForCore["packages/lib/for_core.dart"]
        Domain["core/foundations_of_rome/"]
        
        Entities["Entidades:<br/>Juego<br/>Jugador<br/>Edificio<br/>Propiedad<br/>CartaEscritura<br/>Era"]
        
        Rules["Reglas:<br/>RuleError<br/>GameError"]
        
        Support["Soporte:<br/>building_catalog.dart<br/>alias_online.dart<br/>entrada_leaderboard.dart"]
        
        Serialization["JSON Serialization"]
    end
    
    subgraph Protocol_Rem["🔌 PROTOCOLO REMOTO"]
        ProtocolFile["packages/lib/protocol.dart"]
        ForProto["packages/lib/for_protocol.dart"]
        RemoteProto["protocol/remote_protocol.dart"]
        
        Messages["Mensajes:<br/>JoinRequest<br/>JoinedMessage<br/>ActionRequest<br/>ActionAcceptedMessage<br/>ActionRejectedMessage<br/>SnapshotMessage<br/>LeaderboardMessage"]
    end
    
    subgraph Consumers["👥 CONSUMIDORES"]
        Frontend["Frontend"]
        Server["Server"]
    end
    
    subgraph Constraints["🚫 RESTRICCIONES"]
        NoFlutter["❌ No importa Flutter"]
        NoServer["❌ No importa código de server"]
        PureDart["✓ Dart puro"]
        SharedSource["✓ Fuente compartida"]
    end
    
    CoreFile --> ForCore
    ForCore --> Domain
    Domain --> Entities
    Domain --> Rules
    Domain --> Support
    Entities --> Serialization
    
    ProtocolFile --> ForProto
    ForProto --> RemoteProto
    RemoteProto --> Messages
    
    Frontend -->|usa| Core_Dom
    Frontend -->|usa| Protocol_Rem
    Server -->|usa| Core_Dom
    Server -->|usa| Protocol_Rem
    
    Core_Dom --> Constraints
    Protocol_Rem --> Constraints
    
    style Core_Dom fill:#c8e6c9
    style Protocol_Rem fill:#b3e5fc
    style Consumers fill:#fff9c4
    style Constraints fill:#ffccbc
```

**Restricciones de diseño:**
- Sin Flutter
- Sin código de server
- Dart puro (portable)
- Fuente única de verdad

---

## 7. Casos de Uso - Modo Remoto

```mermaid
graph TB
    subgraph Actors["👥 ACTORES"]
        Host["🟢 Primer Jugador"]
        Guest["🟡 Jugador Invitado"]
        Client["📱 Cliente Flutter"]
        Backend["🖥️ Backend Dart"]
        DB["💾 Base de Datos"]
    end
    
    subgraph UseCases["🎯 CASOS DE USO"]
        CreateRoom["Crear sala con alias"]
        NumPlayers["Elegir número de jugadores"]
        ReserveAlias["Reservar alias de sala"]
        JoinRoom["Unirse a sala existente"]
        ValidateAlias["Validar alias de jugador"]
        GenToken["Generar sessionToken"]
        Reconnect["Reconectar con sessionToken"]
        RejectAlias["Rechazar alias ocupado"]
        SendAction["Enviar acción con requestId"]
        AcceptAction["Aceptar acción"]
        RejectAction["Rechazar acción"]
        EmitSnapshot["Emitir snapshot"]
        QueryLeaderboard["Consultar leaderboard"]
        RegisterResult["Registrar resultado final"]
    end
    
    Host --> CreateRoom
    Host --> NumPlayers
    Guest --> JoinRoom
    
    CreateRoom -.->|includes| ReserveAlias
    CreateRoom -.->|includes| GenToken
    
    JoinRoom -.->|includes| ValidateAlias
    JoinRoom -.->|includes| GenToken
    
    Reconnect -.->|includes| GenToken
    
    Client --> SendAction
    Client --> QueryLeaderboard
    
    SendAction -.->|includes| AcceptAction
    SendAction -.->|includes| RejectAction
    
    AcceptAction -.->|includes| EmitSnapshot
    
    Backend --> RejectAlias
    Backend --> RegisterResult
    
    EmitSnapshot --> DB
    RegisterResult --> DB
    QueryLeaderboard --> DB
    
    style Host fill:#a5d6a7
    style Guest fill:#fff59d
    style Client fill:#b3e5fc
    style Backend fill:#f8bbd0
    style DB fill:#ffccbc
    style CreateRoom fill:#c8e6c9
    style JoinRoom fill:#c8e6c9
    style SendAction fill:#bbdefb
```

**Nota:** "El alias identifica al jugador visualmente; la identidad de reconexión es el sessionToken"

---

## 8. Casos de Uso - Partida Local

```mermaid
graph TB
    subgraph Actors_Local["👥 ACTORES"]
        HumanPlayer["👤 Jugador Humano"]
        BotPlayer["🤖 Bot Local"]
        FlutterApp["📱 Aplicación Flutter"]
        GameEngine["🎮 Motor Juego"]
        Viewer3D["🌐 Visor 3D"]
    end
    
    subgraph Init["🚀 INICIALIZACIÓN"]
        StartGame["Iniciar partida local"]
        SelectPlayers["Seleccionar jugadores"]
        ConfigBots["Configurar bots"]
    end
    
    subgraph Actions["⚡ ACCIONES"]
        BuyPlot["Comprar parcela"]
        BuildBuilding["Construir edificio"]
        RotateBuilding["Rotar edificio"]
        ValidateConstruct["Validar construcción"]
        CollectIncome["Recaudar ingresos"]
    end
    
    subgraph Turn["🔄 TURNO"]
        AdvanceTurn["Avanzar turno"]
        BotTurn["Ejecutar turno bot"]
    end
    
    subgraph Era["📊 ERAS"]
        ScoreEra["Puntuar era"]
        ShowSummary["Mostrar resumen de era"]
    end
    
    subgraph End["🏁 FINAL"]
        CalcFinal["Calcular final de partida"]
        ShowRanking["Mostrar ranking final"]
    end
    
    subgraph Persistence["💾 PERSISTENCIA"]
        SaveGame["Guardar partida"]
        LoadGame["Cargar partida"]
        SyncBoard["Sincronizar tablero 3D"]
    end
    
    HumanPlayer --> StartGame
    StartGame --> SelectPlayers
    SelectPlayers --> ConfigBots
    
    HumanPlayer --> BuyPlot
    HumanPlayer --> BuildBuilding
    HumanPlayer --> CollectIncome
    
    BuildBuilding -.->|includes| RotateBuilding
    BuildBuilding -.->|includes| ValidateConstruct
    
    BuyPlot -.->|includes| SyncBoard
    
    BotPlayer --> BotTurn
    BotTurn -.->|includes| BuyPlot
    BotTurn -.->|includes| BuildBuilding
    BotTurn -.->|includes| CollectIncome
    
    BuyPlot --> AdvanceTurn
    CollectIncome --> AdvanceTurn
    BuildBuilding --> AdvanceTurn
    
    AdvanceTurn --> AdvanceTurn
    AdvanceTurn --> ScoreEra
    
    ScoreEra -.->|includes| ShowSummary
    
    ShowSummary --> CalcFinal
    CalcFinal -.->|includes| ShowRanking
    
    FlutterApp --> SaveGame
    FlutterApp --> LoadGame
    GameEngine --> SaveGame
    
    style StartGame fill:#a5d6a7
    style BuyPlot fill:#c8e6c9
    style BotTurn fill:#b3e5fc
    style AdvanceTurn fill:#fff9c4
    style ScoreEra fill:#ffe0b2
    style CalcFinal fill:#ffccbc
```

**Nota:** "Todas las acciones legales pasan por Juego; la UI no duplica reglas"

