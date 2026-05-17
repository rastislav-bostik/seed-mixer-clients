import 'package:flutter/material.dart';

/// App-wide scroll behavior with the platform overscroll indicators disabled.
///
/// Why this exists: on Android 12+, Material 3 wraps every scrollable in a
/// `StretchingOverscrollIndicator` which **visibly elongates the entire list
/// content** when the user drags past either edge. Setting
/// `physics: ClampingScrollPhysics()` only stops the scroll math at the edge
/// — the overscroll indicator is a separate painter that runs regardless,
/// and is responsible for the rubber-band-stretching the user sees.
///
/// `MaterialScrollBehavior.buildOverscrollIndicator` returns a child wrapped
/// in either `StretchingOverscrollIndicator` (Android) or
/// `GlowingOverscrollIndicator` (older). We return the child unmodified —
/// no glow, no stretch. Clean hard stop at the edges, matching what feels
/// right for a catalog browser.
class NoOverscrollScrollBehavior extends MaterialScrollBehavior {
  const NoOverscrollScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
