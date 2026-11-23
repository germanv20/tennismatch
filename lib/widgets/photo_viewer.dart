import 'package:flutter/material.dart';

/// Opens [url] in a full-screen, pinch-to-zoom viewer (black background).
/// Used when tapping another player's profile picture so small or
/// low-detail photos can be inspected properly. Close with the X button, a
/// single tap, or the system back gesture.
Future<void> showPhotoViewer(BuildContext context, String url,
    {String? heroTag}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, __, ___) => _PhotoViewer(url: url, heroTag: heroTag),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatelessWidget {
  final String url;
  final String? heroTag;

  const _PhotoViewer({required this.url, this.heroTag});

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white54,
            size: 64,
          ),
        ),
      ),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // A single tap anywhere closes the viewer; pinch/drag are still
          // handled by the InteractiveViewer.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: image,
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
