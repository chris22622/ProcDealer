class Law {
  // Returns tier 0..3 based on heat (0..1)
  static int tier(double heat) {
    if (heat < 0.25) return 0;
    if (heat < 0.5) return 1;
    if (heat < 0.75) return 2;
    return 3;
  }

  // Bust probability influenced by heat tier; upgrades like scanner/safehouse can reduce chance if applied later
  static double bustChance(double heat) {
    final t = tier(heat);
    switch (t) {
      case 0:
        return 0.01;
      case 1:
        return 0.05;
      case 2:
        return 0.12;
      default:
        return 0.25;
    }
  }

  // Police patrol risk multiplier based on overall heat and district police presence (0..1)
  // Returns a multiplier ~ [0.9 .. 1.6]
  static double policeRiskMod(double heat, double policePresence) {
    final h = heat.clamp(0.0, 1.0);
    final p = policePresence.clamp(0.0, 1.0);
    // Effective patrol pressure grows with both heat and local police presence
    final pressure = (0.4 * p + 0.6 * (p * h)).clamp(0.0, 1.0);
    return 0.9 + 0.7 * pressure; // at max pressure, +70% risk; at min, -10%
  }
}
