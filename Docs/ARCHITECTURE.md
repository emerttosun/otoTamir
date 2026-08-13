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

