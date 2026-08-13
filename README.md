# OtoTamir

Türk sanayi kültüründen esinlenen, SwiftUI ve SpriteKit ile geliştirilmiş dikey iPhone tamirhane simülasyonu prototipi.

## Açma ve çalıştırma

1. `OtoTamir.xcodeproj` dosyasını Xcode 26 veya daha yeni sürümde açın.
2. `OtoTamir` scheme'ini ve bir iOS 17+ iPhone simülatörünü seçin.
3. Çalıştırın. İlk açılışta üç müşteri teklifi otomatik üretilir.

StoreKit ürünlerini yerel test etmek için scheme Run ayarındaki StoreKit Configuration alanında `OtoTamir/Resources/OtoTamir.storekit` seçilir. Gerçek iCloud için bundle identifier, geliştirici takımı ve CloudKit container App Store Connect/Developer Portal üzerinde oluşturulmalıdır; servis kullanılamazsa oyun yerel kayda devam eder.

## Doğrulama

```sh
swift test --package-path GameModules
xcodebuild -project OtoTamir.xcodeproj -scheme OtoTamir \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Mimari ve oyun kararları `Docs/` klasöründedir. Depo kuralları `AGENTS.md` içinde tutulur.

