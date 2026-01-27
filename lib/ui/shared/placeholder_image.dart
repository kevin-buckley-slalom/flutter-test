import 'package:flutter/material.dart';

class PlaceholderImage extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;

  const PlaceholderImage({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.image_outlined,
        size: (width != null && height != null)
            ? (width! < height! ? width! * 0.5 : height! * 0.5)
            : 48,
        color: Colors.grey.shade600,
      ),
    );
  }
}





