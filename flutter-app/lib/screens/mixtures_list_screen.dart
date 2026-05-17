import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../api/seed_mixer_repository.dart';
import '../models/product.dart';
import '../widgets/error_banner.dart';
import '../widgets/product_image.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return client;
});

final repositoryProvider = Provider<SeedMixerRepository>((ref) {
  return SeedMixerRepository(ref.watch(apiClientProvider));
});

final mixturesProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(repositoryProvider).listProducts(type: 'mixture');
});

class MixturesListScreen extends ConsumerWidget {
  const MixturesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixtures = ref.watch(mixturesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed Mixer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(mixturesProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: mixtures.when(
        data: (items) => _MixtureList(items: items),
        error: (e, _) => Center(
          child: ErrorBanner(
            error: e,
            onRetry: () => ref.invalidate(mixturesProvider),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _MixtureList extends StatelessWidget {
  const _MixtureList({required this.items});

  final List<Product> items;

  // Card body 110 + bottom padding 8 = the per-item slot. itemExtent skips
  // intrinsic measurement entirely — Flutter just does offset math, which
  // is the single biggest scroll-perf lever for a long list of fixed-size
  // cards.
  static const double _itemExtent = 118;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No mixtures found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: items.length,
      itemExtent: _itemExtent,
      // ClampingScrollPhysics suppresses Android 12+ stretch-overscroll
      // (where the whole list visibly elongates when dragged past either
      // end). Bouncing physics would be the iOS-style alternative; we go
      // with clamping because it makes the cards feel more like a catalog
      // than a flexible canvas.
      physics: const ClampingScrollPhysics(),
      // Prefetch ~2 screens of off-screen items so fast flings don't show
      // empty card slots while content is being built.
      cacheExtent: _itemExtent * 8,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _MixtureCard(product: items[index]),
      ),
    );
  }
}

class _MixtureCard extends StatelessWidget {
  const _MixtureCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // push (not go): keeps the list screen alive on the navigation stack
        // so scroll position is preserved when the user returns via the
        // back arrow.
        onTap: () => context.push('/product/${product.source}/${product.slug}'),
        // Fixed card height — gives the inner Column a definite vertical
        // bound, which Spacer/Expanded need to flex against. Without this
        // the Row's stretch + Column's flex create a circular constraint
        // that quietly collapses to zero on Flutter web's canvas renderer.
        child: SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 100,
                child: ProductImage(url: product.primaryImage),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.manufacturer.isNotEmpty ? product.manufacturer : '—',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (product.lowestPriceCzk != null)
                            Text(
                              'od ${product.lowestPriceCzk!.toStringAsFixed(0)} Kč',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          const Spacer(),
                          if (product.categories.isNotEmpty)
                            Flexible(
                              child: Text(
                                product.categories.first,
                                style: Theme.of(context).textTheme.labelSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
