import Foundation

enum GameSection: String, CaseIterable, Identifiable {
    case workshop
    case auction
    case listings
    case progress
    case apprentices
    case bank
    case store

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workshop: "Dükkân"
        case .auction: "İhale"
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
            "Ağır hasarlı araçları ekspertiz raporu ve Usta Hesabı ile incele; sabit bedelle satın alıp dükkânda topla."
        case .listings:
            "Restorasyonu biten araçlara fiyat belirle. Fiyat yükseldikçe satış ihtimali düşer; alıcılar oyun içi işlemlerle zaman ilerledikçe gelir."
        case .progress:
            "Dükkânı geliştir; motor, elektrik, yürüyen ve kaporta ustalığını, puanını, yorumları ve Olay Defteri'ni takip et."
        case .apprentices:
            "Dükkânda tezgâh açıldığında çırak al. Tamir veya bakım adımı verdikçe çırak tecrübe kazanır."
        case .bank:
            "Dükkân puanı ve güvene bağlı limitten araç yatırım kredisi kullan; faiz, taksit ve kalan borcu buradan izle."
        case .store:
            "Oyun parası ve kozmetik ürünler burada bulunur. Satın alma yalnız ilerlemeyi hızlandırır; ustalık ve iyi işçilik satılmaz."
        }
    }
}
