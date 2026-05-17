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
      // Resize images during decode to roughly the rendered size. CDN images
      // can be 1000+ px wide; decoding them to that resolution and then
      // shrinking to a 100-px-wide thumbnail wastes CPU on every scroll-in
      // and balloons the in-memory cache. 200 px gives crisp display on
      // hi-dpi screens without burning decode time.
      memCacheWidth: width != null ? (width! * 2).toInt() : 240,
      // Avoid the brief flash to placeholder when the image arrives.
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
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
