# Implementation Notes

Long-form companion to [`flutter-app/README.md`](../README.md). The README is "what is this and how do I run it"; this doc is "why is the code shaped the way it is" — the bottlenecks we hit, the trade-offs we made, the gotchas baked into the file headers.

If you're modifying any of the files in this doc's table of contents, **read the relevant section first**. Every section explains an intentional design decision; revert it casually and the symptom returns.

## Contents

1. [Scroll performance — the 9 knobs](#scroll-performance--the-9-knobs)
2. [Web target — CORS, HtmlElementView, flicker](#web-target--cors-htmlelementview-flicker)
3. [Image cache — `memCacheWidth` strategy](#image-cache--memcachewidth-strategy)
4. [Diagnostic tooling](#diagnostic-tooling)
5. [Testing on real devices — Mi Account gate workaround](#testing-on-real-devices--mi-account-gate-workaround)
6. [Build commands cheat sheet](#build-commands-cheat-sheet)
7. [Known limitations + future work](#known-limitations--future-work)

---

## Scroll performance — the 9 knobs

The mixtures list (~50 cards, network thumbnails, Material 3 InkWell ripple) reached buttery-smooth 60 fps scroll on a Redmi Note 14 Pro profile build by combining **nine independent knobs**. Each one targets a different bottleneck. Removing any one of them brings back a distinct, observable jank.

| # | Knob | Where | Solves |
|---|---|---|---|
| 1 | `ListView.builder(itemExtent: 118)` | `lib/screens/mixtures_list_screen.dart` | Layout cost (skips intrinsic measurement) |
| 2 | `cacheExtent: _itemExtent * 10` | same | Off-screen widget churn, web flicker |
| 3 | `physics: ClampingScrollPhysics()` | list + detail screens | Android 12+ stretch overscroll math |
| 4 | `NoOverscrollScrollBehavior()` | `lib/theme/scroll_behavior.dart` + `main.dart` | Visual stretch indicator (separate layer from physics) |
| 5 | `RepaintBoundary` per card | `mixtures_list_screen.dart` `itemBuilder` | Whole-viewport repaint cost |
| 6 | `Material` + `InkWell` (NOT `GestureDetector`) | `_MixtureCard` | Gesture arena conflicts swallowing scrolls |
| 7 | `CachedNetworkImage` with `memCacheWidth` | `lib/widgets/product_image.dart` | Image decode cost during scroll-in |
| 8 | `gaplessPlayback: true` + zero `fadeIn/Out` | same | Flash-to-placeholder when image arrives |
| 9 | `imageCache.maximumSizeBytes = 50 MB` cap | `main.dart` | GC pause from runaway image cache |

### Knob detail

**#1 `itemExtent`** — single biggest scroll-perf lever for long fixed-height lists. Tells Flutter "every item is exactly 118 px tall", so scroll math collapses to pure offset arithmetic. No intrinsic measurement, no layout pass per item. Card body 110 + bottom padding 8 = 118.

**#2 `cacheExtent`** — Flutter renders+keeps alive widgets in a buffer of ±N pixels around the viewport. Default is 250 px. We bumped to `_itemExtent * 10` (~1180 px = ~10 cards each side) for two reasons:
- On web, each card's image is a real DOM `<img>` element (see §2). When the widget disposes, the `<img>` unmounts; on scroll-back a fresh `<img>` mounts and shows a brief paint gap → visible flicker. Bigger buffer = fewer dispose/recreate cycles for typical up/down scrubbing.
- On native, the cost is negligible since `PaintingBinding.imageCache` smooths out the bitmap re-decoding anyway. Applied universally for consistency.

**#3 ClampingScrollPhysics** — the *scroll math* layer. Without it, Android 12+ stretch overscroll lets the list elongate when dragged past either end.

**#4 NoOverscrollScrollBehavior** — the *visual indicator* layer. Distinct from physics! Even with `ClampingScrollPhysics`, Flutter still paints the `StretchingOverscrollIndicator` on top by default. Overriding `MaterialScrollBehavior.buildOverscrollIndicator` to return the child unchanged kills the visual stretch. User feedback "listing se stále natahuje" was specifically caused by us setting physics but forgetting the indicator.

**#5 RepaintBoundary** — per-card paint layer that the GPU caches as a texture. Without it, Flutter repaints the whole visible ListView slice every scroll tick — at 60 fps with 7 visible Material 3 + InkWell cards, that's exactly where the "chewing" comes from.

**#6 Material + Ink + InkWell, NOT raw GestureDetector** — we initially tried a `GestureDetector` to skip the ripple cost. Outcome: worse, because `TapGestureRecognizer` holds the touch for ~100 ms in the gesture arena before yielding to `VerticalDragGestureRecognizer`. Fast short swipes that should have been scrolls got swallowed as taps that then went nowhere. Material's `InkWell` plays better with `ListView`'s scroll machinery — the splash is worth that responsiveness.

**#7 `memCacheWidth`** — see §3 below for the full story. The 2× rendered width rule keeps decode cost proportional to visible pixels.

**#8 Zero fade durations + `gaplessPlayback`** — by default, `CachedNetworkImage` cross-fades from placeholder to loaded image over 500 ms. This adds a perceived "blinking" effect during scroll-in that reads as jank. Zero duration + gapless = the image appears the frame the bitmap is ready.

**#9 Image cache cap** — `PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024` and `maximumSize = 60`. Defaults are 100 MB / 1000 entries. On memory-constrained devices that triggers full GC pauses (we measured 1453 ms once in `PerformanceOverlay`) that visibly freeze input. 50 MB / 60 entries fits roughly three screens' worth of thumbnails — enough to scroll smoothly, small enough that GC stays incremental.

### Diagnostic that proved emulator ≠ Flutter

Before all of the above, we thought the app was broken. PerformanceOverlay showed ~30 ms average UI thread on Android emulator and `NotificationListener<ScrollNotification>` (the `_ScrollLogger` in the list screen) revealed the smoking gun:

```
[ScrollLog] ScrollStartNotification pixels=670.1 / 23055
[ScrollLog] UserScrollNotification  pixels=670.1 / 23055
[ScrollLog] ScrollEndNotification   pixels=670.1 / 23055   ← stuck!
[ScrollLog] ScrollStartNotification pixels=670.1 / 23055
[ScrollLog] ScrollEndNotification   pixels=670.1 / 23055
... repeat dozens of times, pixels never moves
```

Pattern: hundreds of Start → End pairs with NO Update in between. **QEMU pointer emulation collapses fast trackpad gestures to touchdown + touchup with no intermediate motion events.** On a real Redmi the same gestures produced 50+ `ScrollUpdateNotification` events per swipe, smooth pixel progression, app totally responsive.

If you see flat-lined `pixels=` values in `_ScrollLogger`, the emulator is lying to you. Switch to real hardware before tuning anything.

---

## Web target — CORS, HtmlElementView, flicker

Flutter web uses the **CanvasKit renderer** by default (the HTML renderer was deprecated in 3.27 and removed in 3.29 — `--web-renderer html` no longer exists).

CanvasKit's image pipeline fetches bytes via **XHR** and decodes them into a WebGL canvas. XHR enforces CORS. Several upstream image CDNs (Planta Naturalis being the prime example) respond `200 OK` but **without** an `Access-Control-Allow-Origin` header — so the fetch fails and every product card renders the broken-image icon on web.

### Render-path comparison

```
                     ┌─── CanvasKit (default)
                     │      Image.network()
                     │      ↓
Flutter web ─────────┤      XHR fetch bytes → canvas decode → WebGL paint
                     │      CORS enforced ✗ (fails on Planta CDN)
                     │
                     └─── HtmlElementView (with webHtmlElementStrategy)
                            Image.network(webHtmlElementStrategy: prefer)
                            ↓
                            HtmlElementView mounting a real <img> DOM element
                            CORS only enforced for canvas read-back — display works ✓
```

### Workaround

`Image.network(webHtmlElementStrategy: WebHtmlElementStrategy.prefer)` forces Flutter web to render via a real DOM `<img>` element wrapped in `HtmlElementView`. The `<img>` tag only enforces CORS for canvas read-back (e.g. `<canvas>.drawImage` + `getImageData`), not for on-screen display. Available since Flutter 3.27. Implemented in [`lib/widgets/product_image.dart`](../lib/widgets/product_image.dart):

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

if (kIsWeb) {
  return Image.network(
    url!,
    height: height, width: width, fit: fit,
    gaplessPlayback: true,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,  // ← key line
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : _Placeholder(height: height, width: width),
    errorBuilder: (_, _, _) => _Placeholder(height: height, width: width, isError: true),
  );
}
return CachedNetworkImage(/* native path unchanged */);
```

### Trade-off: flicker on fast scroll back

`<img>` element rendering on web costs us **two** things compared to native `CachedNetworkImage`:

1. **No `memCacheWidth` decode-time resize** — the browser downloads full-resolution originals. Planta Naturalis serves 2000 px WebP files → slow.
2. **No process-global bitmap cache that survives widget disposal** — when `ListView.builder` disposes off-screen cards, the `<img>` DOM element unmounts. On scroll-back the new `<img>` re-mounts; bytes return instantly from browser HTTP cache, but there's a brief paint gap between mount and first decoded frame.

The `cacheExtent` bump (knob #2) is the mitigation, not a fix. The proper fix is a backend image proxy (Hono `/api/image-proxy?url=&w=`) that lets web go back to `CachedNetworkImage` on a same-origin URL — same Dart bitmap cache as native, zero flicker. Backlog item, see §7.

---

## Image cache — `memCacheWidth` strategy

`CachedNetworkImage` decodes the JPEG/WebP bytes into an RGBA bitmap that lives in `PaintingBinding.imageCache`. The bitmap size is the dominant memory cost.

### The rule we use

```dart
memCacheWidth: width != null ? (width! * 2).toInt() : 1080,
```

- **Caller passes `width`** → decode to `width × 2` pixels. The 2× covers hi-DPI screens (DPR up to 3 on modern phones, but 2× is the perceptual sweet spot — going to 3× is rarely visible and triples the bitmap memory).
- **Caller passes only `height` (hero/detail image case)** → fall back to **1080 px**. Covers most phone viewports at full DPR.

### Why 1080 and not the previous 240

The list cards pass `width: 100` → `memCacheWidth: 200`, perfect for a thumbnail. But the detail screen passes:

```dart
// lib/screens/mixture_detail_screen.dart:80
ProductImage(url: product.primaryImage, height: 240, fit: BoxFit.cover)
```

Notice: **no `width`**. The hero image stretches to the full viewport width (~688 px on a typical phone). Our original fallback of `240` meant the bitmap was decoded to 240 × ~360 px, then stretched to ~688 × 240. The result was visibly blurry — verified by screenshot comparison before/after the fix.

Bumping the fallback to 1080 makes the hero crisp on every device we've tested without measurable memory impact (one extra ~3 MB bitmap in cache, well under the 50 MB cap from knob #9).

### Lesson

When you pass only `height` to a network image widget that uses `memCacheWidth`, you're handing the cache manager a riddle it can't solve. Either:
- Pass both `width` and `height`, or
- Have an explicit fallback for the hero-image case sized for full-viewport width.

The pattern in `ProductImage` does both.

---

## Diagnostic tooling

Three tools, each catches a different kind of bug:

### 1. PerformanceOverlay (visual, on-screen)

```dart
// lib/main.dart
showPerformanceOverlay: !kReleaseMode,
```

Stacked bar graphs at the top of every frame: UI thread on top, Raster thread on bottom. Each bar = one frame's duration; the horizontal line is the 16.6 ms budget for 60 fps. Bars above the line are dropped frames.

We gate it behind `!kReleaseMode` so debug + profile builds show it (great for on-device QA) but release never leaks it to end users.

Reading the overlay:
- **UI thread spikes** = Dart code took too long this frame (heavy `build()`, expensive synchronous work, GC pause).
- **Raster thread spikes** = GPU thread took too long (complex shader, large texture upload, layer composition).
- **Tall bars together** = the whole frame budget blown.

In our case the overlay revealed a max UI of 1453 ms once during scroll fling — pure GC pause from the un-capped image cache. After capping (knob #9) the worst-case UI dropped to ~45 ms with an avg of < 2 ms.

### 2. `_ScrollLogger` — `NotificationListener<ScrollNotification>`

```dart
// lib/screens/mixtures_list_screen.dart
class _ScrollLogger extends StatelessWidget {
  final Widget child;
  const _ScrollLogger({required this.child});

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final type = n.runtimeType.toString();
        final px = n.metrics.pixels.toStringAsFixed(1);
        final max = n.metrics.maxScrollExtent.toStringAsFixed(0);
        debugPrint('[ScrollLog] $type pixels=$px / $max');
        return false;  // don't swallow — let other listeners hear it too
      },
      child: child,
    );
  }
}
```

Captures `ScrollStartNotification`, `ScrollUpdateNotification`, `ScrollEndNotification`, `UserScrollNotification`. Each event includes the current pixel position so you can correlate gesture with actual scroll motion.

**Bug pattern this catches**: emulator pointer-event collapse, broken Bluetooth trackpad, frozen scroll controller. When notifications show flat-line pixels with `Start → End` only patterns (no `Update` between), the input source is lying.

### 3. `adb logcat` filter

```bash
adb -s {DEVICE_ID} logcat -d -t 200 | grep -iE "flutter|seedmixer|seed_mixer|scrolllog" | tail -40
```

- `-d` = dump and exit (NOT continuous tail — for that use `-T` or pipe without `-d`).
- `-t 200` = last 200 lines from buffer.
- `-s {ID}` = pin to a specific device when emulator + phone are both connected.

Filters Flutter's `I/flutter` tag (where `debugPrint` ends up) and our `[ScrollLog]` prefix.

---

## Testing on real devices — Mi Account gate workaround

**Xiaomi/HyperOS devices** (verified on Redmi Note 14 Pro, model `2409BRN2CY`, codename `lake`) block `adb install` and `adb shell pm install` with `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user`. The gate is the MIUI/HyperOS "Install via USB" toggle in Developer Options, which **requires a Mi Account login to enable**.

### What does NOT work (all hit the gate)

```bash
adb install file.apk
adb install -t --user 0 file.apk
adb push /data/local/tmp/file.apk && adb shell pm install -t /data/local/tmp/file.apk
adb shell am start -a android.intent.action.VIEW -d file:///sdcard/Download/file.apk  # Android 7+ blocks file://
```

### What DOES work

```bash
adb push build/app/outputs/flutter-apk/app-profile.apk /sdcard/Download/seedmixer.apk
# On the phone:
#   Files app → Internal storage → Download → tap seedmixer.apk
#   System installer dialog opens → "Allow from this source" (for Files) → Install
```

The system installer activity that runs when you tap an APK in Files goes through a different code path that the Mi Account gate doesn't intercept. ~10 second workflow.

### Wireless debugging — same gate doesn't apply, but…

Wireless debugging (Settings → Developer options → Wireless debugging) goes through the standard Android ADB protocol and isn't gated by Mi Account. BUT it requires phone + Mac on the **same wifi without AP isolation**. Many home routers have AP isolation enabled (blocks client-to-client traffic). Verified failing on user's home wifi: `arp -n 192.168.69.29 → (incomplete)`.

Workarounds:
- USB tethering (phone shares mobile data to Mac via cable; phone is reachable through the cable's network interface).
- Phone hotspot (Mac connects to phone's hotspot, both on phone's local subnet).
- Router admin disabling AP isolation.

Or just side-load via Files (above) — simplest path.

---

## Build commands cheat sheet

```bash
# All commands run from flutter-app/

# Web (no emulator needed)
flutter build web --release          # output: build/web/
python3 -m http.server 8788 -d build/web  # serve it

# Android emulator (JIT, fastest dev loop)
flutter run -d {EMULATOR_ID}

# Android profile build for real-device QA (AOT, prod-like perf)
source scripts/setup-android-env.sh
flutter build apk --profile          # output: build/app/outputs/flutter-apk/app-profile.apk (~83 MB)

# Android release build (smallest, no diagnostics)
flutter build apk --release

# macOS (blocked on full Xcode — see §7)
flutter build macos
```

### Recording a demo on real device

```bash
# Background: capture screen + filtered logcat in parallel
adb -s {ID} shell screenrecord --size 720x1600 --bit-rate 4000000 --time-limit 180 /sdcard/demo.mp4 &
adb -s {ID} logcat -v threadtime | grep -iE "flutter|seedmixer|MIUIInput.*MotionEvent" > logs/demo.log &

# Use the app...

# Stop cleanly (screenrecord finalizes the mp4 on SIGINT)
adb -s {ID} shell pkill -SIGINT screenrecord
adb -s {ID} pull /sdcard/demo.mp4 logs/

# Compress for GitHub PR comment (<10 MB)
ffmpeg -i logs/demo.mp4 \
  -vf "setpts=PTS/1.5,scale=480:-2" \
  -an -c:v libx264 -preset slow -crf 30 -pix_fmt yuv420p -movflags +faststart \
  logs/demo-trimmed.mp4
```

---

## Known limitations + future work

### 1. Web target images: full-res from upstream CDN
Planta Naturalis serves 2000 px WebP originals; we display ~100 px thumbnails. Web has no decode-time resize because `<img>` element rendering bypasses Dart's image cache. **Fix**: backend image proxy at `seed-mixer-api` (Hono route `/api/image-proxy?url=&w=` with Sharp resize + aggressive `Cache-Control` + correct CORS). Then web can switch back to `CachedNetworkImage` pointing at the proxy — same-origin, same cache as native, no flicker, ~10× smaller payload. Tracked separately.

### 2. Web target flicker on fast scroll-back
Mitigated by `cacheExtent: _itemExtent * 10` but not eliminated. Will disappear once backend image proxy lands (item #1) and web can use Dart-side bitmap cache.

### 3. macOS desktop build blocked
Scaffolding is in place — `macos/Runner/{DebugProfile,Release}.entitlements` have `com.apple.security.network.client` set. But `flutter build macos` requires full Xcode.app, not just CommandLineTools. User opted to skip the ~15 GB Xcode install. Tested on web target instead, which is a reasonable stand-in for desktop UX (same trackpad input, same layout). Run when Xcode is available:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
flutter build macos
```

### 4. iOS untested
Same blocker as macOS (needs full Xcode). Same likely smooth result.

### 5. Render free-tier cold-start
First request to `seed-mixer-api.onrender.com` after a quiet period can take 30–60 s. We have a 70 s timeout in `ApiClient` and a friendly "warming up" message in `ErrorBanner`. Acceptable for a demo; not acceptable for production. Cheapest fix is a cron pinger; better fix is paid tier or self-host.

### 6. No tests beyond `flutter analyze`
Widget tests for the two screens + a unit test for DTO → domain mappers are a fair next step. Not blocking the PoC merge.
