import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/mixture_detail_screen.dart';
import 'screens/mixtures_list_screen.dart';
import 'theme/app_theme.dart';
import 'theme/scroll_behavior.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap the image cache aggressively. Defaults (100 MB / 1000 entries) let
  // the heap balloon as the user scrolls through a long list, which on a
  // QEMU emulator (and on real low-memory phones) triggers full GC pauses
  // that visibly freeze input. 50 MB / 60 entries fits roughly three
  // screens' worth of thumbnails — enough to scroll smoothly, small enough
  // that GC stays incremental.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 60;

  final tokens = await AppTokens.load();
  runApp(
    ProviderScope(child: SeedMixerApp(tokens: tokens)),
  );
}

class SeedMixerApp extends StatelessWidget {
  const SeedMixerApp({super.key, required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const MixturesListScreen(),
        ),
        GoRoute(
          path: '/product/:source/:slug',
          builder: (_, state) => MixtureDetailScreen(
            source: state.pathParameters['source']!,
            slug: state.pathParameters['slug']!,
          ),
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Seed Mixer',
      theme: buildTheme(tokens),
      routerConfig: router,
      // App-wide: no Android stretch overscroll, no iOS-style glow. The list
      // and detail screens already pin ClampingScrollPhysics; this kills the
      // visual indicator that runs on top of the scroll math.
      scrollBehavior: const NoOverscrollScrollBehavior(),
      // Diagnostic: shows two stacked bar graphs at the top of every frame
      // (UI thread on top, Raster thread on bottom). Each bar = one frame's
      // duration; the horizontal line is the 16 ms budget for 60 fps. Bars
      // above the line are dropped frames. Visible in debug + profile
      // builds, suppressed in release — so end users never see it but
      // we still get the overlay while running `flutter build apk --profile`
      // for on-device perf QA.
      showPerformanceOverlay: !kReleaseMode,
      debugShowCheckedModeBanner: false,
    );
  }
}
