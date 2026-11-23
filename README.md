# bilgi-motoru

Bilgi Yarışması ailesinin ortak motoru. Sorular dil bağımsız veriden üretilir, her soru tek doğru yanıtı olduğu denetlenerek bölüme alınır; metinler oyuncunun diline göre (33 dil) kurulur.

## Türler (`kBilgiKinds`)

| Tür | Oyun | Soru şablonları |
|---|---|---|
| `genel` | Genel Kültür | Başkent, kıta, haritada ülke, yüzölçümü, element, gezegen, birim, hayvan, tarih |
| `tarih` | Tarih ve Tarihler | Yıl bul, hangisi önce/sonra, olayları sırala, yıl aralığı |
| `iller` | İller ve Plakalar | Plaka → il, il → plaka, bölge, haritada il, haritaya dokun, hangisi kuzeyde/doğuda |
| `harita` | Dünya Haritası | Haritaya dokun (uzaklık ölçülür), işaretli ülke, başkent, kıta, yüzölçümü |
| `bilim` | Elementler ve Bilim | Atom numarası ↔ simge, grup, sıvı/gaz, periyot, atom kütlesi, gezegenler, birim çevirme |
| `doga` | Hayvanlar ve Doğa | Sınıf, yumurtlama, denizde yaşama, boyut, bacak sayısı, otçul/etçil |
| `hangisi` | Hangisi Daha? | İki seçenekli hızlı karşılaştırmalar |
| `duello` | Bilgi Düellosu | Tek telefonda iki kişi; üst yarı ters döner |

Ekran: üç can, soru başına süre, seri çarpanı, 50:50 / Pas / +Süre jokerleri (her turda birer; bitince ödüllü reklamla yenilenir), her yanıttan sonra kısa açıklama.

## Veri ve lisanslar

- Ülke adları, başkentlerin yerel adları ve kıta adları: Unicode CLDR (Unicode License v3), `babel` paketi aracılığıyla.
- Harita: Natural Earth 1:110m kara ve 1:50m Türkiye sınırı (kamu malı), `world-atlas` paketinden; Douglas–Peucker ile sadeleştirildi. Haritada ülke sınırları çizilmez; yalnız kara kütleleri ve iğne gösterilir.
- Yüzölçümü ve başkent konumları: `countryinfo` paketi verisi (MIT).
- Atom kütleleri: `periodictable` paketi (IUPAC standart değerleri).
- İl merkezleri, olaylar, hayvan özellikleri: stüdyo tarafından derlendi. Tartışmalı sınır veya başkenti olan ülkeler ilgili soru türlerinden çıkarıldı; yalnız BM üyesi 193 ülke kullanılır.

Veri dosyaları `proto/bilgi/mkdata.py` ile üretilir (`lib/src/data/`).
