import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// UbuntuID's placeholder brand mark: an original identity-card motif in the
/// UbuntuID green/gold palette. This is not the National Coat of Arms or any
/// government department's logo. Swap this widget out for a final brand
/// asset when one is commissioned -- every screen references it from here.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36, this.showWordmark = true, this.onDark = false});

  final double size;
  final bool showWordmark;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.greenDark],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.gold, width: size * 0.06),
      ),
      child: Center(
        child: Icon(Icons.badge_outlined, color: Colors.white, size: size * 0.56),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Text(
          'UbuntuID',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: onDark || Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}
