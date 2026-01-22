import 'package:flutter/material.dart';

/// A parallax scrolling container for layered depth effects.
/// 
/// This widget creates parallax scrolling effects with:
/// - A background hero image layer
/// - Multiple content layers with different scroll speeds
/// - Smooth transitions between layers
/// - Context-aware depth perception
class ParallaxScrollContainer extends StatefulWidget {
  final Widget backgroundChild;
  final double backgroundHeight;
  final Widget contentChild;
  final Color? contentBackgroundColor;
  final BorderRadius? contentBorderRadius;
  final double parallaxRatio;
  final double contentOffsetTop;

  const ParallaxScrollContainer({
    super.key,
    required this.backgroundChild,
    this.backgroundHeight = 300,
    required this.contentChild,
    this.contentBackgroundColor,
    this.contentBorderRadius,
    this.parallaxRatio = 0.2,
    this.contentOffsetTop = 0,
  });

  @override
  State<ParallaxScrollContainer> createState() =>
      _ParallaxScrollContainerState();
}

class _ParallaxScrollContainerState extends State<ParallaxScrollContainer> {
  late ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Calculate extra height needed for parallax offset
    // This prevents white space from appearing at the top when scrolling
    final maxParallaxOffset = widget.backgroundHeight * widget.parallaxRatio;
    final extendedBackgroundHeight = widget.backgroundHeight + maxParallaxOffset;

    return Stack(
      children: [
        // Background layer with parallax effect
        Transform.translate(
          offset: Offset(0, -maxParallaxOffset + (_scrollOffset * widget.parallaxRatio)),
          child: Container(
            height: extendedBackgroundHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: widget.backgroundChild,
          ),
        ),

        // Content layer on top with smooth scrolling
        SingleChildScrollView(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Spacer to allow background to show initially, minus the overlap offset
              SizedBox(height: widget.backgroundHeight - widget.contentOffsetTop),

              // Main content card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: widget.contentBackgroundColor ??
                      theme.colorScheme.surface,
                  borderRadius: widget.contentBorderRadius ??
                      const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                ),
                child: widget.contentChild,
              ),
              // Bottom padding to prevent over-scrolling
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ],
    );
  }
}
