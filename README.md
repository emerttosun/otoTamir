# OtoTamir

Türk sanayi kültüründen esinlenen, SwiftUI ve SpriteKit ile geliştirilmiş dikey iPhone tamirhane simülasyonu prototipi.

## Açma ve çalıştırma

1. `OtoTamir.xcodeproj` dosyasını Xcode 26 veya daha yeni sürümde açın.
2. `OtoTamir` scheme'ini ve bir iOS 17+ iPhone simülatörünü seçin.
3. Çalıştırın. İlk müşteri dükkânda görünür; sonraki müşteriler yapılan işlemler veya “Biraz Müşteri Bekle” eylemiyle gelir. Kabul edilen müşteri araçları ve ihaleden alınan proje araçları Dükkân sahnesine eklenir; işlem paneli yalnız araca dokununca açılır. Oyun boşta para harcamaz. Hasarlı araçlar İhale bölümünde ekspertizle alınır, Dükkân'da restore edilir ve İlanlar bölümünde satışa çıkarılır. Çıraklar, Banka ve gerçek para ürünlerini içeren Mağaza ayrı bölümlerdir; para göstergesi kasa hareketlerini açar.

StoreKit ürünlerini yerel test etmek için paylaşılan `OtoTamir` scheme'i `OtoTamir/Resources/OtoTamir.storekit` yapılandırmasını otomatik kullanır. Canlı gerçek para satışları için aynı ürün kimlikleri App Store Connect'te oluşturulup onaylanmalıdır. Gerçek iCloud için bundle identifier, geliştirici takımı ve CloudKit container App Store Connect/Developer Portal üzerinde oluşturulmalıdır; servis kullanılamazsa oyun yerel kayda devam eder.

## Doğrulama

```sh
swift test --package-path GameModules
xcodebuild -project OtoTamir.xcodeproj -scheme OtoTamir \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Mimari ve oyun kararları `Docs/` klasöründedir. Depo kuralları `AGENTS.md` içinde tutulur.
