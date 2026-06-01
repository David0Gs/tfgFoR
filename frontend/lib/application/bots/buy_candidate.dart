// Candidato de compra evaluado por el bot. Prioriza coste bajo y cercania a
// solares ya comprados.

/// Posible parcela del mercado que el bot podria comprar.
class BuyCandidate {
  const BuyCandidate({
    required this.marketIndex,
    required this.cost,
    required this.adjacentToOwnedLot,
  });

  final int marketIndex;
  final int cost;
  final bool adjacentToOwnedLot;

  /// Compara candidatos para elegir la compra mas conveniente.
  int compareTo(BuyCandidate other) {
    final int byCost = other.cost.compareTo(cost);
    if (byCost != 0) {
      return byCost;
    }

    if (adjacentToOwnedLot != other.adjacentToOwnedLot) {
      return adjacentToOwnedLot ? 1 : -1;
    }

    return other.marketIndex.compareTo(marketIndex);
  }
}
