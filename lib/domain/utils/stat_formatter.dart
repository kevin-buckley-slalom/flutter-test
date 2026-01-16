class StatFormatter {
  static String formatStatName(String stat) {
    switch (stat.toLowerCase()) {
      case 'hp':
        return 'HP';
      case 'attack':
        return 'ATK';
      case 'defense':
        return 'DEF';
      case 'sp_atk':
      case 'spatk':
        return 'SPA';
      case 'sp_def':
      case 'spdef':
        return 'SPD';
      case 'speed':
        return 'SPE';
      default:
        return stat;
    }
  }

  static int getMaxStatValue() {
    return 255; // Maximum stat value in Pokemon
  }
}




