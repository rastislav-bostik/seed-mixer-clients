import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/mixture_detail_screen.dart';
import 'screens/mixtures_list_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      debugShowCheckedModeBanner: false,
    );
  }
}
