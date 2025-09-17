import 'package:flutter_test/flutter_test.dart';
import 'package:baitech_web_app/utils/webview_zoom.dart';

void main() {
  group('WebViewZoom', () {
    test('buildZoomScript clamps and contains expected values', () {
      final script = WebViewZoom.buildZoomScript(0.7);
      expect(script, contains('document.documentElement.style.zoom'));
      expect(script, contains('document.body.style.zoom'));
      expect(script, contains('0.7'));
    });

    test('buildZoomScript clamps too-small values to 0.1', () {
      final script = WebViewZoom.buildZoomScript(0.01);
      expect(script, contains('0.1'));
    });

    test('buildZoomScript clamps too-large values to 5.0', () {
      final script = WebViewZoom.buildZoomScript(10.0);
      expect(script, contains('5.0'));
    });
  });
}


