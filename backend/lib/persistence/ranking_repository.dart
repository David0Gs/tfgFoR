// Contrato de persistencia del ranking global. Las implementaciones SQLite y
// PostgreSQL cumplen esta interfaz.

import 'package:for_core/core.dart';

/// Repositorio de puntuaciones maximas por alias.
abstract interface class RankingRepository {
  /// Registra una puntuacion solo si mejora la puntuacion previa del alias.
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  });

  /// Carga las diez mejores puntuaciones.
  Future<List<EntradaClasificacion>> cargarTop10();

  /// Carga todo el ranking para sincronizaciones entre repositorios.
  Future<List<EntradaClasificacion>> cargarRankingCompleto();

  /// Libera recursos del repositorio.
  Future<void> close();
}
