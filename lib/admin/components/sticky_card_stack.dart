import 'dart:math';
import 'package:flutter/material.dart';

class StickyCardsBackground extends StatefulWidget {
  final ScrollController controller;
  final List<Widget> children;
  final double cardStackOffset;
  final double collapsedHeight; // Default spacing if customSpacers is null
  final double topPadding;
  final List<double>? customSpacers; // Values to add to previous top.

  const StickyCardsBackground({
    super.key,
    required this.controller,
    required this.children,
    this.cardStackOffset = 15.0,
    this.collapsedHeight = 280.0,
    this.topPadding = 150.0,
    this.customSpacers,
  });

  @override
  State<StickyCardsBackground> createState() => _StickyCardsBackgroundState();
}

class _StickyCardsBackgroundState extends State<StickyCardsBackground> {
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = widget.controller.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial positions based on spacers
    List<double> initialTops = [];
    double currentPos = widget.topPadding;
    initialTops.add(currentPos); // First item at topPadding

    for (int i = 0; i < widget.children.length - 1; i++) {
        double spacer = widget.collapsedHeight;
        if (widget.customSpacers != null && i < widget.customSpacers!.length) {
            spacer = widget.customSpacers![i];
        }
        currentPos += spacer;
        initialTops.add(currentPos);
    }

    return Stack(
      children: List.generate(widget.children.length, (index) {
        final double stackedTop = widget.topPadding + (index * widget.cardStackOffset);
        final double initialTop = initialTops[index];
        
        double currentTop = initialTop - _scrollOffset;
        currentTop = max(stackedTop, currentTop);

        // Opacity/Scale Logic
        double scale = 1.0;
        if (index < widget.children.length - 1) {
           final double nextStackedTop = widget.topPadding + ((index + 1) * widget.cardStackOffset);
           final double nextInitialTop = initialTops[index + 1];
           final double nextCurrentTop = max(nextStackedTop, nextInitialTop - _scrollOffset);
           
           // Distance remaining for next card to dock
           // Effective range for this card's scaling is the distance the NEXT card travels.
           final double maxDist = nextInitialTop - nextStackedTop;
           // Wait, maxDist isn't constant per se if spacers vary, but logic holds.
           // However, to be consistent with previous logic:
           // progress = (currentDist) / collapsedHeight
           
           // Correct logic:
           // How far is the next card from its stacked position?
           final double dist = nextCurrentTop - nextStackedTop;
           
           // Determine the "travel distance" that correlates to the scale effect.
           // Previously it was `collapsedHeight`.
           // Now it should probably vary or stay uniform?
           // If we use the spacer distance, scale changes might speed up/slow down.
           // Let's use the actual spacer distance for that gap.
           double spacer = widget.collapsedHeight;
            if (widget.customSpacers != null && index < widget.customSpacers!.length) {
                spacer = widget.customSpacers![index];
            }
           
           final double progress = (dist / spacer).clamp(0.0, 1.0);
           
           scale = 0.9 + (0.1 * progress);
        }

        return Positioned(
          top: currentTop,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: widget.children[index],
          ),
        );
      }),
    );
  }
}
