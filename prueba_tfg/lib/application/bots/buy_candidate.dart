class BuyCandidate {
  const BuyCandidate({
    required this.marketIndex,
    required this.cost,
    required this.adjacentToOwnedLot,
  });

  final int marketIndex;
  final int cost;
  final bool adjacentToOwnedLot;

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
