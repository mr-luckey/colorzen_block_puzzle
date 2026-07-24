class IapConstants {
  static const String removeAdsProductId =
      'com.appwaretech.colorzen.puzzle.remove_ads';
}

class AppConstants {
  static const String appName = 'ColorZen';
  static const String tagline = 'Place. Clear. Zen.';
  static const String appLogoAsset = 'assets/images/app_logo.png';
  static const String packageId = 'com.appwaretech.colorzen.puzzle';
  static const int gridSize = 9;
  /// Pieces on the infinite horizontal conveyor belt.
  static const int beltSize = 18;
  static const int traySize = 3; // legacy
  static const double beltScrollSpeedPx = 44; // smoother on mid devices
  /// After every N belt pieces, one bomb piece appears.
  static const int bombEveryMin = 7;
  static const int bombEveryMax = 8;
  /// Timer starts only after the bomb piece is placed on the board.
  static const int bombDurationSec = 15;
  /// Conveyor bomb blast radius (Chebyshev) — e.g. 2 → up to 5×5 area.
  static const int bombAreaRadius = 2;
  /// Flat bonus when combo bomb wipes the whole board.
  static const int bombBoardClearBonus = 2500;
  /// Flat bonus when conveyor bomb blasts a local area.
  static const int bombAreaClearBonus = 600;
  static const int bombPerBlockBonus = 15;
  /// Daily challenge score multiplier (shared seeded puzzle).
  static const double dailyScoreMultiplier = 1.5;
  static const int interstitialCooldownMs = 180000;
  /// Menu / home interstitial cadence (paused during gameplay).
  static const int menuInterstitialEverySec = 20;
  static const int desiUnlockScore = 5000;
  static const int arcticUnlockScore = 10000;
  /// Previous free theme (Woodland) — now unlockable.
  static const int woodlandUnlockScore = 3000;
}
