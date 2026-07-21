/// Common Myanmar townships/regions for delivery routing. Not exhaustive —
/// covers the major Yangon/Mandalay townships plus each region/state capital,
/// which is enough for a shop to route or batch deliveries by area even
/// before a real carrier API resolves addresses itself.
const myanmarTownships = <String>[
  // Yangon
  'Ahlone', 'Bahan', 'Botahtaung', 'Dagon', 'Dagon Seikkan', 'Dawbon',
  'Hlaing', 'Hlaingtharyar', 'Insein', 'Kamayut', 'Kyauktada', 'Kyeemyindaing',
  'Lanmadaw', 'Latha', 'Mayangone', 'Mingaladon', 'Mingalar Taung Nyunt',
  'North Dagon', 'North Okkalapa', 'Pabedan', 'Pazundaung', 'Sanchaung',
  'Seikkyi Kanaungto', 'Shwepyithar', 'South Dagon', 'South Okkalapa',
  'Tamwe', 'Thaketa', 'Thingangyun', 'Yankin',
  // Mandalay
  'Chanayethazan', 'Chanmyathazi', 'Mahaaungmye', 'Pyigyidagun',
  'Aungmyethazan', 'Amarapura', 'Patheingyi',
  // Region/state capitals + major cities
  'Naypyidaw', 'Bago', 'Pathein', 'Mawlamyine', 'Taunggyi', 'Sittwe',
  'Myitkyina', 'Hakha', 'Loikaw', 'Monywa', 'Meiktila', 'Pyay', 'Dawei',
  'Myeik', 'Magway', 'Lashio', 'Muse', 'Pyin Oo Lwin',
  'Other',
];
