# Mimari

OtoTamir'de oyun kuralları platformdan bağımsız, deterministik bir durum makinesidir. Arayüz yalnızca `GameCommand` gönderir ve `GameState` okur. Kayıt, bulut ve satın alma Apple servislerini domain protokollerinin arkasında tutar.

```text
OtoTamir App (composition root)
 ├─ GamePresentation → GameLogic → GameDomain
 ├─ GameContent ─────────────────→ GameDomain
 ├─ GamePersistence ─────────────→ GameDomain
 └─ GameCommerce ────────────────→ GameDomain
```

Yeni bir modül yalnızca daha aşağıdaki katmanlara bağlanabilir. Domain hiçbir Apple UI veya servis framework'ünü import etmez.

## Durum değişimi

1. UI bir `GameCommand` oluşturur.
2. `GameEngine.handle` ön koşulları doğrular.
3. Motor durumu tek atomik işlemde değiştirir ve `GameEvent` üretir.
4. `GameStore` yeni durumu yayınlar ve kaydeder.
5. SpriteKit sahnesi dahil bütün görünümler salt okunur durumu çizer.

Rastgele seçimler `GameState.randomSeed` üzerinden yapılır. Aynı başlangıç kaydı ve komut dizisi aynı içeriği üretir.

`GameEngine` yalnızca komut yönlendirme girişidir. Davranış; dükkân, dünya/ekonomi, araç ticareti, içerik ve ortak destek sorumluluk dosyalarına ayrılır. Domain modelleri de tamir, finans, çırak ve araç ticareti dosyalarında tutulur. Yeni sistemler mevcut merkezi dosyaları büyütmek yerine kendi sorumluluk dosyası ve testiyle eklenir.

## Zaman ve kayıt

`GameState.totalMinutes` işlemlerin sıralanması için tek zaman kaynağıdır. Geçici tasarımda gerçek zaman sayacı çalıştırılmaz; yalnız oyuncu komutları zamanı ilerletir. Müşteri gelişleri, giderler, kredi taksitleri, ilan alıcı kontrolleri, hasarlı araç pazarı ve gecikmeli sonuçlar aynı deterministik takvim üzerinde kalır.

Kayıt şeması sürüm 7'dir. Eski kayıtlar silinmez; migrator gün bilgisini dakikaya, eski uzmanlık seviyelerini XP modeline taşır ve çırak/kasa hareketi/kredi, Olay Defteri ile proje restorasyon ilerlemesini güvenli varsayılanlarla ekler. iCloud eşitlemesi otomatik ve isteğe bağlıdır; normal oyun akışında elle eşitleme düğmesi bulunmaz.
