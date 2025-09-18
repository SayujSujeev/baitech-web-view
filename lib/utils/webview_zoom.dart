/// Utilities for controlling zoom behavior inside WebViews via injected JS.
class WebViewZoom {
  /// Returns JavaScript that applies CSS zoom to the whole page.
  ///
  /// [scale] should be between 0.1 and 3.0 typically. For example, 0.7 means 70%.
  static String buildZoomScript(double scale) {
    final clamped = scale.clamp(0.1, 5.0);
    // Use viewport scaling to mimic browser Ctrl +/- behavior and avoid clipping.
    // This updates or creates the <meta name="viewport"> tag with the desired scale.
    return """
      (function(){
        try {
          var s = $clamped;
          // Clear any previous style-based zooms that could cause clipping
          try {
            document.documentElement.style.zoom = '';
            document.body && (document.body.style.zoom = '');
            document.documentElement.style.fontSize = '';
            document.documentElement.style.transform = '';
            document.documentElement.style.transformOrigin = '';
          } catch(_) {}

          var head = document.head || document.getElementsByTagName('head')[0];
          if (!head) return;
          var meta = head.querySelector('meta[name="viewport"]');
          var content = 'width=device-width, initial-scale=' + s + ', minimum-scale=0.1, maximum-scale=5.0, user-scalable=yes';
          if (meta) {
            meta.setAttribute('content', content);
          } else {
            meta = document.createElement('meta');
            meta.setAttribute('name', 'viewport');
            meta.setAttribute('content', content);
            head.appendChild(meta);
          }
        } catch (e) { /* ignore */ }
      })();
    """;
  }
}


