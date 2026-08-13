# OtoTamir Geliştirme Kuralları

Bu kurallar depo genelindeki bütün kaynak ve test dosyaları için zorunludur.

## Mimari

- Bağımlılık yönü `GameDomain <- GameLogic/GameContent <- GamePresentation` şeklindedir. Persistence ve Commerce yalnızca domain protokollerini uygular.
- Oyun kuralları SwiftUI, SpriteKit, CloudKit veya StoreKit tipleri içeremez.
- Global mutable durum, gizli singleton, service locator ve üçüncü taraf paket kullanılamaz.
- Bağımlılıklar initializer üzerinden açıkça verilir ve uygulama target'ındaki composition root tarafından kurulur.
- Para `Money` ile tam sayı küçük birim olarak, rastgelelik kayıt içindeki seed ile temsil edilir.

## Kod kalitesi

- Swift sembolleri İngilizce; oyuncu metinleri ve proje dokümanları Türkçe yazılır.
- Bir dosya tek bir ana sorumluluk taşır. Yeni kaynak dosyası eklenince `Docs/FILE_MAP.md` güncellenir.
- Yeni oyun kuralı deterministik birim testiyle, yeni JSON içerik ise doğrulama testiyle teslim edilir.
- Swift 6 strict concurrency uyarıları hata kabul edilir.
- Zorunlu olmayan protokol, soyutlama veya tekrar kullanılmayacak genel yardımcı eklenmez.

## Teslim kontrolü

- `swift test --package-path GameModules`
- `xcodebuild -project OtoTamir.xcodeproj -scheme OtoTamir -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- UI metinlerinde erişilebilirlik etiketi, dinamik yazı boyutu ve dar ekran kontrol edilir.

