# Ekonomi ve Denge

Bütün tutarlar kuruş cinsinden `Int64` olarak saklanır. Başlangıç değerleri `catalog.json` içindeki balance bölümündedir.

Fiyatlar tek bir gerçek marka veya modele ait canlı teklif değildir. 16 Ağustos 2026 tarihinde düşük/orta segment bir araç için göreli büyüklükler; [Ankara Ticaret Odası 2026 oto tamir ve kaporta azami işçilik tarifesi](https://www.atonet.org.tr/Uploads/Birimler/Internet/Hizmetlerimiz/Azami%20Fiyat%20Tarifleri/2026_azami_fiyat_tarifesi/2026_oto_tamir_iscilik_2026_05_18_v2.pdf), [Otopratik servis fiyat listesi](https://www.otopratik.com.tr/servis-fiyat-listesi) ve [ServiGO kaporta-boya listesi](https://servigo.com/kaporta-boya) referans alınarak dengelenmiştir. Amaç piyasa fiyatını birebir takip etmek değil; yağın filtreden, fren diskinin balatadan, trigerin aksesuar kayışından ve panel değişiminin küçük bağlantı setinden anlamlı ölçüde pahalı kalmasıdır.

- Normal tamir parçası maliyeti: çıkma `%55`, yan sanayi `%100`, orijinal `%140`.
- Bakım sarflarında çıkma ürün bulunmaz: ekonomik `%85`, standart `%100`, premium `%135` kullanılır. Kayıt uyumluluğu için bu seçenekler içeride aynı üç kalite kimliğini korur, oyuncuya hizmete uygun adla gösterilir.
- Yıllık bakımda motor yağı, yağ filtresi, hava filtresi, polen filtresi, antifriz ve fren hidroliği ayrı katalog kayıtlarıdır. Her kaydın kendi taban fiyatı vardır.
- Bakım görevi hangi parçaları değiştirdiğini ve kendi işçilik değerini katalogda belirtir. Akü ölçümü ile lastik/fren kontrolü yalnız kontrol bedeli üretir; otomatik parça bedeli eklemez.
- Bakım parça alış tutarı, seçili görevlerin benzersiz parçalarının taban fiyat toplamına kalite katsayısı uygulanarak hesaplanır. İlk sürümde parça deposu ve depo indirimi bulunmaz.
- Normal müşteri bedeli gerçek parça alış tutarı ile seçili bakım görevlerinin işçilik toplamıdır; uygun/normal/yüksek/uçuk stratejisi bunun üzerine tamir başlamadan önce uygulanır.
- Normal arızalar da aynı ortak `parts` kataloğuna `partID` ile bağlanır. Arıza kaydında ikinci bir parça adı veya fiyatı tutulmaz; müşteri işi, Hasarlı yatırım hesabı ve restorasyon aynı fiyat kaynağını kullanır.
- Fiyat stratejisi: uygun `%85`, normal `%100`, yüksek `%135`, uçuk `%180`.
- Fiyat ekranı gerçek parça alış tutarını, katalogdan gelen işçiliği ve normal toplamı ayrı gösterir. Dört fiyat seçeneğinde müşteriden istenecek tutar önceden görünür. Fiyat bilgisi yüksek müşteri pahalı teklifi sorgularsa pazarlık açılır; karşı teklifi kabul etme, ortada buluşma veya kendi fiyatında diretme sonucunda kesin tutar belirlenir. Tamir bu anlaşmadan sonra başlar ve teslimde kasaya yalnız anlaşılmış tutar girer.
- İlk istenen tutar ile pazarlık sonunda ödenen tutar müşteri değerlendirmesinde birlikte kullanılabilir. Yüksek fiyat söylemek tek başına şaibe değildir; gizlenen parça kalitesi ve benzeri dürüstlük ihlalleri ayrı risk üretir.
- Müşteri yorumu işçilik, parça, ilk/son fiyat ve yıkamadan tek seferde hesaplanır. Teknik bilgisi yüksek müşterinin kötü işçiliği veya gizlenen parçayı fark etme ihtimali artar; yıkama yalnız bir değerlendirme puanı kadar küçük katkı sağlar.
- Müşteri tamir başlamadan fiyat yüzünden ayrılırsa satın alınan parça parçacıya otomatik iade edilir. Alış bedeli pozitif `Parça iadesi`, `%10` kesinti negatif `Parça iade kesintisi` olarak iki kasa hareketine yazılır; kasaya net `%90` döner.
- İşçilik ve parça güvenilirliği tekrar arıza ihtimalini etkiler.
- Hileli davranışlar anında kazanç sağlar; dükkân puanı/yorum, şikâyet ve denetim sonraki takvim günlerinde uygulanır.
- İşletme giderleri kasayı zorlayabilir ancak karşılanamayan kredi taksiti kasadan çekilmiş veya ödenmiş sayılmaz; `Gecikmiş Borç` olarak tutulur. Kasaya yeniden para girdiğinde önce bu borç kapatılır.
- Dükkân boşta açık kaldığında zaman ilerlemez ve gider yazılmaz. Takvim gideri yalnız oyuncu eylemi yeni güne geçtiğinde oluşur.
- Günlük gider; kira, elektrik-su/enerji ve sarf-temizlik olarak ayrı kasa hareketlerine yazılır. Çırak ücretleri kişi başı ayrıca görünür.
- Yıkama, çırak işe alımı, hasarlı araç alımı ve restorasyon parçaları da ayrı gider kategorileridir.
- Kaporta-boya kabini proje araç restorasyon giderini azaltır; satış vitrini ilanların alıcı ihtimalini yükseltir.
- Banka limiti dükkân seviyesi ve dükkân puanından hesaplanır. Üç vadede toplam faiz baştan görünür; kalan borç limiti meşgul eder ve taksitler yalnız oyun zamanı ilerlediğinde tahsil edilir. Gecikmiş borç varken yeni kredi kullanılamaz.
- Gecikmiş borç 100.000 ₺ eşiğine ulaşırsa banka önce proje araçlarını, ardından yıkama ekipmanını ve kapasite uygunsa dükkân seviyesini indirimli tasfiye değeriyle satar. Satılabilir varlık kalmadığında kalan krediler 24 düşük taksitli, yedi oyun günü aralıklı uzun vadeli plana yapılandırılır. Bu akış ücretsiz para üretmez; eski `Esnaf desteği` kategorisi yalnız geçmiş kayıtları okuyabilmek için korunur.
- Hasarlı araç raporu tek kâr rakamı vermez: onarım, toplam yatırım, adil satış ve olası kâr/zarar aralıkları gösterilir.
- Restorasyon sonrası araç doğrudan satılmaz. İlan fiyatı adil fiyatın üzerine çıktıkça satış ihtimali düşer; her ilan yayını sabit bir ilan gideri üretir.
- Gerçek para paketleri yalnız nakit sağlar; uzmanlık, itibar ve kalite sonucu satın alınamaz.

Denge değerleri koddan bağımsız içerik dosyasında tutulur ve içerik doğrulama testinden geçer. Yeni bir bakım parçası eklenirken `parts` kaydı oluşturulur, ilgili `maintenanceServices.partIDs` listesine kimliği eklenir; hesaplama kodunun değiştirilmesi gerekmez.
