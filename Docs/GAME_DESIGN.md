# Oyun Tasarımı

Ana fantezi küçük bir sanayi dükkânını ustalıkla ve esnaflık kararlarıyla büyütmektir. Gün/saat tasarımı kesinleşene kadar oyun boşta kendi kendine ilerlemez; yalnız kontrol, parça, tamir, yıkama veya açıkça müşteri bekleme eylemleri zamanı ilerletir. Böylece uygulama açık bırakıldığı için para kaybedilmez. Oyuncu kısa vadeli nakit ile uzun vadeli güven arasında seçim yapar.

## Döngüler

- **Müşteri:** bekleyen müşteri, şikâyeti dinleme, araç kontrolleri, bulguyla bağlantılı teşhis, parça alma, tamir mini oyunu, fiyat seçimi, ödeme ve gecikmeli sonuç.
- **Yıllık bakım:** bakım seti alma, yağ/filtre, akü, lastik-fren ve sıvı kontrollerini uygun mini oyunlarla tamamlama.
- **Gelişim:** yapılan işlerden alan bazlı XP ve seviye, ustalık/güven/şaibe, dükkân puanı ve yorumlar, dükkân kabiliyetleri ve çıraklar.
- **Hasarlı araç ihalesi:** sabit ihale bedelli ağır hasarlı araç, üstten siluet üzerinde tam ekspertiz raporu, yatırım/kâr aralığı ve satın alma.
- **Dükkân sahnesi:** kabul edilen müşteri araçlarını ve satın alınan proje araçlarını geliş sırasına göre (FIFO) tek araçlık yatay sayfalarda gösterir; işlem paneli yalnız oyuncu araca dokunduğunda açılır.
- **Proje restorasyonu:** ihale aracı tek düğmeyle bitmez. Her mekanik arıza, hasarlı/boyalı/değişen kaporta parçası ve hava yastığı sistemi ayrı maliyetli bir iş ve uygun mini oyunla oyuncu tarafından tamamlanır.
- **İlan yeri:** restorasyonu biten araç için fiyat belirleme, satış ihtimali, ayrı ilan takibi ve dürüst veya riskli satış.
- **Finansman:** dükkân puanı, güven ve gelişim seviyesine bağlı banka limiti; araç yatırımı için farklı faiz/vade seçenekleri ve eylem tabanlı taksitler.

İlk üç gün eski ustanın mesajları temel sistemi öğretir. Sonrasında oyun sonsuz ilerler. Mizah; abartılı teşhis, yanlış parça, çay sohbeti ve esnaf olayları üzerinden kurulur; kimlik veya dezavantaj üzerinden aşağılayıcı şaka kullanılmaz.

## Müşteri ve fiyat davranışı

Müşteriler sabit bir günlük listede bulunmaz. Yapılan işlemler zamanı ilerlettikçe itibar ve dükkân puanına bağlı aralıklarla gelir, sabır süresi dolunca ayrılır ve kuyruk en fazla üç kişidir. İş yoksa oyuncu açıkça müşteri beklemeyi seçebilir. Küçük dükkân aynı anda bir araç alır.

Fiyat parça satın alınıp işçilik tamamlandıktan sonra `Uygun`, `Normal`, `Yüksek` veya `Uçuk` olarak seçilir. Müşterinin görünüşü ve davranış profili oyuncuya kesin olmayan bir ipucu verir. Hassas müşteri yüksek fiyatı fark edip pazarlık yapabilir; sonradan düşük puan, şikâyet veya denetim doğabilir. Ayrıntılı fatura ekranı ilk sürüm kapsamına alınmaz.

## Arızaya özgü mini oyunlar

- Gösterge: hareketli ibreyi doğru aralıkta durdurma.
- Civata: bağlantıları doğru sıra ve sıkılıkta tamamlama.
- Elektrik: doğru hattı ve soketi eşleştirme.
- Hizalama: parçayı doğru yatay ve dikey konuma getirme.
- Sıvı dolumu: hedef seviyeye taşırmadan kontrollü dolum yapma.
- Zamanlama: üç kasnak üzerindeki derece işaretlerini doğru konuma çevirme.

Genel altı mekanik yıllık bakım ve proje araçlarında tekrar kullanılabilir. On iki müşteri arızasının her biri ayrıca benzersiz bir oyun kullanır: kayış gerginliği, soğutma suyu doldurma/hava alma, iki kademeli silindir kapağı torku, akü kutup sırası, farklı yükte şarj voltajı, krank sensörü boşluğu, kaliper-balata-pedal sırası, iki teker rot ayarı, debriyaj diski merkezleme, tampon klipslerini ortadan dışa oturtma, kapı aralığı ve göçüğü çevreden merkeze toplama.

Sistem uyarısı veya ayrı iPhone penceresi açılmaz; oyunlar dükkân ekranının üzerinde oyun içi çalışma alanı olarak görünür. İş kimliğinden üretilen hedefler değişir; başarı hızdan çok doğru sıra, ölçü, denge ve son kontrolden hesaplanır.

## Dükkân, yıkama ve çırak

- Seviye 1: temel lift ve tek araç kapasitesi.
- Seviye 2: ikinci lift, oturma alanı, yıllık bakım ve ilk çırak tezgâhı.
- Seviye 3: yıkama alanı ve parça deposu.
- Seviye 4: üç araç kapasitesi, ikinci çırak ve kontrolleri hızlandıran teşhis laboratuvarı.
- Seviye 5: hasarlı araç restorasyon giderini azaltan kaporta-boya kabini.
- Seviye 6: dört araç kapasitesi, detaylı temizlik ve üçüncü çırak.
- Seviye 7: beş araç kapasitesi, dört çırak ve ilan satış ihtimalini yükselten araç vitrini.

Çırak tamir veya tek bir bakım adımına atanabilir. Başlangıçta ustadan daha düşük ve değişken performans gösterir; tamamladığı işlerden XP kazanıp seviye atlar. Araç, fiyat söylenmeden önce yıkanabilir; yıkama maliyet üretir fakat müşteri memnuniyetine katkı sağlar.

## Ağır hasarlı araç raporu

Teklif turu bulunmaz. Her araçta sabit alış fiyatı, ağır hasar/pert durumu, çalışır-yürür bilgisi, airbag durumu, kayıtlı hasar tutarı, bütün kaporta panellerinin orijinal/boyalı/değişen/hasarlı durumu ve birden fazla mekanik-elektrik kusuru görünür.

Ekspertizde `Usta Hesabı` bölümü; tahmini onarım giderini, alış dahil toplam yatırımı, adil satış bandını ve kötümser/iyimser kâr aralığını gösterir. Bu değer piyasa ve parça belirsizliğini koruyan bir karar desteğidir, kâr garantisi değildir. Restorasyondan sonra oyuncu adil fiyat önerisini görür, ilan fiyatını belirler ve fiyat yükseldikçe düşen tahmini satış ihtimalini izler. Satış anlık değildir; oyun içi eylemler zaman ilerlettikçe alıcı kontrolleri oluşur.

## Banka kredisi

Kredi limiti dükkân seviyesi, müşteri güveni ve dükkân puanıyla büyür. Kısa, dengeli ve esnek vadeler sırasıyla daha yüksek taksit/düşük faiz ile daha düşük taksit/yüksek faiz arasında seçim sunar. Kalan borç kullanılabilir limitten düşer. Taksitler gerçek zamanla veya uygulama açık kaldığı için işlemez; yalnız oyun içi eylemler ödeme tarihini geçtiğinde otomatik tahsil edilir ve kasa hareketlerinde ayrı görünür.

Rapor kapsamı; gerçek ekspertizlerde kullanılan kaporta-boya, şasi/podye/direk, airbag, motor-mekanik, fren, süspansiyon ve OBD başlıklarından esinlenir. Kaynaklar: [Ticaret Bakanlığı ikinci el taşıt yönetmeliği](https://ietts.gtb.gov.tr/Home/Yonetmelik?v=1.0.26), [örnek kaporta ekspertiz raporu](https://cdn.zugo.live/File/AracHavuzDosya/131/3DB736C4-E5BB-4E67-B08E-56C3FBA5F833/3C013D0E-4685-4B37-9855-612C46A24531.pdf), [ekspertiz kapsamı özeti](https://blog.toyota.com.tr/oto-ekspertiz-ne-demektir/).
