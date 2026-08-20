import Foundation

enum GameSection: String, CaseIterable, Identifiable {
    case workshop
    case auction
    case garage
    case listings
    case progress
    case apprentices
    case bank
    case store

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workshop: "Dükkân"
        case .auction: "Hasarlı"
        case .garage: "Garaj"
        case .listings: "İlanlar"
        case .progress: "Gelişim"
        case .apprentices: "Çıraklar"
        case .bank: "Banka"
        case .store: "Mağaza"
        }
    }

    var icon: String {
        switch self {
        case .workshop: "wrench.and.screwdriver.fill"
        case .auction: "car.side.rear.open.fill"
        case .garage: "building.2.crop.circle.fill"
        case .listings: "rectangle.and.pencil.and.ellipsis"
        case .progress: "chart.line.uptrend.xyaxis"
        case .apprentices: "person.2.fill"
        case .bank: "building.columns.fill"
        case .store: "bag.fill"
        }
    }

    var introduction: String {
        switch self {
        case .workshop:
            "Bekleyen müşterileri kabul et. Dükkândaki araca dokunarak kontrol, teşhis, parça, tamir ve teslim işlemlerini yap."
        case .auction:
            "Ağır hasarlı araçları ekspertiz raporu ve Usta Hesabı ile incele; Garaj kapasiten uygunsa sabit bedelle satın al."
        case .garage:
            "Hasarlı'dan aldığın proje araçlarını geliş sırasıyla yönet. Her eksiği ayrı tamamla; hazır aracı İlanlar'da satışa çıkar."
        case .listings:
            "Restorasyonu biten araçlara fiyat belirle. Fiyat yükseldikçe satış ihtimali düşer; alıcılar oyun içi işlemlerle zaman ilerledikçe gelir."
        case .progress:
            "Dükkânı geliştir; motor, elektrik, yürüyen ve kaporta ustalığını, puanını, yorumları ve Olay Defteri'ni takip et."
        case .apprentices:
            "Çırak ilanı verip adayları değerlendir. İş ve yıkama verdikçe alan seviyeleri, mutluluğu ve zamanla tanıdığın kişisel özellikleri gelişir."
        case .bank:
            "Dükkân seviyesi ve puanına bağlı limitten araç yatırım kredisi kullan; faiz, taksit ve kalan borcu buradan izle."
        case .store:
            "Oyun parası ve kozmetik ürünler burada bulunur. Satın alma yalnız ilerlemeyi hızlandırır; ustalık ve iyi işçilik satılmaz."
        }
    }
}
