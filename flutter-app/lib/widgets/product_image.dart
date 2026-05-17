import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

    // On the web target, fall back to plain Image.network which renders via
    // an HTML <img> element. <img> doesn't enforce CORS for display (only
    // for canvas read-back), so it sidesteps the missing
    // Access-Control-Allow-Origin header on several seed-shop image CDNs
    // (Planta Naturalis being the main offender). Browser HTTP cache still
    // caches these — we just lose Dart-side cache control.
    //
    // Mobile/desktop native targets use CachedNetworkImage as before: full
    // app-level cache with memCacheWidth resizing, fadeless swaps, custom
    // placeholder/error widgets.
    if (kIsWeb) {
      return Image.network(
        url!,
        height: height,
        width: width,
        fit: fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _Placeholder(height: height, width: width),
        errorBuilder: (_, _, _) => _Placeholder(height: height, width: width, isError: true),
      );
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
