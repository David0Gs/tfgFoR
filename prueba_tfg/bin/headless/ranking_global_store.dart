import 'package:prueba_tfg/domain/entrada_leaderboard.dart';

abstract interface class RankingGlobalStore {
  Future<bool> registrarPuntuacionMaxima({
    required String alias,
    required int puntuacion,
  });

  Future<List<EntradaClasificacion>> cargarTop10();

  Future<void> close();
}
