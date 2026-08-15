# Dosya Haritası

## Kök ve uygulama

- `AGENTS.md`: Mimari, kod kalitesi ve teslim kurallarını zorunlu kılar.
- `README.md`: Projeyi açma, çalıştırma ve servisleri bağlama adımlarını açıklar.
- `Docs/CONTENT_STYLE.md`: Türk sanayi mizahının sınırlarını, araştırma kaynaklarını ve arızaya özgü mini oyun tasarım ilkelerini kaydeder.
- `.gitignore`: SwiftPM ve Xcode tarafından üretilen yerel derleme dosyalarını sürüm kontrolünden uzak tutar.
- `OtoTamir.xcodeproj`: iOS 17 portre uygulama target'ını ve yerel paket ürünlerini Xcode'a bağlar.
- `GameModules/Package.swift`: Altı üretim modülü ile iki test target'ının bağımlılık grafiğini tanımlar.
- `OtoTamir/App/OtoTamirApp.swift`: SwiftUI uygulama yaşam döngüsü ve arka plana geçiş kaydını yönetir.
- `OtoTamir/App/AppContainer.swift`: Bütün modülleri tek composition root'ta kurar; imzasız Simulator'da CloudKit'i güvenli kapatıp gerçek cihazda özel iCloud container'ını kullanır.
- `OtoTamir/App/QAScenarioFactory.swift`: Yalnız Debug derlemesinde, normal kayda dokunmadan ekran ve uçtan uca oyun akışı denetimi için deterministik QA durumları üretir.
- `OtoTamir/OtoTamir.entitlements`: CloudKit özel veritabanı yetkilerini tanımlar.
- `OtoTamir/Resources/Localizable.xcstrings`: Türkçe kaynak dilini ve gelecekteki yerelleştirmeleri taşır.
- `OtoTamir/Resources/OtoTamir.storekit`: İki nakit, bir kozmetik ve bir içerik test ürününü tanımlar.
- `OtoTamir/Resources/workshop-background-v1.png`: Marka ve yazı içermeyen, iki liftli özgün 2D tamirhane sahne arka planıdır.
- `OtoTamir/Resources/workshop-car-sprite-v1.png`: Dükkândaki müşteri ve proje araçlarının içerik rengine boyanabilen şeffaf, markasız araç sprite'ıdır.

## GameDomain

- `Money.swift`: Kuruş tabanlı güvenli para değerini ve Türk lirası gösterimini sağlar.
- `ContentModels.swift`: JSON'dan gelen araç, kontrol bulgusu, arıza, müşteri, yorum, dükkân kabiliyeti ve ayrıntılı gider dengelerini tanımlar.
- `GameModels.swift`: Sürüm 7 kayıt durumunu, eylem tabanlı zamanı, XP'yi, çırakları, banka kredilerini, kasa hareketlerini, yıkamayı ve adım adım proje araç restorasyonunu tanımlar.
- `IncidentModels.swift`: Denetim, şikâyet, kredi, ilan ve benzeri dükkân olaylarını para ve itibar etkileriyle sürümlü kayda uygun tanımlar.
- `GameContracts.swift`: Komut, olay, hata ve kayıt/bulut/satın alma portlarını tanımlar.

## GameLogic ve GameContent

- `SeededRandomSource.swift`: Kayıt seed'inden tekrar üretilebilir rastgele sayı ve kimlik üretir.
- `BankingRules.swift`: Dükkân durumundan kredi limitini, vade faizini ve taksit tutarını deterministik hesaplar.
- `VehicleTradingRules.swift`: Hasarlı araç yatırım aralığını, restorasyon maliyetini, adil ilan fiyatını ve satış ihtimalini deterministik hesaplar.
- `GameEngine.swift`: Dinamik müşteri, kontrol/teşhis, bakım, fiyat, yıkama, çırak, kredi, görünür gider, sabit fiyatlı hasarlı araç, restorasyon ve ilan kurallarının tek değişim noktasıdır.
- `DefaultContentRepository.swift`: Paket JSON'unu yükler ve bütünlük kurallarını doğrular.
- `Resources/catalog.json`: 12 araç, benzersiz mini oyunlu 12 arıza, 20 müşteri, üçlü şikâyet anlatımları, 26 yorum ve yedi dükkân seviyesini koddan bağımsız tutar.

## Apple servis adaptörleri

- `JSONFileSaveRepository.swift`: Atomik yerel kayıt, yedek okuma ve sürümlü kayıt göçünü uygular.
- `CloudKitSyncService.swift`: Özel CloudKit veritabanı eşitlemesi ve ayrışmış kayıt algılamasını uygular.
- `StoreKitPurchaseService.swift`: StoreKit 2 ürün, doğrulama, satın alma ve geri yükleme akışını uygular.

## GamePresentation

- `GameStore.swift`: UI ile oyun motoru arasındaki MainActor köprüsü, otomatik yerel/bulut kayıt ve oyun içi bildirim durumlarını yönetir.
- `RootGameView.swift`: Dikey uygulama kabuğu, tıklanabilir para göstergesi, kasa ekranı, oyun içi bildirim ve Dükkân/İhale/İlanlar/Gelişim/Çıraklar/Banka/Mağaza geçişlerini sunar.
- `WorkshopView.swift`: Yeniden yüklenmeden çalışan araç seçimini, müşteri kuyruğunu, proje restorasyonunu ve kontrol, teşhis, parça, tamir/bakım, fiyat sıralı iş akışını gösterir.
- `AuctionView.swift`: Sabit ihale bedelli ağır hasarlı araçları, ayrıntılı ekspertiz ve yatırım hesabını ve satın alma akışını sunar.
- `VehicleInspectionDiagram.swift`: Ekspertiz panel durumlarını sade üstten 2B kaporta şemasında, taşıyıcı yapıyı ayrı rapor satırında ve VoiceOver özetiyle gösterir.
- `ProjectCarCard.swift`: Restorasyonu tamamlanan proje aracının ilan hazırlama ve yayındaki ilan durumlarını gösterir.
- `ProjectRestorationCard.swift`: İhale aracının mekanik, kaporta ve güvenlik eksiklerini ayrı maliyet ve mini oyun görevleri halinde gösterir.
- `ListingsView.swift`: Restorasyonu tamamlanan araçların fiyatlandırıldığı ve yayındaki alıcıların kontrol edildiği bağımsız ilan alanıdır.
- `WorkshopDevelopmentView.swift`: Dükkân seviyesini, tesisleri, kapasite yükseltmelerini, uzmanlığı ve itibarı Gelişim sayfasında gösterir.
- `ProgressViewScreen.swift`: Dükkân/ustalık gelişimini, yıldız puanını ve gelen müşteri yorumlarını tek bölümde gösterir.
- `ApprenticesView.swift`: Çırak kadrosunu, deneyimlerini, boş kadroyu ve işe alma işlemini ayrı bölümde sunar.
- `BankView.swift`: Kredi limiti, vade seçimi, taksit hesabı ve aktif borçları ayrı bölümde sunar.
- `ShopStoreView.swift`: Gerçek para ile alınabilen StoreKit oyun parası, kozmetik ve içerik ürünlerini ayrı mağazada sunar.
- `FinanceLedgerView.swift`: Üstteki para göstergesine dokunulduğunda kasa bakiyesi ve bütün gelir/gider hareketlerini açar.
- `RepairMiniGames.swift`: Altı genel bakım mekaniğini ve kayıştan göçük onarımına kadar on iki arızaya özgü, hedefleri iş kimliğine göre değişen mini oyunu içerir.
- `WorkshopScene.swift`: Kalıcı SpriteKit sahnesinde araçları kabul sırasıyla tek tek büyük gösterir; iPhone'da yatay sayfalama ve dokunarak iş seçimi sağlar.
- `Style.swift`: Paylaşılan renk, kart, düğme stilleri ve iPhone dokunsal geri bildirimini tanımlar.

## Testler

- `GameLogicTests.swift`: Determinizm, müşteri, teşhis, bakım, adım adım proje restorasyonu, yıkama, çırak, kredi/taksit, yatırım hesabı, ilan satışı, gider dökümü, kriz, satın alma ve sürüm 6 kayıt göçünü doğrular.
- `GameContentTests.swift`: İçerik sayısı, kontrol bağlantıları, yorumlar, benzersiz kimlik ve kapsama kurallarını doğrular.
