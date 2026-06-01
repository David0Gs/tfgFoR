// Utilidades de validacion del alias online. Centraliza las reglas para que
// cliente y servidor acepten exactamente el mismo formato.

/// Valida y normaliza el alias corto usado en partidas remotas.
class AliasOnline {
  /// Longitud exacta requerida para los alias online.
  static const int longitud = 3;

  static final RegExp _patronPermitido = RegExp(r'^[A-Z0-9]{3}$');

  /// Normaliza un alias eliminando espacios y pasandolo a mayusculas.
  static String normalizar(String rawAlias) {
    return rawAlias.trim().toUpperCase();
  }

  /// Indica si un alias es valido segun las reglas compartidas.
  static bool esValido(String rawAlias) {
    return mensajeError(rawAlias) == null;
  }

  /// Devuelve un mensaje de error si el alias no es valido.
  static String? mensajeError(
    String rawAlias, {
    Iterable<String> aliasesOcupados = const <String>[],
  }) {
    final String alias = normalizar(rawAlias);

    if (alias.length != longitud) {
      return 'El alias online debe tener exactamente 3 caracteres.';
    }

    if (!_patronPermitido.hasMatch(alias)) {
      return 'El alias online solo admite letras y numeros.';
    }

    final bool aliasDuplicado = aliasesOcupados
        .map(normalizar)
        .any((String ocupado) => ocupado == alias);
    if (aliasDuplicado) {
      return 'El alias $alias ya esta ocupado en esta partida.';
    }

    return null;
  }
}
