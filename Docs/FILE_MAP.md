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
- `ContentModels.swift`: JSON'dan gelen araç, ortak parçaya kimlikle bağlanan arıza, müşteri, yorum, dükkân ve üç seviyeli yıkama gelişimi ile ayrıntılı gider dengelerini tanımlar.
- `PartModels.swift`: Tekil parçaların kategori, taban fiyat ve bakım/normal tamire göre kalite profilini; bakım görevlerinin parça ve işçilik eşlemesini tanımlar.
- `GameModels.swift`: Sürüm 14 `GameState` kayıt kökünü, kişilikli çırakları, kaybedilen müşteri havuzunu, alan bazlı yetkinliği ve eylem tabanlı zamanı tanımlar.
- `RepairModels.swift`: Müşteri teklifi, iş emri, parça kalitesi, bakım, ustalık ve itibar modellerini toplar.
- `ApprenticeModels.swift`: Çırak geçmişini, beş gizli özelliği, mutluluğu, sadık müşterileri, ayrılık uyarısını, görev sayısını ve dört alandaki ilerlemeyi tanımlar.
- `FinanceModels.swift`: Kredi, kasa hareketi, yorum, envanter ve gecikmeli sonuç modellerini tanımlar.
- `VehicleTradingModels.swift`: Onarılabilir ağır hasarlı araç, dış panel, ayrıntılı şasi/podye/direk ölçümü, restorasyon görevi ve ilan durumunu tanımlar.
- `IncidentModels.swift`: Denetim, şikâyet, kredi, ilan ve benzeri dükkân olaylarını para ve itibar etkileriyle sürümlü kayda uygun tanımlar.
- `GameContracts.swift`: Komut, olay, hata ve kayıt/bulut/satın alma portlarını tanımlar.

## GameLogic ve GameContent

- `SeededRandomSource.swift`: Kayıt seed'inden tekrar üretilebilir rastgele sayı ve kimlik üretir.
- `BankingRules.swift`: Dükkân durumundan kredi limitini, vade faizini ve taksit tutarını deterministik hesaplar.
- `WashBayRules.swift`: Yıkama bölümünün mevcut ve sıradaki veri tanımını, dükkân ve para yükseltme şartlarını değerlendirir.
- `ApprenticeRules.swift`: Çırağın alan seviyesine göre yapabileceği işleri; kişilik, mutluluk ve çalışma hızına bağlı iş performansını belirler.
- `VehicleTradingRules.swift`: Hasarlı araç yatırım aralığını, restorasyon maliyetini, adil ilan fiyatını ve satış ihtimalini deterministik hesaplar.
- `ProgressionRules.swift`: Alan uzmanlığı ve dükkân seviyesinden açık arıza, müşteri ve araç havuzunu deterministik hesaplar.
- `PartPricingRules.swift`: Bakım görevlerinden değişecek benzersiz parçaları bulur; kalite katsayısı ve görev bazlı işçilik tutarlarını tek merkezde hesaplar.
- `CustomerPricingRules.swift`: Tamir öncesi gösterilen parça, işçilik, normal toplam ve fiyat stratejilerinin istenen tutarlarını tek merkezde hesaplar.
- `CustomerNegotiationRules.swift`: Müşterinin fiyat bilgisi ve pazarlık gücünden fark etme, karşı teklif, orta yol ve diretme olasılığını deterministik hesaplar.
- `GameEngine.swift`: Komutları doğrular ve ilgili kural uzantısına yönlendiren küçük oyun motoru girişidir.
- `GameEngine+Workshop.swift`: Kontrol, teşhis, parça, tamir, fiyat, `%10` kesintili parçacı iadesi, usta/çırak yıkaması ve seviye kontrollü çırak iş akışını yürütür.
- `GameEngine+Apprentices.swift`: Çırak ilanı, deterministik aday üretimi, işe alım, prim, günlük bağlılık kontrolü, ayrılık uyarısı ve müşteri götürme akışını yürütür.
- `GameEngine+World.swift`: Eylem tabanlı saat, gider, kredi ve dükkân gelişimini yürütür.
- `GameEngine+Trading.swift`: Hasarlı araç alımı, restorasyon, ilan ve satış akışını yürütür.
- `GameEngine+Content.swift`: Deterministik müşteri/içerik seçimi, itibar, yorum ve gecikmeli sonuç üretir.
- `GameEngine+Support.swift`: Para yüzdesi, tesis kontrolü ve kayıt defteri gibi ortak saf yardımcıları tutar.
- `DefaultContentRepository.swift`: Paket JSON'unu yükler ve bütünlük kurallarını doğrular.
- `Resources/catalog.json`: 12 araç, benzersiz tamir oyunlu 30 arıza, bakım ve normal tamirde kullanılan 36 ortak parça, bakım görev eşlemeleri, 20 müşteri, üçlü şikâyet anlatımları, 26 yorum ve yedi dükkân seviyesini koddan bağımsız tutar.

## Apple servis adaptörleri

- `JSONFileSaveRepository.swift`: Atomik yerel kayıt, yedek okuma ve sürümlü kayıt göçünü uygular.
- `CloudKitSyncService.swift`: Özel CloudKit veritabanı eşitlemesi ve ayrışmış kayıt algılamasını uygular.
- `StoreKitPurchaseService.swift`: StoreKit 2 ürün, doğrulama, satın alma ve geri yükleme akışını uygular.

## GamePresentation

- `GameStore.swift`: UI ile oyun motoru arasındaki MainActor köprüsü, otomatik yerel/bulut kayıt ve oyun içi bildirim durumlarını yönetir.
- `RootGameView.swift`: Dikey uygulama kabuğu, tıklanabilir para göstergesi, kasa ekranı, oyun içi bildirim ve Dükkân/İhale/İlanlar/Gelişim/Çıraklar/Banka/Mağaza geçişlerini sunar.
- `GameSection.swift`: Üst gezinti sekmelerinin başlık, simge ve tek seferlik kısa tanıtım metinlerini tanımlar.
- `SectionIntroductionCard.swift`: Bir sekme ilk kez açıldığında akışı kilitlemeden kısa kullanım açıklamasını gösterir.
- `WorkshopView.swift`: Yeniden yüklenmeden çalışan araç seçimini, müşteri kuyruğunu, proje restorasyonunu ve kontrol, teşhis, parça, tamir/bakım, fiyat sıralı iş akışını gösterir.
- `AuctionView.swift`: Sabit ihale bedelli ağır hasarlı araçları, ayrıntılı ekspertiz ve yatırım hesabını ve satın alma akışını sunar.
- `VehicleInspectionDiagram.swift`: Hasarlı veya eksik dış parçaları sade üstten 2B kaporta şemasında; şasi, podye, kule, direk, panel ve bagaj havuzunu ayrı metin satırlarında ve VoiceOver özetiyle gösterir.
- `RestoredBodyHistoryView.swift`: İlan hazırlığında ve yayındaki ilanda restorasyon sonrası boyalı/değişen parçaları, yapısal onarımları ve airbag geçmişini açılır bölümde gösterir.
- `VehicleBuyerOfferCard.swift`: Gelen araç teklifini kabul etme, reddetme ve alıcının bütçesine karşı fiyatla pazarlık yapma arayüzünü sunar.
- `ProjectCarCard.swift`: Restorasyonu tamamlanan proje aracının ilan hazırlama ve yayındaki ilan durumlarını gösterir.
- `ProjectRestorationCard.swift`: İhale aracının mekanik, kaporta, taşıyıcı yapı ve güvenlik eksiklerini ayrı maliyet ve mini oyun görevleri halinde gösterir.
- `ListingsView.swift`: Restorasyonu tamamlanan araçların fiyatlandırıldığı ve yayındaki alıcıların kontrol edildiği bağımsız ilan alanıdır.
- `WorkshopDevelopmentView.swift`: Dükkân seviyesini, tesisleri, kapasite yükseltmelerini, uzmanlığı ve itibarı Gelişim sayfasında gösterir.
- `ProgressViewScreen.swift`: Dükkân/ustalık gelişimini, yıldız puanını ve gelen müşteri yorumlarını tek bölümde gösterir.
- `ApprenticesView.swift`: Çırak kadrosunu, deneyimlerini, boş kadroyu ve işe alma işlemini ayrı bölümde sunar.
- `BankView.swift`: Kredi limiti, vade seçimi, taksit hesabı ve aktif borçları ayrı bölümde sunar.
- `ShopStoreView.swift`: Gerçek para ile alınabilen StoreKit oyun parası, kozmetik ve içerik ürünlerini ayrı mağazada sunar.
- `FinanceLedgerView.swift`: Üstteki para göstergesine dokunulduğunda kasa bakiyesi ve bütün gelir/gider hareketlerini açar.
- `RepairMiniGames.swift`: Tamir isteğini ilgili mini oyun ailesine yönlendiren sunum girişidir.
- `RepairMiniGames/CommonMiniGames.swift`: Gösterge, civata, kablo ve hizalama gibi yeniden kullanılabilir temel mekanikleri tutar.
- `RepairMiniGames/MaintenanceMiniGames.swift`: Sıvı dolumu ve zamanlama bakım oyunlarını tutar.
- `RepairMiniGames/EngineMiniGames.swift`: Motor ve elektrik arızalarına özel tamir oyunlarını tutar.
- `RepairMiniGames/ChassisMiniGames.swift`: Fren, rot ve debriyaj oyunlarını tutar.
- `RepairMiniGames/BodyMiniGames.swift`: Tampon, kapı ve göçük kaporta oyunlarını tutar.
- `RepairMiniGames/AdvancedEngineMiniGames.swift`: Buji, enjektör, devirdaim, turbo ve yağ kaçağı işlemlerini canlandırır.
- `RepairMiniGames/AdvancedElectricalMiniGames.swift`: Bobin, sigorta, kablo sürekliliği, cam krikosu ve far ayarı işlemlerini canlandırır.
- `RepairMiniGames/AdvancedChassisMiniGames.swift`: Disk salgısı, amortisör, rulman ve aks körüğü işlemlerini canlandırır.
- `RepairMiniGames/AdvancedBodyMiniGames.swift`: Kaput hizalama, nokta kaynak ve boya katmanı işlemlerini canlandırır.
- `WorkshopScene.swift`: Kalıcı SpriteKit sahnesinde araçları kabul sırasıyla tek tek büyük gösterir; iPhone'da yatay sayfalama ve dokunarak iş seçimi sağlar.
- `Style.swift`: Paylaşılan renk, kart, düğme stilleri ve iPhone dokunsal geri bildirimini tanımlar.

## Testler

- `GameLogicTests.swift`: Determinizm, müşteri, teşhis, bakım, adım adım proje restorasyonu, üç seviyeli yıkama, çırak, kredi/taksit, olay defteri, yatırım hesabı, teklif/pazarlık, gider dökümü, kriz, satın alma ve sürüm 10 kayıt göçünü doğrular.
- `GameContentTests.swift`: İçerik sayısı, kontrol bağlantıları, yorumlar, benzersiz kimlik ve kapsama kurallarını doğrular.
