import 'package:flutter/material.dart';
import '../../../data/models/pokemon.dart';
import 'type_chip.dart';

extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class ControlsSection extends StatefulWidget {
  final Pokemon pokemon;
  final bool showShiny;
  final VoidCallback onShinyToggled;
  final String? selectedAltImage;
  final Function(String?)? onAltImageSelected;

  const ControlsSection({
    super.key,
    required this.pokemon,
    required this.showShiny,
    required this.onShinyToggled,
    this.selectedAltImage,
    this.onAltImageSelected,
  });

  @override
  State<ControlsSection> createState() => _ControlsSectionState();
}

class _ControlsSectionState extends State<ControlsSection> {
  List<String> _altImages = [];
  bool _altImagesChecked = false;

  @override
  void initState() {
    super.initState();
    _findAltImages();
  }

  Future<void> _findAltImages() async {
    try {
      final altImageFileNames = widget.pokemon.altImagesLarge;

      if (altImageFileNames.isNotEmpty) {
        setState(() {
          _altImages = altImageFileNames;
          _altImagesChecked = true;
        });
      } else {
        setState(() {
          _altImagesChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _altImagesChecked = true;
        });
      }
    }
  }

  String _extractDescription(String fileName) {
    // Extract description from filename like "pokemon_name_alt_description.png"
    final withoutExt = fileName.replaceAll('.png', '');
    final parts = withoutExt.split('_alt_');
    if (parts.length > 1) {
      return parts[1].replaceAll('_', ' ').toTitleCase();
    }
    return fileName;
  }

  void _showAltImagesModal() {
    showDialog(
      context: context,
      builder: (context) {
        // Calculate modal height based on number of images (including normal)
        final screenHeight = MediaQuery.of(context).size.height;
        final numImagesTotal = _altImages.length + 1; // +1 for normal image
        final numRows = (numImagesTotal / 2).ceil();
        // Each row is approximately 160 pixels (image + spacing + text)
        final contentHeight = (numRows * 160) + 80; // 80 for header and footer
        final modalHeight =
            contentHeight.clamp(300, screenHeight * 0.8).toDouble();

        // Create list of images including normal
        final allImages = [null, ..._altImages]; // null represents normal image

        return Dialog(
          child: SizedBox(
            height: modalHeight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    'Select Image',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                      ),
                      itemCount: allImages.length,
                      itemBuilder: (context, index) {
                        final fileName = allImages[index];
                        final isNormal = fileName == null;
                        final imageToLoad = _buildImagePath(fileName);
                        final description =
                            isNormal ? 'Normal' : _extractDescription(fileName);
                        final isSelected = widget.selectedAltImage == fileName;

                        return GestureDetector(
                          onTap: () {
                            widget.onAltImageSelected?.call(fileName);
                            Navigator.pop(context);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.2),
                                      width: isSelected ? 3 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Image.asset(
                                    imageToLoad,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.image_outlined);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildImagePath(String? fileName) {
    if (fileName == null) {
      // Normal image
      if (widget.showShiny && widget.pokemon.imageShinyPathLarge != null) {
        return 'assets/images_large/pokemon/${widget.pokemon.imageShinyPathLarge}';
      }
      return 'assets/images_large/pokemon/${widget.pokemon.imagePathLarge}';
    }
    // Alt image
    if (widget.showShiny) {
      final withoutExt = fileName.replaceAll('.png', '');
      return 'assets/images_large/pokemon/${withoutExt}_shiny.png';
    }
    return 'assets/images_large/pokemon/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAltImages = _altImagesChecked && _altImages.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: IconButton.outlined(
                    isSelected: widget.showShiny,
                    onPressed: widget.onShinyToggled,
                    icon: const Icon(Icons.star_border),
                    selectedIcon: const Icon(Icons.star),
                    style: IconButton.styleFrom(
                      foregroundColor: widget.showShiny
                          ? theme.colorScheme.primary
                          : theme.colorScheme.primary.withValues(alpha: 0.7),
                      side: BorderSide(
                        color: widget.showShiny
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                      ),
                      backgroundColor: widget.showShiny
                          ? theme.colorScheme.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: hasAltImages ? _showAltImagesModal : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hasAltImages
                          ? theme.colorScheme.primary.withValues(alpha: 0.7)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      side: BorderSide(
                        color: hasAltImages
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    child: const Icon(Icons.image),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: TypeChip(type: widget.pokemon.types[0]),
                ),
              ),
              if (widget.pokemon.types.length > 1) ...[
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: TypeChip(type: widget.pokemon.types[1]),
                  ),
                ),
              ] else ...[
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
