import 'package:flutter/material.dart';

class PokemonImage extends StatelessWidget {
  final String? imagePath;
  final String? imagePathLarge;
  final double size;
  final bool useLarge;

  const PokemonImage({
    super.key,
    required this.imagePath,
    required this.imagePathLarge,
    required this.size,
    required this.useLarge,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) {
      // Show placeholder if no image path is provided
      return Image.asset(
        'assets/images/pokemon/placeholder_pokemon.png',
        width: size,
        height: size,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to icon if placeholder fails to load
          return Icon(
            Icons.image_outlined,
            size: (size * 0.5),
            color: Colors.grey.shade600,
          );
        },
      );
    }
    final imageDir = useLarge && imagePathLarge != null ? 'images_large' : 'images';
    final imageFileName = useLarge && imagePathLarge != null ? imagePathLarge! : imagePath!;
    final placeholderName = imageFileName.contains('_shiny') ? 'placeholder_pokemon_shiny.png' : 'placeholder_pokemon.png';
    return Image.asset(
      'assets/$imageDir/pokemon/$imageFileName',
      width: size,
      height: size,
      cacheWidth: (size * 2).toInt(),
      cacheHeight: (size * 2).toInt(),
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to placeholder if image fails to load
        return Image.asset(
          'assets/images/pokemon/$placeholderName',
          width: size,
          height: size,
          cacheWidth: (size * 2).toInt(),
          cacheHeight: (size * 2).toInt(),
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            // Final fallback to icon
            return Icon(
              Icons.image_outlined,
              size: (size * 0.5),
              color: Colors.grey.shade600,
            );
          },
        );
      },
    );
  }
}
