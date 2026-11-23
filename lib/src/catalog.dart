import 'core.dart';
import 'quiz.dart';

/// Bilgi yarışması türleri: hangi şablonlardan ne ağırlıkla soru gelir.
final Map<String, BilgiKind> kBilgiKinds = {
  'genel': const BilgiKind('genel', [
    (Tpl.cap, 3), (Tpl.cont, 2), (Tpl.pinCountry, 2), (Tpl.area, 1), //
    (Tpl.z2s, 1), (Tpl.s2z, 1), (Tpl.cat, 1), (Tpl.gas, 1), (Tpl.liquid, 1), //
    (Tpl.planetN, 1), (Tpl.planetBig, 1), (Tpl.rocky, 1), (Tpl.unit, 2), //
    (Tpl.cls, 2), (Tpl.eggs, 1), (Tpl.sea, 1), (Tpl.biggest, 1), (Tpl.herb, 1), (Tpl.carn, 1), //
    (Tpl.year, 2), (Tpl.first, 2), (Tpl.span, 1), (Tpl.bigger, 1),
  ]),
  'tarih': const BilgiKind('tarih', [
    (Tpl.year, 3), (Tpl.first, 3), (Tpl.later, 2), (Tpl.order, 3), (Tpl.span, 2),
  ]),
  'iller': const BilgiKind('iller', [
    (Tpl.plate, 3), (Tpl.plateRev, 3), (Tpl.region, 3), (Tpl.pinProv, 3), (Tpl.tapProv, 3), (Tpl.north, 2), (Tpl.east, 2),
  ]),
  'harita': const BilgiKind('harita', [
    (Tpl.tapCountry, 4), (Tpl.pinCountry, 3), (Tpl.cap, 3), (Tpl.cont, 2), (Tpl.area, 2),
  ]),
  'bilim': const BilgiKind('bilim', [
    (Tpl.z2s, 3), (Tpl.s2z, 3), (Tpl.cat, 2), (Tpl.liquid, 1), (Tpl.gas, 2), (Tpl.period, 2), (Tpl.mass, 2), //
    (Tpl.planetN, 2), (Tpl.planetBig, 2), (Tpl.rocky, 1), (Tpl.unit, 3),
  ]),
  'doga': const BilgiKind('doga', [
    (Tpl.cls, 3), (Tpl.notCls, 2), (Tpl.eggs, 2), (Tpl.sea, 2), (Tpl.biggest, 2), (Tpl.legs, 2), (Tpl.herb, 2), (Tpl.carn, 2), (Tpl.bigger, 2),
  ]),
  'hangisi': const BilgiKind('hangisi', [
    (Tpl.area, 3), (Tpl.north, 2), (Tpl.east, 2), (Tpl.mass, 2), (Tpl.planetBig, 1), (Tpl.first, 3), (Tpl.later, 2), (Tpl.bigger, 3),
  ], base: 10, per: 2, timeScale: 0.7),
  'duello': const BilgiKind('duello', [
    (Tpl.cap, 2), (Tpl.cont, 1), (Tpl.area, 1), (Tpl.z2s, 1), (Tpl.s2z, 1), (Tpl.gas, 1), //
    (Tpl.planetN, 1), (Tpl.planetBig, 1), (Tpl.rocky, 1), (Tpl.unit, 2), //
    (Tpl.cls, 2), (Tpl.eggs, 1), (Tpl.sea, 1), (Tpl.biggest, 1), (Tpl.herb, 1), (Tpl.carn, 1), (Tpl.bigger, 1), (Tpl.legs, 1), //
    (Tpl.year, 1), (Tpl.span, 1),
  ], base: 12, per: 100, duel: true),
};

BilgiRules bilgiRulesFor(String gameId, String kind) => bilgiRules(gameId, kBilgiKinds[kind]!);
