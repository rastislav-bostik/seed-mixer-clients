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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No mixtures found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _MixtureCard(product: items[index]),
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
        onTap: () => context.go('/product/${product.source}/${product.slug}'),
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
                          Text(
                            product.categories.first,
                            style: Theme.of(context).textTheme.labelSmall,
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
    );
  }
}
