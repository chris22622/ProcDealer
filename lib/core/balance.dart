class Balance {
  static const double volCap = 0.35; // Max daily price volatility
  static const double heatDecay = 0.18; // Nightly heat decay
  static const double baseBustRate = 0.04; // Base bust chance
  static const int travelTime = 2; // Hours per travel
  static const int offerMin = 3;
  static const int offerMax = 6;
  static const int minDistricts = 3;
  static const int maxDistricts = 7;
  static const int launderingCap = 5000;
  static const int passiveIncome = 250;
  // Bank economics
  // Tiered daily compound interest (applied to bank principal at end of day)
  static const int bankTier1Limit = 1000; // <= 1k
  static const int bankTier2Limit = 10000; // <= 10k
  static const double bankTier1Rate = 0.004; // 0.4%/day
  static const double bankTier2Rate = 0.006; // 0.6%/day
  static const double bankTier3Rate = 0.008; // 0.8%/day
  // Fees
  static const double bankWithdrawFeeRate = 0.01; // 1%
  static const int bankWithdrawMinFee = 2; // minimum $2
  static const int bankLowBalanceThreshold = 500; // if below, charge daily maintenance
  static const int bankDailyMaintenanceFee = 2; // $2/day
  // Loans
  static const int creditScoreMin = 300;
  static const int creditScoreStart = 500;
  static const int creditScoreMax = 850;
  static const int creditScorePayoffBump = 25; // bump when a loan is fully repaid
  static const double loanDailyRateBad = 0.015; // ~1.5%/day
  static const double loanDailyRateMid = 0.010; // 1.0%/day
  static const double loanDailyRateGood = 0.006; // 0.6%/day
  static int maxLoanForScore(int score) {
    // Linear scale: 500 -> $2000; 850 -> $8000; 300 -> $500
    final s = score.clamp(creditScoreMin, creditScoreMax);
    final t = (s - 300) / (850 - 300); // 0..1
    return (500 + t * (8000 - 500)).round();
  }
  // Minimum daily loan payment policy (autopay at end of day)
  static const int loanMinPaymentBase = 25; // at least $25 per active loan per day
  static const double loanMinPaymentRate = 0.01; // or 1% of outstanding balance, whichever is higher
  // Law/Police
  static const int policeBribeCost = 200;
  static const double policeBribeFactor = 0.85; // 15% reduction to police risk
}
