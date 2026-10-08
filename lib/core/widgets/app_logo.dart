import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// UbuntuID's brand lockup: the coat of arms with the "UbuntuID" wordmark
/// centred underneath. Every screen references it from here, so swapping the
/// branding later is a one-file change.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36, this.showWordmark = true, this.onDark = false});

  /// Height of the wordmark's line box; the coat of arms scales with it.
  final double size;

  /// False shows just the coat of arms, at [size] tall (e.g. the app bar).
  final bool showWordmark;
  final bool onDark;

  static const _coatOfArmsAsset = 'assets/branding/coat_of_arms.svg';

  @override
  Widget build(BuildContext context) {
    if (!showWordmark) {
      return SvgPicture.asset(_coatOfArmsAsset, height: size, semanticsLabel: 'Coat of arms of South Africa');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(_coatOfArmsAsset, height: size * 1.7, semanticsLabel: 'Coat of arms of South Africa'),
        SizedBox(height: size * 0.28),
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
