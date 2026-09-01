import 'dart:io';
import 'package:image/image.dart' as img;

// Separable max-filter (dilate) / min-filter (erode) over a square window,
// used for morphological closing.
List<List<bool>> _dilate(List<List<bool>> m, int w, int h, int r) =>
    _filter(m, w, h, r, true);
List<List<bool>> _erode(List<List<bool>> m, int w, int h, int r) =>
    _filter(m, w, h, r, false);

List<List<bool>> _filter(
  List<List<bool>> m,
  int w,
  int h,
  int r,
  bool anyTrue,
) {
  final horiz = List.generate(h, (_) => List.filled(w, false));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var v = anyTrue ? false : true;
      for (var dx = -r; dx <= r; dx++) {
        final xx = x + dx;
        final cell = (xx < 0 || xx >= w) ? !anyTrue : m[y][xx];
        if (anyTrue) {
          v = v || cell;
        } else {
          v = v && cell;
        }
      }
      horiz[y][x] = v;
    }
  }
  final out = List.generate(h, (_) => List.filled(w, false));
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      var v = anyTrue ? false : true;
      for (var dy = -r; dy <= r; dy++) {
        final yy = y + dy;
        final cell = (yy < 0 || yy >= h) ? !anyTrue : horiz[yy][x];
        if (anyTrue) {
          v = v || cell;
        } else {
          v = v && cell;
        }
      }
      out[y][x] = v;
    }
  }
  return out;
}

// Generates a white-on-transparent Android notification icon (drawable) from
// assets/icon/app_icon.jpeg. Android requires the status-bar/tray icon to be
// a simple alpha-only silhouette; feeding it the full-color launcher icon
// makes the OS fall back to a solid white box. The source logo is too
// detailed to read at 24dp, so this fills the shield outline into one solid
// silhouette (dropping interior line detail) rather than tracing every line.
void main() {
  final src = img.decodeImage(
    File('assets/icon/app_icon.jpeg').readAsBytesSync(),
  )!;

  final w = src.width, h = src.height;
  const lumCut = 190.0; // below this luminance counts as "ink"

  final ink = List.generate(h, (_) => List.filled(w, false));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      ink[y][x] = img.getLuminance(src.getPixel(x, y)) < lumCut;
    }
  }

  // Morphological closing (dilate then erode) bridges small gaps in the
  // outline (e.g. where the ribbon design breaks the shield's border) so the
  // flood fill below can't leak into the interior through them, while
  // leaving intentionally large gaps (between the speed lines, etc) alone.
  final r = (w < h ? w : h) ~/ 80;
  final closedInk = _erode(_dilate(ink, w, h, r), w, h, r);

  // Flood fill from the border across non-ink pixels to find the
  // background; anything left (ink, or non-ink fully enclosed by ink) is
  // treated as solid icon.
  final outside = List.generate(h, (_) => List.filled(w, false));
  final stack = <List<int>>[];
  for (var x = 0; x < w; x++) {
    if (!closedInk[0][x]) stack.add([x, 0]);
    if (!closedInk[h - 1][x]) stack.add([x, h - 1]);
  }
  for (var y = 0; y < h; y++) {
    if (!closedInk[y][0]) stack.add([0, y]);
    if (!closedInk[y][w - 1]) stack.add([w - 1, y]);
  }
  while (stack.isNotEmpty) {
    final p = stack.removeLast();
    final x = p[0], y = p[1];
    if (x < 0 || x >= w || y < 0 || y >= h) continue;
    if (outside[y][x] || closedInk[y][x]) continue;
    outside[y][x] = true;
    stack.add([x + 1, y]);
    stack.add([x - 1, y]);
    stack.add([x, y + 1]);
    stack.add([x, y - 1]);
  }

  final mask = img.Image(width: w, height: h, numChannels: 4);
  int minX = w, minY = h, maxX = 0, maxY = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final solid = ink[y][x] || !outside[y][x];
      mask.setPixelRgba(x, y, 255, 255, 255, solid ? 255 : 0);
      if (solid) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  final margin = ((maxX - minX) * 0.06).round();
  minX = (minX - margin).clamp(0, w - 1);
  minY = (minY - margin).clamp(0, h - 1);
  maxX = (maxX + margin).clamp(0, w - 1);
  maxY = (maxY + margin).clamp(0, h - 1);
  final cropped = img.copyCrop(
    mask,
    x: minX,
    y: minY,
    width: (maxX - minX).clamp(1, w),
    height: (maxY - minY).clamp(1, h),
  );

  final side = cropped.width > cropped.height ? cropped.width : cropped.height;
  final square = img.Image(width: side, height: side, numChannels: 4);
  img.compositeImage(
    square,
    cropped,
    dstX: ((side - cropped.width) / 2).round(),
    dstY: ((side - cropped.height) / 2).round(),
  );

  const densities = {
    'mdpi': 24,
    'hdpi': 36,
    'xhdpi': 48,
    'xxhdpi': 72,
    'xxxhdpi': 96,
  };

  for (final entry in densities.entries) {
    final resized = img.copyResize(
      square,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.average,
    );
    final dir = Directory(
      'android/app/src/main/res/drawable-${entry.key}',
    )..createSync(recursive: true);
    File('${dir.path}/ic_notification.png')
        .writeAsBytesSync(img.encodePng(resized));
  }

  stdout.writeln('Done: ${densities.keys.join(", ")}');
}
