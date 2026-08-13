# Ekonomi ve Denge

Bütün tutarlar kuruş cinsinden `Int64` olarak saklanır. Başlangıç değerleri `catalog.json` içindeki balance bölümündedir.

- Parça maliyeti: çıkma `%55`, yan sanayi `%100`, orijinal `%140`.
- Fiyat stratejisi: adil `%100`, yüksek `%135`, uçuk `%180`.
- İşçilik ve parça güvenilirliği tekrar arıza ihtimalini etkiler.
- Hileli davranışlar anında kazanç sağlar; şikâyet ve denetim sonraki günlerde uygulanır.
- Para sıfırın altına inebilir ancak oyun bitmez. Böylece kriz cezalı fakat toparlanabilirdir.
- Parçacı en fazla 10.000 ₺ veresiye parça verir; kasa -5.000 ₺ altına düşerse gün sonunda çalışmayı sürdürecek seviyede esnaf avansı açılır.
- Gerçek para paketleri yalnız nakit sağlar; uzmanlık, itibar ve kalite sonucu satın alınamaz.

Denge değerleri koddan bağımsız içerik dosyasında tutulur ve içerik doğrulama testinden geçer.
