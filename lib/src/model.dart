/// Bilgi verisinin satır türleri (veri dosyaları proto/bilgi/mkdata.py ile üretilir).
library;

class Country {
  final String iso;

  /// 0 Afrika, 1 Avrupa, 2 Asya, 3 Kuzey Amerika, 4 Güney Amerika, 5 Okyanusya; -1 çok kıtalı.
  final int cont;

  /// km² (iç sular dâhil).
  final int area;
  final double lat;
  final double lon;

  /// 1:110m haritada görünecek büyüklükte mi?
  final bool onMap;

  /// Başkent sorusunda kullanılabilir mi (tek ve tartışmasız başkent)?
  final bool capOk;
  const Country(this.iso, this.cont, this.area, this.lat, this.lon, this.onMap, this.capOk);
}

class Province {
  final int plate;
  final String name;

  /// 0 Marmara, 1 Ege, 2 Akdeniz, 3 İç Anadolu, 4 Karadeniz, 5 Doğu Anadolu, 6 Güneydoğu Anadolu.
  final int region;
  final double lat;
  final double lon;
  const Province(this.plate, this.name, this.region, this.lat, this.lon);
}

class Elem {
  final int z;
  final String sym;
  final String tr;
  final String en;
  final double mass;
  final int period;

  /// 1..18; 0: lantanit/aktinit.
  final int group;

  /// 0 alkali, 1 toprak alkali, 2 geçiş metali, 3 halojen, 4 soy gaz, -1 diğer.
  final int cat;

  /// 25 °C'de: 0 katı, 1 sıvı, 2 gaz, -1 bilinmiyor/sınırda.
  final int state;
  const Elem(this.z, this.sym, this.tr, this.en, this.mass, this.period, this.group, this.cat, this.state);
}

class Animal {
  final String emoji;
  final String tr;
  final String en;

  /// 0 memeli, 1 kuş, 2 sürüngen, 3 iki yaşamlı, 4 balık, 5 böcek, 6 örümceğimsi, -1 diğer.
  final int cls;

  /// 0 otçul, 1 etçil, 2 hepçil, -1 belirsiz.
  final int diet;

  /// 1 denizde yaşar, 0 yaşamaz, -1 belirsiz.
  final int sea;

  /// 1 yumurtlar, 0 yumurtlamaz, -1 belirsiz.
  final int eggs;

  /// Bacak sayısı; -1 belirsiz.
  final int legs;

  /// Tipik yetişkin kütlesi (kg); -1 belirsiz.
  final double kg;
  const Animal(this.emoji, this.tr, this.en, this.cls, this.diet, this.sea, this.eggs, this.legs, this.kg);
}

class HEvent {
  final int year;

  /// 0 bilim, 1 keşif ve uzay, 2 icat, 3 yapı, 4 spor ve kültür, 5 tarih.
  final int kind;
  final String tr;
  final String en;
  const HEvent(this.year, this.kind, this.tr, this.en);
}

class Dish {
  final String emoji;
  final String tr;
  final String en;

  /// kCountries içindeki sıra.
  final int country;
  const Dish(this.emoji, this.tr, this.en, this.country);
}

class Fact {
  final bool truth;
  final String tr;
  final String en;
  final String exTr;
  final String exEn;
  const Fact(this.truth, this.tr, this.en, this.exTr, this.exEn);
}

class NumFact {
  final String tr;
  final String en;
  final double value;
  final String unit;
  final int decimals;
  const NumFact(this.tr, this.en, this.value, this.unit, this.decimals);
}

class Mountain {
  final String tr;
  final String en;
  final int m;
  const Mountain(this.tr, this.en, this.m);
}
