/// Utilities for controlling zoom behavior inside WebViews via injected JS.
class WebViewZoom {
  /// Returns JavaScript that applies CSS zoom to the whole page.
  ///
  /// [scale] should be between 0.1 and 3.0 typically. For example, 0.7 means 70%.
  static String buildZoomScript(double scale) {
    final clamped = scale.clamp(0.1, 5.0);
    // CSS zoom works on most mobile webviews. Fallback adjusts root font-size.
    return """
      (function(){
        try {
          var s = $clamped;
          document.documentElement.style.zoom = s;
          document.body.style.zoom = s;
          // Fallback: adjust root font-size to approximate zoom if 'zoom' unsupported
          if (!('zoom' in document.documentElement.style)) {
            var base = 100 * s;
            document.documentElement.style.fontSize = base + '%';
          }
        } catch (e) { /* ignore */ }
      })();
    """;
  }
}


