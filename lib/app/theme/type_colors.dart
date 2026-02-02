import 'package:flutter/material.dart';

class TypeColors {
  static const Map<String, Color> colors = {
    'Normal': Color(0xFFA8A878),
    'Fire': Color(0xFFF08030),
    'Water': Color(0xFF6890F0),
    'Electric': Color(0xFFF8D030),
    'Grass': Color(0xFF78C850),
    'Ice': Color(0xFF98D8D8),
    'Fighting': Color(0xFFC03028),
    'Poison': Color(0xFFA040A0),
    'Ground': Color(0xFFE0C068),
    'Flying': Color(0xFFA890F0),
    'Psychic': Color(0xFFF85888),
    'Bug': Color(0xFFA8B820),
    'Rock': Color(0xFFB8A038),
    'Ghost': Color(0xFF705898),
    'Dragon': Color(0xFF7038F8),
    'Dark': Color(0xFF705848),
    'Steel': Color(0xFFB8B8D0),
    'Fairy': Color(0xFFEE99AC),
  };

  static Color getColor(String type, {double alphaValue = 1.0}) {
    if (colors[type] == null) {
      return Colors.grey;
    }
    Color color = colors[type]!;
    return Color.from(
        alpha: alphaValue, red: color.r, green: color.g, blue: color.b);
    // return colors[type] ?? Colors.grey;
  }

  static Color getTextColor(String type) {
    final color = getColor(type);
    // Determine if text should be white or black based on luminance
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}
