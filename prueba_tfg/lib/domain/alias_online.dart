class AliasOnline {
  static const int longitud = 3;

  static final RegExp _patronPermitido = RegExp(r'^[A-Z0-9]{3}$');

  static String normalizar(String rawAlias) {
    return rawAlias.trim().toUpperCase();
  }

  static bool esValido(String rawAlias) {
    return mensajeError(rawAlias) == null;
  }

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
