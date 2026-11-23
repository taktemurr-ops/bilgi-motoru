import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data/geo.dart';
import 'data/provinces.dart';

/// Haritada bir işaret: konum, renk, isteğe bağlı halka yarıçapı (mantıksal birim).
class MapMark {
  final double lat;
  final double lon;
  final Color color;
  final double ring;
  final bool pin;
  const MapMark(this.lat, this.lon, this.color, {this.ring = 0, this.pin = true});
}

/// Eş dikdörtgen dünya haritası ve Türkiye haritası için ortak izdüşüm.
abstract class GeoProjection {
  double get w;
  double get h;
  Offset toXY(double lat, double lon);
  (double, double) toLatLon(Offset p);
}

class WorldProjection implements GeoProjection {
  const WorldProjection();
  static const top = 84.0, bottom = -58.0, k = 2.0;
  @override
  double get w => 360 * k;
  @override
  double get h => (top - bottom) * k;
  @override
  Offset toXY(double lat, double lon) => Offset((lon + 180) * k, (top - lat) * k);
  @override
  (double, double) toLatLon(Offset p) => (top - p.dy / k, p.dx / k - 180);
}

class TurkeyProjection implements GeoProjection {
  const TurkeyProjection();
  static const west = 25.4, east = 45.2, north = 42.4, south = 35.6, kx = 30.0, ky = 38.5;
  @override
  double get w => (east - west) * kx;
  @override
  double get h => (north - south) * ky;
  @override
  Offset toXY(double lat, double lon) => Offset((lon - west) * kx, (north - lat) * ky);
  @override
  (double, double) toLatLon(Offset p) => (north - p.dy / ky, p.dx / kx + west);
}

/// Haritayı kullanılabilir alana oranı koruyarak sığdırır; dokunuşu enlem/boylama çevirir.
class GeoMap extends StatelessWidget {
  final bool turkey;
  final List<MapMark> marks;
  final void Function(double lat, double lon)? onTap;
  final String? semantics;

  /// Türkiye haritasında bütün il merkezlerini soluk nokta olarak göster.
  final bool provinceDots;
  const GeoMap({super.key, required this.turkey, this.marks = const [], this.onTap, this.semantics, this.provinceDots = true});

  GeoProjection get proj => turkey ? const TurkeyProjection() : const WorldProjection();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, box) {
      final p = proj;
      final mw = box.maxWidth.isFinite ? box.maxWidth : 360.0;
      final mh = box.maxHeight.isFinite ? box.maxHeight : 240.0;
      final k = math.min<double>(mw / p.w, mh / p.h);
      final tap = onTap;
      return Center(
        child: Semantics(
          label: semantics,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: tap == null
                ? null
                : (e) {
                    final ll = p.toLatLon(e.localPosition / k);
                    tap(ll.$1, ll.$2);
                  },
            child: CustomPaint(
              size: Size(p.w * k, p.h * k),
              painter: _MapPainter(
                proj: p,
                k: k,
                turkey: turkey,
                marks: marks,
                dots: provinceDots,
                sea: dark ? const Color(0xFF1E3442) : const Color(0xFFDCE8EC),
                land: dark ? const Color(0xFF6B5B45) : const Color(0xFFE9D9B8),
                coast: dark ? const Color(0xFFB8A27A) : const Color(0xFF9C8462),
                ink: scheme.onSurface,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MapPainter extends CustomPainter {
  final GeoProjection proj;
  final double k;
  final bool turkey;
  final List<MapMark> marks;
  final bool dots;
  final Color sea, land, coast, ink;
  _MapPainter({
    required this.proj,
    required this.k,
    required this.turkey,
    required this.marks,
    required this.dots,
    required this.sea,
    required this.land,
    required this.coast,
    required this.ink,
  });

  Path _ring(List<int> r, double div) {
    final path = Path();
    for (var i = 0; i + 1 < r.length; i += 2) {
      final o = proj.toXY(r[i + 1] / div, r[i] / div);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    final rect = Rect.fromLTWH(0, 0, proj.w, proj.h);
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(turkey ? 10 : 8)));
    canvas.drawRect(rect, Paint()..color = sea);
    // ızgara: dünya haritasında 30°'lik enlem/boylam çizgileri
    if (!turkey) {
      final g = Paint()
        ..color = ink.withValues(alpha: 0.07)
        ..strokeWidth = 0.6;
      for (var lon = -150; lon <= 150; lon += 30) {
        final a = proj.toXY(WorldProjection.top, lon.toDouble()), b = proj.toXY(WorldProjection.bottom, lon.toDouble());
        canvas.drawLine(a, b, g);
      }
      for (var lat = -30; lat <= 60; lat += 30) {
        final a = proj.toXY(lat.toDouble(), -180), b = proj.toXY(lat.toDouble(), 180);
        canvas.drawLine(a, b, g);
      }
    }
    final fillP = Paint()..color = land;
    final lineP = Paint()
      ..color = coast
      ..style = PaintingStyle.stroke
      ..strokeWidth = turkey ? 1.4 : 0.7
      ..strokeJoin = StrokeJoin.round;
    if (turkey) {
      // komşu karalar da soluk görünsün
      for (final r in kLand) {
        canvas.drawPath(_ring(r, 10), Paint()..color = land.withValues(alpha: 0.45));
      }
      for (final r in kTurkeyOutline) {
        final path = _ring(r, 100);
        canvas.drawPath(path, fillP);
        canvas.drawPath(path, lineP);
      }
      if (dots) {
        final dp = Paint()..color = ink.withValues(alpha: 0.28);
        for (final pr in kProvinces) {
          canvas.drawCircle(proj.toXY(pr.lat, pr.lon), 2.6, dp);
        }
      }
    } else {
      for (final r in kLand) {
        final path = _ring(r, 10);
        canvas.drawPath(path, fillP);
        canvas.drawPath(path, lineP);
      }
    }
    final s = turkey ? 1.6 : 1.3;
    for (final m in marks) {
      final c = proj.toXY(m.lat, m.lon);
      if (m.ring > 0) {
        canvas.drawCircle(c, m.ring, Paint()..color = m.color.withValues(alpha: 0.16));
        canvas.drawCircle(
            c,
            m.ring,
            Paint()
              ..color = m.color.withValues(alpha: 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2 * s);
      }
      if (m.pin) {
        final head = c - Offset(0, 11 * s);
        final path = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(head.dx - 5 * s, head.dy + 3 * s)
          ..lineTo(head.dx + 5 * s, head.dy + 3 * s)
          ..close();
        canvas.drawPath(path, Paint()..color = m.color);
        canvas.drawCircle(head, 6 * s, Paint()..color = m.color);
        canvas.drawCircle(head, 2.4 * s, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(c, 4 * s, Paint()..color = m.color);
        canvas.drawCircle(
            c,
            4 * s,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}
