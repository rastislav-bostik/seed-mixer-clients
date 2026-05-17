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

    // On the web target: force Image.network to render via a real HTML <img>
    // element (HtmlElementView under the hood). Default CanvasKit path fetches
    // bytes via XHR to draw them into the WebGL canvas — and XHR enforces
    // CORS, which Planta Naturalis' CDN fails (no Access-Control-Allow-Origin
    // header). A plain <img> tag only enforces CORS for canvas read-back, not
    // for on-screen display, so it sidesteps the missing header entirely.
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
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        // 180ms ease-out cross-fade when the image finishes decoding —
        // softer than the default hard-cut from placeholder → image. The
        // wasSynchronouslyLoaded short-circuit means cached <img>s appear
        // instantly (no animation flash on revisit). Cost: one extra
        // opacity layer per fading image, dropped after the animation ends.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: child,
          );
        },
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
      // Resize images during decode. CDN images can be 1000+ px wide;
      // decoding them to that resolution and then shrinking to a 100-px-wide
      // thumbnail wastes CPU on every scroll-in and balloons the in-memory
      // cache. 2× the rendered logical width gives crisp display on hi-dpi
      // screens without burning decode time.
      //
      // When the caller passes only `height` (hero/detail image, e.g. the
      // detail screen passes height: 240 with the image stretching full
      // viewport width), we don't know the rendered width — so we fall back
      // to 1080 px, which covers most phone viewports at full DPR. Using
      // the previous 240 px fallback decoded the hero into a thumbnail-sized
      // bitmap that visibly blurred when stretched to ~688 px viewport.
      memCacheWidth: width != null ? (width! * 2).toInt() : 1080,
      // 180ms ease-in cross-fade once the bitmap is decoded — gentle
      // transition from the placeholder flower icon to the loaded image,
      // softer than the previous hard cut. Cached bitmaps decode in one
      // frame so the fade is effectively skipped on re-display.
      //
      // fadeOutDuration stays zero so the placeholder doesn't cross-fade
      // with the incoming image — otherwise we'd get a brief "ghost"
      // double-image during the overlap window.
      fadeInDuration: const Duration(milliseconds: 180),
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
