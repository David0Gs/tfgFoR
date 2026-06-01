// Modelo compartido para una entrada del ranking global.

/// Puntuacion registrada en el leaderboard.
class EntradaClasificacion {
  const EntradaClasificacion({required this.alias, required this.puntuacion});

  final String alias;
  final int puntuacion;

  /// Convierte la entrada a JSON para persistencia o protocolo.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'alias': alias, 'puntuacion': puntuacion};
  }

  /// Reconstruye una entrada de ranking desde JSON.
  factory EntradaClasificacion.fromJson(Map<String, dynamic> json) {
    return EntradaClasificacion(
      alias: (json['alias'] ?? '').toString(),
      puntuacion: json['puntuacion'] as int? ?? 0,
    );
  }
}
