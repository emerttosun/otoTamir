# Oyun Tasarımı

Ana fantezi küçük bir sanayi dükkânını ustalıkla ve esnaflık kararlarıyla büyütmektir. Gün/saat tasarımı kesinleşene kadar oyun boşta kendi kendine ilerlemez; yalnız kontrol, parça, tamir, yıkama veya açıkça müşteri bekleme eylemleri zamanı ilerletir. Böylece uygulama açık bırakıldığı için para kaybedilmez. Oyuncu kısa vadeli nakit ile uzun vadeli dükkân itibarı arasında seçim yapar.

## Döngüler

- **Müşteri:** bekleyen müşteri, şikâyeti dinleme, araç kontrolleri, bulguyla bağlantılı teşhis, parçacı kataloğundan parça alma, fiyat söyleme ve gerekirse pazarlık, tamir mini oyunu, teslim, ödeme ve gecikmeli sonuç.
- **Yıllık bakım:** bakım seti alma, yağ/filtre, akü, lastik-fren ve sıvı kontrollerini uygun mini oyunlarla tamamlama.
- **Gelişim:** yapılan işlerden alan bazlı XP ve seviye, işçilik şöhreti, şaibe, dükkân puanı ve yorumlar, dükkân kabiliyetleri ve çıraklar.
- **Hasarlı araç pazarı:** sabit satış bedelli, sigorta çıkması ve eksper tarafından onarılabilir kabul edilmiş ağır hasarlı araç; kısa eksper özeti, isteğe bağlı üç inceleme, ustanın bulduğu ölçümler, belirsizlikli yatırım/kâr aralığı ve satın alma.
- **Dükkân sahnesi:** yalnız kabul edilen müşteri araçlarını geliş sırasına göre (FIFO) tek araçlık yatay sayfalarda gösterir; işlem paneli yalnız oyuncu araca dokunduğunda açılır.
- **Garaj ve proje restorasyonu:** Hasarlı'dan alınan araç bağımsız Garaj'a gider ve müşteri liftini işgal etmez. Proje araçları geliş sırasıyla tek araçlık yatay sayfalarda gösterilir. Her mekanik arıza, hasarlı veya eksik dış parça, şasi/podye/direk onarımı ve hava yastığı sistemi ayrı maliyetli bir iş ve uygun mini oyunla oyuncu tarafından tamamlanır.
- **İlan yeri:** restorasyonu biten araç için fiyat belirleme, satış ihtimali, ayrı ilan takibi ve dürüst veya riskli satış.
- **Finansman:** dükkân puanı ve gelişim seviyesine bağlı banka limiti; araç yatırımı için farklı faiz/vade seçenekleri ve eylem tabanlı taksitler.
- **Olay Defteri:** denetim, şikâyet, tavsiye, kredi, ilan, araç satışı ve çırak sonuçlarını para/itibar etkileriyle Gelişim ekranında kalıcı tutar.

Zorunlu ve uzun bir ilk üç gün eğitimi bulunmaz. Her üst sekme ilk kez açıldığında ne işe yaradığını anlatan tek, kapatılabilir oyun içi kart gösterir. Sonrasında oyun sonsuz ilerler. Mizah; abartılı teşhis, yanlış parça, çay sohbeti ve esnaf olayları üzerinden kurulur; kimlik veya dezavantaj üzerinden aşağılayıcı şaka kullanılmaz.

Motor, elektrik, yürüyen ve kaporta seviyeleri yalnız işçilik puanı vermez; ilgili seviyedeki yeni arıza havuzunu açar. En yüksek uzmanlık daha seçici müşterileri, dükkân seviyesiyle birlikte ortalama uzmanlık da daha geniş araç havuzunu getirir. Gelişim ekranı her alan için sırada açılacak işi gösterir.

## Müşteri ve fiyat davranışı

Müşteriler sabit bir günlük listede bulunmaz. Yapılan işlemler zamanı ilerlettikçe itibar ve dükkân puanına bağlı aralıklarla gelir, bekleme süresi dolunca kendiliğinden ayrılır ve kuyruk en fazla üç kişidir. Oyuncu istemediği müşteriyi ayrıca `Gönder` seçeneğiyle hemen reddedebilir; beklemek veya açıkça göndermek birlikte korunur. Bekleme süresi ayrı bir müşteri sabır statından değil, dükkân koşullarından hesaplanır. İş yoksa oyuncu açıkça müşteri beklemeyi seçebilir. Küçük dükkân aynı anda bir araç alır.

Her müşteri içerikte kişiliğiyle uyumlu üç adet `1...10` değere sahiptir: fiyat bilgisi pahalı teklifi fark etmeyi, teknik bilgi yanlış teşhis/düşük parça/kötü işçilik farkındalığını, pazarlık gücü ise karşı teklif davranışını belirler. Bu değerler tek bir genel hassasiyet statında birleştirilmez.

Fiyat parça satın alındıktan sonra, tamir başlamadan önce `Uygun`, `Normal`, `Yüksek` veya `Uçuk` olarak söylenir. Ekran parça bedelini, işçiliği, normal toplamı ve her seçeneğin istenen tutarını gösterir; ayrıntılı resmî fatura ilk sürüm kapsamına alınmaz. Müşterinin görünüşü ve davranış profili oyuncuya fiyat bilgisi ve pazarlık gücü hakkında kesin olmayan bir ipucu verir.

Müşteri fiyatı yüksek bulursa karşı teklif verir. Oyuncu karşı teklifi kabul eder, ortada buluşur veya kendi fiyatında diretir. Anlaşma sağlanınca tutar sabitlenir ve tamir başlar; tamir edilmiş araç için sonradan işi iptal etme akışı oluşmaz. Teslimde kasaya giren para anlaşılmış son tutardır. İlk istenen fiyat ile son ödenen fiyat müşteri değerlendirmesinde ayrı ayrı dikkate alınabilir; uçuk başlayıp pazarlıkla düşmek müşterinin yorumunu etkileyebilir fakat tek başına şaibe sayılmaz.

Araç kabul edildiğinde iş türü, kontrol adımları ve arıza zorluğundan kesin bir oyun içi teslim hedefi üretilir; oyuncuya gün ve saat olarak gösterilir. Hedefe kadar teslim normaldir, ilk iki saatlik aşım gecikmiş, daha büyük aşım çok gecikmiş sayılır. Gecikme nihai müşteri deneyimini düşürür. Teslime hazır araç teslim edilene kadar aktif iş olarak kalır ve müşteri liftini işgal eder; ayrı bir müşteri sabır statı bulunmaz.

Teslimde işçilik, kullanılan parça, parçanın gizlenip gizlenmediği, ilk ve son fiyat ile yıkama tek bir müşteri deneyimi puanında birleşir. Fiyat bilgisi ilk ve son hesabın yorumlanmasını, teknik bilgi ise kötü işçilik veya gizlenen kaliteyi fark etme ihtimalini belirler. Çok iyi ve çok kötü deneyimler daha sık, sıradan deneyimler daha seyrek yorum doğurur. Aynı müşteri aynı teslim için yalnız bir bütüncül yorum bırakabilir. Yıkama seviyesine göre sonuca en fazla iki küçük artı ekler; kötü tamiri veya gizlenen parçayı iyi deneyime çeviremez.

İlk sürümde parça deposu bulunmaz; bütün parçalar iş emri için parçacı kataloğundan sipariş edilir. Oyuncu tamir başlamadan fiyatında diretir ve müşteri kabul etmeyip ayrılırsa alınan parça otomatik olarak parçacıya döner. Alış bedelinin `%90`ı kasaya iade edilir, `%10` kesinti ayrı kasa hareketi olarak görünür. Tamir başladıktan sonra müşteri işi iptal edemez.

## Arızaya özgü mini oyunlar

- Gösterge: hareketli ibreyi doğru aralıkta durdurma.
- Civata: bağlantıları doğru sıra ve sıkılıkta tamamlama.
- Elektrik: doğru hattı ve soketi eşleştirme.
- Hizalama: parçayı doğru yatay ve dikey konuma getirme.
- Sıvı dolumu: hedef seviyeye taşırmadan kontrollü dolum yapma.
- Zamanlama: üç kasnak üzerindeki derece işaretlerini doğru konuma çevirme.

Genel altı mekanik yıllık bakım ve proje araçlarında tekrar kullanılabilir. Otuz müşteri arızasının her biri ayrıca benzersiz bir oyun kimliği kullanır. Mevcut mekanikler; kayış gerginliği, hava alma, tork sırası, akü kutupları, şarj voltajı, sensör boşluğu, fren-balata, rot, debriyaj, kaporta hizalama ve göçük işlerine ek olarak buji aralığı, bobin sırası, enjektör dönüş dengesi, pompa contası, triger işaretleri, turbo basıncı, UV yağ izi, sigorta ve kablo sürekliliği, cam krikosu, far ayarı, disk salgısı, amortisör geri dönüşü, rulman ön yükü, aks körüğü gres dağılımı, kaput aralığı, nokta kaynak ve boya katmanlarını kapsar.

Sistem uyarısı veya ayrı iPhone penceresi açılmaz; oyunlar dükkân ekranının üzerinde oyun içi çalışma alanı olarak görünür. İş kimliğinden üretilen hedefler değişir; başarı hızdan çok doğru sıra, ölçü, denge ve son kontrolden hesaplanır.

## Dükkân, yıkama ve çırak

- Seviye 1: temel lift ve tek müşteri aracı kapasitesi; proje Garajı kapalıdır.
- Seviye 2: ikinci lift, oturma alanı, yıllık bakım, ilk çırak tezgâhı ve bir proje araçlık Garaj.
- Dükkân Seviye 3'te bağımsız yıkama gelişimi açılır. Yıkama Seviye 1 temel dış yıkama, Seviye 2 iç-dış detaylı temizlik, Seviye 3 premium teslim sunar; ilerledikçe işlem süresi ve sarf maliyeti düşer, dükkân puanına küçük katkısı artar.
- Seviye 4: üç müşteri aracı kapasitesi, iki proje araçlık Garaj, ikinci çırak ve kontrolleri hızlandıran teşhis laboratuvarı.
- Seviye 5: iki proje araçlık Garaj ve hasarlı araç restorasyon giderini azaltan kaporta-boya kabini.
- Seviye 6: dört müşteri aracı kapasitesi, üç proje araçlık Garaj, detaylı temizlik ve üçüncü çırak.
- Seviye 7: beş müşteri aracı kapasitesi, dört proje araçlık Garaj, dört çırak ve ilan satış ihtimalini yükselten araç vitrini.

Oyuncu kabul edilmiş bir aracı çırağa devretmeden önce parça kalitesini belirler. Çırak kendi yeterliliğine göre kontrol ve teşhisi yapar, parçacı siparişini hazırlar ve fiyat kararı için ustayı bekler. Müşteriyle fiyatı yalnız usta konuşur; anlaşmadan sonra çırak tamiri oyun saati içinde arka planda sürdürürken oyuncu başka araçla ilgilenebilir. Fiyatlandırma ve teslim daima ustada kalır. Çırak başlangıçta ustadan daha düşük ve değişken performans gösterir; tamamladığı bütün işlerden XP kazanıp alan seviyesi açar. Araç teslimden önce mevcut yıkama seviyesinde temizlenebilir; o seviyenin sarf maliyetini ve süresini kullanır, temiz teslim seviyesine göre dükkân puanına küçük katkı sağlar.

## Ağır hasarlı araç raporu

Teklif turu bulunmaz. Her araçta başlangıçta yalnız sabit alış fiyatı, onarılabilir ağır hasar durumu, genel darbe bölgesi, çalışır-yürür bilgisi, airbag durumu ve kayıtlı hasar tutarı görünür. Oyuncu satın almadan önce `Kaporta taraması`, `Alt ve taşıyıcı ölçümü` ve `Motor, elektrik ve güvenlik` kontrollerinden istediğini yaptırır; her biri ayrı oyun zamanı tüketir. Kaporta kontrolü görünen dış parçaları, diğer kontroller ise ustalık ve dükkân ekipmanına bağlı olasılıkla mekanik ve yapısal kusurları açar. Kontroller tamamlandığında dahi düşük gizli kusur riski kalır; satın alınan aracın gerçek eksikleri Garaj'daki söküm ve restorasyon listesinde ortaya çıkar. Sol-sağ şasi kolları, podyeler, amortisör kuleleri, A/B/C direkleri, ön-arka panel ve bagaj havuzu yalnız ölçülmüşse ayrı satırlarda raporlanır; ölçülmeyen bölge sağlammış gibi gösterilmez.

Tam hasarlı ve hurda tescilli araçlar onarım kabul etmediği için oyuncuya satılmaz. Oyun pazarı yalnız onarımı mümkün ağır hasarlı araçları kapsar. Ağır hasar üretiminde onarım maliyetinin araç rayicinin en az %60'ına ulaşması veya kritik yapısal hasar bulunması esas alınır.

Ekspertizde `Usta Hesabı` bölümü; o ana kadar bulunan kusurlardan tahmini onarım giderini, alış dahil toplam yatırımı, adil satış bandını ve kötümser/iyimser kâr aralığını gösterir. Yapılan her kontrol belirsizlik aralığını daraltır fakat kâr garantisi vermez. Restorasyondan sonra oyuncu adil fiyat önerisini görür, ilan fiyatını belirler ve fiyat yükseldikçe düşen tahmini satış ihtimalini izler. Alıcı kontrolü aracı otomatik satmaz. İsimli teklifler ilanın altında birikir; oyuncu teklifi kabul eder, reddeder veya ilan fiyatını aşmadan karşı fiyat gönderir. Karşı fiyat alıcının gizli limitine yakınsa alıcı üst sınırıyla pazarlığa devam eder, çok yüksekse çekilir.

Satın alma sonrası Garaj'da zorunlu kusurlardan ayrı olarak `orta durumda` yıpranmış parçalar da gösterilir. Bunlar değiştirilmeden araç satışa çıkabilir; oyuncu minimum restorasyon için bırakabilir veya parça ve işçilik bedelini ödeyip mini oyunla yenileyebilir. İsteğe bağlı yenilemeler restorasyon kondisyonunu ve adil satış değerini yükseltir, fakat harcanan paranın tamamının satışta geri döneceğini garanti etmez.

## Banka kredisi

Kredi limiti dükkân seviyesi ve dükkân puanıyla büyür. Kısa, dengeli ve esnek vadeler sırasıyla daha yüksek taksit/düşük faiz ile daha düşük taksit/yüksek faiz arasında seçim sunar. Kalan borç kullanılabilir limitten düşer. Taksitler gerçek zamanla veya uygulama açık kaldığı için işlemez; yalnız oyun içi eylemler ödeme tarihini geçtiğinde otomatik tahsil edilir ve kasa hareketlerinde ayrı görünür.

Para göstergesinden açılan finans ekranı geçmiş günleri tutan bir muhasebe sayfası değildir; yalnız mevcut oyun gününü özetler. Tamir/araç satış geliri, parça/işletme gideri, işletme sonucu, yeni kredi, kredi taksiti, net nakit değişimi ve güncel kasa ayrı görünür. Kredi anaparası kasayı artırsa da işletme geliri veya kâr olarak hesaplanmaz.

`Güven` ayrı bir sayaç değildir. Oyuncuya görünen uzun vadeli müşteri algısı tek dükkân puanı ve yorum geçmişiyle temsil edilir; teknik kalite algısı işçilik şöhretinde, dürüstlük riski şaibede kalır. Sürüm 14 ve daha eski kayıtlardaki güven ilerlemesi, başlangıç değeri korunacak şekilde dükkân puanına aktarılır.

Rapor kapsamı; gerçek ekspertizlerde kullanılan kaporta-boya, şasi/podye/direk, airbag, motor-mekanik, fren, süspansiyon ve OBD başlıklarından esinlenir. Ağır ve tam hasar ayrımı SEDDK 2025/12 Genelgesi esas alınarak oyunlaştırılır. Kaynaklar: [SEDDK ağır ve tam hasar genelgesi](https://www.tsb.org.tr/content/Legislations/Motorlu%20Ara%C3%A7%20Sigortalar%C4%B1%20Kapsam%C4%B1nda%20Tam%20Hasara%20Ya%20Da%20A%C4%9F%C4%B1r%20Hasara%20U%C4%9Fram%C4%B1%C5%9F%20Ara%C3%A7lar%C4%B1n%20Tespiti%20Hakk%C4%B1nda%20Genelge%20202512.pdf), [Ticaret Bakanlığı ikinci el taşıt yönetmeliği](https://ietts.gtb.gov.tr/Home/Yonetmelik?v=1.0.26), [örnek kaporta ekspertiz raporu](https://cdn.zugo.live/File/AracHavuzDosya/131/3DB736C4-E5BB-4E67-B08E-56C3FBA5F833/3C013D0E-4685-4B37-9855-612C46A24531.pdf).
