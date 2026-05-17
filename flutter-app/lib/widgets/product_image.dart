import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.url,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? height;
  final double? width;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _Placeholder(height: height, width: width);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: width,
      fit: fit,
      placeholder: (_, _) => _Placeholder(height: height, width: width),
      errorWidget: (_, _, _) => _Placeholder(height: height, width: width, isError: true),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.height, this.width, this.isError = false});

  final double? height;
  final double? width;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          isError ? Icons.broken_image_outlined : Icons.local_florist_outlined,
          color: Theme.of(context).colorScheme.outline,
          size: 32,
        ),
      ),
    );
  }
}
