import 'package:flutter/material.dart';

/// Fades and slides [child] in, delayed by `index * delayPerItem` -- wrap
/// each item of a `ListView.builder`/`.separated` in this to get a
/// staggered entrance instead of the whole list just appearing at once.
class StaggeredFadeIn extends StatefulWidget {
  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.delayPerItem = const Duration(milliseconds: 35),
    this.maxDelay = const Duration(milliseconds: 350),
  });

  final int index;
  final Widget child;
  final Duration delayPerItem;
  final Duration maxDelay;

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.delayPerItem * widget.index;
    Future.delayed(delay > widget.maxDelay ? widget.maxDelay : delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
