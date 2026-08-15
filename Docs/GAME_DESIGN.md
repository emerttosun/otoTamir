# Oyun Tasarımı

Ana fantezi küçük bir sanayi dükkânını ustalıkla ve esnaflık kararlarıyla büyütmektir. Gün/saat tasarımı kesinleşene kadar oyun boşta kendi kendine ilerlemez; yalnız kontrol, parça, tamir, yıkama veya açıkça müşteri bekleme eylemleri zamanı ilerletir. Böylece uygulama açık bırakıldığı için para kaybedilmez. Oyuncu kısa vadeli nakit ile uzun vadeli güven arasında seçim yapar.

## Döngüler

- **Müşteri:** bekleyen müşteri, şikâyeti dinleme, araç kontrolleri, bulguyla bağlantılı teşhis, parça alma, tamir mini oyunu, fiyat seçimi, ödeme ve gecikmeli sonuç.
- **Yıllık bakım:** bakım seti alma, yağ/filtre, akü, lastik-fren ve sıvı kontrollerini uygun mini oyunlarla tamamlama.
- **Gelişim:** yapılan işlerden alan bazlı XP ve seviye, ustalık/güven/şaibe, dükkân puanı ve yorumlar, dükkân kabiliyetleri ve çıraklar.
- **Hasarlı araç ihalesi:** sabit ihale bedelli, sigorta çıkması ve eksper tarafından onarılabilir kabul edilmiş ağır hasarlı araç; üstten kaporta şeması, ayrıntılı taşıyıcı yapı ölçümü, yatırım/kâr aralığı ve satın alma.
- **Dükkân sahnesi:** kabul edilen müşteri araçlarını ve satın alınan proje araçlarını geliş sırasına göre (FIFO) tek araçlık yatay sayfalarda gösterir; işlem paneli yalnız oyuncu araca dokunduğunda açılır.
- **Proje restorasyonu:** ihale aracı tek düğmeyle bitmez. Her mekanik arıza, hasarlı veya eksik dış parça, şasi/podye/direk onarımı ve hava yastığı sistemi ayrı maliyetli bir iş ve uygun mini oyunla oyuncu tarafından tamamlanır.
- **İlan yeri:** restorasyonu biten araç için fiyat belirleme, satış ihtimali, ayrı ilan takibi ve dürüst veya riskli satış.
- **Finansman:** dükkân puanı, güven ve gelişim seviyesine bağlı banka limiti; araç yatırımı için farklı faiz/vade seçenekleri ve eylem tabanlı taksitler.
- **Olay Defteri:** denetim, şikâyet, tavsiye, kredi, ilan, araç satışı ve çırak sonuçlarını para/itibar etkileriyle Gelişim ekranında kalıcı tutar.

Zorunlu ve uzun bir ilk üç gün eğitimi bulunmaz. Her üst sekme ilk kez açıldığında ne işe yaradığını anlatan tek, kapatılabilir oyun içi kart gösterir. Sonrasında oyun sonsuz ilerler. Mizah; abartılı teşhis, yanlış parça, çay sohbeti ve esnaf olayları üzerinden kurulur; kimlik veya dezavantaj üzerinden aşağılayıcı şaka kullanılmaz.

Motor, elektrik, yürüyen ve kaporta seviyeleri yalnız işçilik puanı vermez; ilgili seviyedeki yeni arıza havuzunu açar. En yüksek uzmanlık daha seçici müşterileri, dükkân seviyesiyle birlikte ortalama uzmanlık da daha geniş araç havuzunu getirir. Gelişim ekranı her alan için sırada açılacak işi gösterir.

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

Genel altı mekanik yıllık bakım ve proje araçlarında tekrar kullanılabilir. Otuz müşteri arızasının her biri ayrıca benzersiz bir oyun kimliği kullanır. Mevcut mekanikler; kayış gerginliği, hava alma, tork sırası, akü kutupları, şarj voltajı, sensör boşluğu, fren-balata, rot, debriyaj, kaporta hizalama ve göçük işlerine ek olarak buji aralığı, bobin sırası, enjektör dönüş dengesi, pompa contası, triger işaretleri, turbo basıncı, UV yağ izi, sigorta ve kablo sürekliliği, cam krikosu, far ayarı, disk salgısı, amortisör geri dönüşü, rulman ön yükü, aks körüğü gres dağılımı, kaput aralığı, nokta kaynak ve boya katmanlarını kapsar.

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

Teklif turu bulunmaz. Her araçta sabit alış fiyatı, onarılabilir ağır hasar durumu, çalışır-yürür bilgisi, airbag durumu, kayıtlı hasar tutarı, dış parçaların sağlam/ezik/ağır ezik/eksik durumu ve birden fazla mekanik-elektrik kusuru görünür. Sol-sağ şasi kolları, podyeler, amortisör kuleleri, A/B/C direkleri, ön-arka panel ve bagaj havuzu renk koduna sıkıştırılmadan ayrı ölçüm satırlarıyla raporlanır.

Tam hasarlı ve hurda tescilli araçlar onarım kabul etmediği için oyuncuya satılmaz. Oyun pazarı yalnız onarımı mümkün ağır hasarlı araçları kapsar. Ağır hasar üretiminde onarım maliyetinin araç rayicinin en az %60'ına ulaşması veya kritik yapısal hasar bulunması esas alınır.

Ekspertizde `Usta Hesabı` bölümü; tahmini onarım giderini, alış dahil toplam yatırımı, adil satış bandını ve kötümser/iyimser kâr aralığını gösterir. Bu değer piyasa ve parça belirsizliğini koruyan bir karar desteğidir, kâr garantisi değildir. Restorasyondan sonra oyuncu adil fiyat önerisini görür, ilan fiyatını belirler ve fiyat yükseldikçe düşen tahmini satış ihtimalini izler. Satış anlık değildir; oyun içi eylemler zaman ilerlettikçe alıcı kontrolleri oluşur.

## Banka kredisi

Kredi limiti dükkân seviyesi, müşteri güveni ve dükkân puanıyla büyür. Kısa, dengeli ve esnek vadeler sırasıyla daha yüksek taksit/düşük faiz ile daha düşük taksit/yüksek faiz arasında seçim sunar. Kalan borç kullanılabilir limitten düşer. Taksitler gerçek zamanla veya uygulama açık kaldığı için işlemez; yalnız oyun içi eylemler ödeme tarihini geçtiğinde otomatik tahsil edilir ve kasa hareketlerinde ayrı görünür.

Rapor kapsamı; gerçek ekspertizlerde kullanılan kaporta-boya, şasi/podye/direk, airbag, motor-mekanik, fren, süspansiyon ve OBD başlıklarından esinlenir. Ağır ve tam hasar ayrımı SEDDK 2025/12 Genelgesi esas alınarak oyunlaştırılır. Kaynaklar: [SEDDK ağır ve tam hasar genelgesi](https://www.tsb.org.tr/content/Legislations/Motorlu%20Ara%C3%A7%20Sigortalar%C4%B1%20Kapsam%C4%B1nda%20Tam%20Hasara%20Ya%20Da%20A%C4%9F%C4%B1r%20Hasara%20U%C4%9Fram%C4%B1%C5%9F%20Ara%C3%A7lar%C4%B1n%20Tespiti%20Hakk%C4%B1nda%20Genelge%20202512.pdf), [Ticaret Bakanlığı ikinci el taşıt yönetmeliği](https://ietts.gtb.gov.tr/Home/Yonetmelik?v=1.0.26), [örnek kaporta ekspertiz raporu](https://cdn.zugo.live/File/AracHavuzDosya/131/3DB736C4-E5BB-4E67-B08E-56C3FBA5F833/3C013D0E-4685-4B37-9855-612C46A24531.pdf).
