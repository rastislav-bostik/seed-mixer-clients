import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product.dart';
import '../widgets/error_banner.dart';
import '../widgets/product_image.dart';
import 'mixtures_list_screen.dart' show repositoryProvider;

class _DetailKey {
  const _DetailKey(this.source, this.slug);
  final String source;
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DetailKey && other.source == source && other.slug == slug;

  @override
  int get hashCode => Object.hash(source, slug);
}

final _productProvider = FutureProvider.family<Product, _DetailKey>((ref, key) {
  return ref.watch(repositoryProvider).getProduct(key.source, key.slug);
});

class MixtureDetailScreen extends ConsumerWidget {
  const MixtureDetailScreen({super.key, required this.source, required this.slug});

  final String source;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _DetailKey(source, slug);
    final product = ref.watch(_productProvider(key));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Detail'),
      ),
      body: product.when(
        data: (p) => _DetailBody(product: p),
        error: (e, _) => Center(
          child: ErrorBanner(
            error: e,
            onRetry: () => ref.invalidate(_productProvider(key)),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (product.primaryImage != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ProductImage(url: product.primaryImage, height: 240, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(product.manufacturer, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (product.description != null) ...[
          Text(product.description!, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
        ],
        if (product.composition.isNotEmpty) ...[
          _SectionHeader(
            title: 'Composition',
            subtitle: product.compositionCoveragePercent < 99
                ? 'Coverage: ${product.compositionCoveragePercent.toStringAsFixed(0)} %'
                : null,
          ),
          ...product.composition.map((ing) => _CompositionRow(ingredient: ing)),
          const SizedBox(height: 24),
        ],
        if (product.offerings.isNotEmpty) ...[
          const _SectionHeader(title: 'Offerings'),
          ...product.offerings.map((o) => _OfferingRow(offering: o)),
          const SizedBox(height: 24),
        ],
        if (product.categories.isNotEmpty) ...[
          const _SectionHeader(title: 'Categories'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: product.categories.map((c) => Chip(label: Text(c))).toList(),
          ),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({required this.ingredient});

  final dynamic ingredient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '${ingredient.percentage.toStringAsFixed(0)} %',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient.displayName, style: Theme.of(context).textTheme.bodyMedium),
                if (ingredient.latinName != null)
                  Text(
                    ingredient.latinName!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingRow extends StatelessWidget {
  const _OfferingRow({required this.offering});

  final dynamic offering;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(offering.packLabel, style: Theme.of(context).textTheme.bodyMedium)),
          if (offering.priceCzk != null)
            Text(
              '${offering.priceCzk!.toStringAsFixed(0)} Kč',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          if (offering.inStock == false) ...[
            const SizedBox(width: 8),
            Icon(Icons.remove_circle_outline, size: 16, color: scheme.error),
          ],
        ],
      ),
    );
  }
}
