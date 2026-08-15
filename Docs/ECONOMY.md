# Ekonomi ve Denge

Bütün tutarlar kuruş cinsinden `Int64` olarak saklanır. Başlangıç değerleri `catalog.json` içindeki balance bölümündedir.

- Parça maliyeti: çıkma `%55`, yan sanayi `%100`, orijinal `%140`.
- Fiyat stratejisi: uygun `%85`, normal `%100`, yüksek `%135`, uçuk `%180`.
- İşçilik ve parça güvenilirliği tekrar arıza ihtimalini etkiler.
- Hileli davranışlar anında kazanç sağlar; dükkân puanı/yorum, şikâyet ve denetim sonraki takvim günlerinde uygulanır.
- Para sıfırın altına inebilir ancak oyun bitmez. Böylece kriz cezalı fakat toparlanabilirdir.
- Dükkân boşta açık kaldığında zaman ilerlemez ve gider yazılmaz. Takvim gideri yalnız oyuncu eylemi yeni güne geçtiğinde oluşur.
- Günlük gider; kira, elektrik-su/enerji ve sarf-temizlik olarak ayrı kasa hareketlerine yazılır. Çırak ücretleri kişi başı ayrıca görünür.
- Yıkama, çırak işe alımı, hasarlı araç alımı ve restorasyon parçaları da ayrı gider kategorileridir.
- Parça deposu parça alış maliyetini, kaporta-boya kabini proje araç restorasyon giderini azaltır; satış vitrini ilanların alıcı ihtimalini yükseltir.
- Banka limiti dükkân seviyesi, güven ve dükkân puanından hesaplanır. Üç vadede toplam faiz baştan görünür; kalan borç limiti meşgul eder ve taksitler yalnız oyun zamanı ilerlediğinde tahsil edilir.
- Hasarlı araç raporu tek kâr rakamı vermez: onarım, toplam yatırım, adil satış ve olası kâr/zarar aralıkları gösterilir.
- Restorasyon sonrası araç doğrudan satılmaz. İlan fiyatı adil fiyatın üzerine çıktıkça satış ihtimali düşer; her ilan yayını sabit bir ilan gideri üretir.
- Parçacı en fazla 10.000 ₺ veresiye parça verir; kasa -5.000 ₺ altına düşerse gün sonunda çalışmayı sürdürecek seviyede esnaf avansı açılır.
- Gerçek para paketleri yalnız nakit sağlar; uzmanlık, itibar ve kalite sonucu satın alınamaz.

Denge değerleri koddan bağımsız içerik dosyasında tutulur ve içerik doğrulama testinden geçer.
