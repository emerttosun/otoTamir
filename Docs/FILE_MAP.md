# Dosya Haritası

## Kök ve uygulama

- `AGENTS.md`: Mimari, kod kalitesi ve teslim kurallarını zorunlu kılar.
- `README.md`: Projeyi açma, çalıştırma ve servisleri bağlama adımlarını açıklar.
- `.gitignore`: SwiftPM ve Xcode tarafından üretilen yerel derleme dosyalarını sürüm kontrolünden uzak tutar.
- `OtoTamir.xcodeproj`: iOS 17 portre uygulama target'ını ve yerel paket ürünlerini Xcode'a bağlar.
- `GameModules/Package.swift`: Altı üretim modülü ile iki test target'ının bağımlılık grafiğini tanımlar.
- `OtoTamir/App/OtoTamirApp.swift`: SwiftUI uygulama yaşam döngüsü ve arka plana geçiş kaydını yönetir.
- `OtoTamir/App/AppContainer.swift`: Bütün modülleri ve dış servis adaptörlerini tek composition root'ta kurar.
- `OtoTamir/OtoTamir.entitlements`: CloudKit özel veritabanı yetkilerini tanımlar.
- `OtoTamir/Resources/Localizable.xcstrings`: Türkçe kaynak dilini ve gelecekteki yerelleştirmeleri taşır.
- `OtoTamir/Resources/OtoTamir.storekit`: İki nakit, bir kozmetik ve bir içerik test ürününü tanımlar.

## GameDomain

- `Money.swift`: Kuruş tabanlı güvenli para değerini ve Türk lirası gösterimini sağlar.
- `ContentModels.swift`: JSON'dan gelen araç, arıza, müşteri, dükkân ve denge tiplerini tanımlar.
- `GameModels.swift`: Kayıt durumunu, işleri, itibarı, ihaleyi ve proje araçlarını tanımlar.
- `GameContracts.swift`: Komut, olay, hata ve kayıt/bulut/satın alma portlarını tanımlar.

## GameLogic ve GameContent

- `SeededRandomSource.swift`: Kayıt seed'inden tekrar üretilebilir rastgele sayı ve kimlik üretir.
- `GameEngine.swift`: Bütün müşteri, ekonomi, gün, itibar, ihale ve restorasyon kurallarının tek değişim noktasıdır.
- `DefaultContentRepository.swift`: Paket JSON'unu yükler ve bütünlük kurallarını doğrular.
- `Resources/catalog.json`: 6 araç, 12 arıza, 10 müşteri ve denge verilerini koddan bağımsız tutar.

## Apple servis adaptörleri

- `JSONFileSaveRepository.swift`: Atomik yerel kayıt, yedek okuma ve sürümlü kayıt göçünü uygular.
- `CloudKitSyncService.swift`: Özel CloudKit veritabanı eşitlemesi ve ayrışmış kayıt algılamasını uygular.
- `StoreKitPurchaseService.swift`: StoreKit 2 ürün, doğrulama, satın alma ve geri yükleme akışını uygular.

## GamePresentation

- `GameStore.swift`: UI ile oyun motoru arasındaki MainActor köprüsü, otomatik kayıt ve servis durumlarını yönetir.
- `RootGameView.swift`: Dikey uygulama kabuğu, durum çubuğu ve üç ana bölüm geçişini sunar.
- `WorkshopView.swift`: Müşteri kabulünden ödeme öncesi tamire kadar bağlamsal iş akışını gösterir.
- `AuctionView.swift`: Üç turlu ihale, ekspertiz, restorasyon ve satış arayüzünü sunar.
- `ProgressViewScreen.swift`: Uzmanlık, itibar, dükkân, iCloud ve mağaza ekranlarını sunar.
- `RepairMiniGames.swift`: Gösterge, civata, kablo ve hizalama mini oyunlarını içerir.
- `WorkshopScene.swift`: Kodla çizilen özgün placeholder tamirhane ve araç SpriteKit sahnesidir.
- `Style.swift`: Paylaşılan renk, kart, düğme stilleri ve iPhone dokunsal geri bildirimini tanımlar.

## Testler

- `GameLogicTests.swift`: Determinizm, tamir döngüsü, ekonomi, kriz, ihale, satın alma ve kayıt göçünü doğrular.
- `GameContentTests.swift`: İçerik sayısı, benzersiz kimlik ve kapsama kurallarını doğrular.
