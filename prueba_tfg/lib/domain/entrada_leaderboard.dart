class EntradaClasificacion {
  const EntradaClasificacion({required this.alias, required this.puntuacion});

  final String alias;
  final int puntuacion;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'alias': alias, 'puntuacion': puntuacion};
  }

  factory EntradaClasificacion.fromJson(Map<String, dynamic> json) {
    return EntradaClasificacion(
      alias: (json['alias'] ?? '').toString(),
      puntuacion: json['puntuacion'] as int? ?? 0,
    );
  }
}
