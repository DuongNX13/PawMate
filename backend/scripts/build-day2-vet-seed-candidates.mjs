import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const backendRoot = path.resolve(__dirname, '..');
const outputDir = path.join(backendRoot, 'prisma', 'data');
const outputPath = path.join(outputDir, 'day2_vet_seed_candidates.json');

const sourceConfig = {
  hanoi: {
    city: 'Hà Nội',
    cityCode: 'hn',
    limit: 30,
    url: 'https://www.longkhanhpets.com/2024/04/30-phong-kham-benh-vien-thu-y-ha-noi-uy.html',
    sourceList: 'Long Khanh Pets - 30 phòng khám, bệnh viện thú y Hà Nội uy tín',
  },
  hcmc: {
    city: 'TP Hồ Chí Minh',
    cityCode: 'hcm',
    limit: 30,
    url: 'https://www.longkhanhpets.com/2024/04/20-phong-kham-benh-vien-thu-y-tphcm-moi.html',
    sourceList:
      'Long Khanh Pets - 20 phòng khám, bệnh viện thú y TPHCM mới nhất',
  },
  haiphong: {
    city: 'Hải Phòng',
    cityCode: 'hp',
    limit: 10,
    url: 'https://tophaiphong.com/thu-y-hai-phong/',
    sourceList:
      'Top Hải Phòng - Top 10 địa chỉ phòng khám thú y Hải Phòng chất lượng, uy tín',
  },
  danang: {
    city: 'Đà Nẵng',
    cityCode: 'dn',
    limit: 10,
    url: 'https://top10.khangviet.net/top-50-phong-kham-thu-y-benh-vien-thu-y-uy-tin-thuoc-da-nang/',
    sourceList:
      'Khang Việt - Top phòng khám, bệnh viện thú y uy tín tại Đà Nẵng',
  },
};

const districtLookup = {
  'Hà Nội': [
    'Ba Đình',
    'Bắc Từ Liêm',
    'Cầu Giấy',
    'Đống Đa',
    'Hà Đông',
    'Hai Bà Trưng',
    'Hoàn Kiếm',
    'Hoàng Mai',
    'Long Biên',
    'Nam Từ Liêm',
    'Tây Hồ',
    'Thanh Xuân',
  ],
  'TP Hồ Chí Minh': [
    'Quận 1',
    'Quận 2',
    'Quận 3',
    'Quận 4',
    'Quận 5',
    'Quận 6',
    'Quận 7',
    'Quận 8',
    'Quận 9',
    'Quận 10',
    'Quận 11',
    'Bình Thạnh',
    'Bình Tân',
    'Gò Vấp',
    'Phú Nhuận',
    'Quận Bình Thạnh',
    'Tân Bình',
    'Tân Phú',
    'Thủ Đức',
  ],
  'Hải Phòng': [
    'An Dương',
    'Dương Kinh',
    'Hải An',
    'Hồng Bàng',
    'Kiến An',
    'Lê Chân',
    'Ngô Quyền',
    'Thủy Nguyên',
  ],
  'Đà Nẵng': [
    'Cẩm Lệ',
    'Hải Châu',
    'Liên Chiểu',
    'Ngũ Hành Sơn',
    'Sơn Trà',
    'Thanh Khê',
  ],
};

const fetchText = async (url) => {
  const response = await fetch(url, {
    headers: {
      'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PawMateSeedBuilder/1.0',
    },
  });

  if (!response.ok) {
    throw new Error(`Cannot fetch ${url} (${response.status})`);
  }

  return new TextDecoder('utf-8').decode(await response.arrayBuffer());
};

const decodeHtml = (value = '') =>
  value
    .replace(/<br\s*\/?>/gi, ', ')
    .replace(/&#(\d+);/g, (_, decimal) =>
      String.fromCodePoint(Number(decimal)),
    )
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) =>
      String.fromCodePoint(parseInt(hex, 16)),
    )
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');

const cleanText = (value = '') =>
  decodeHtml(value)
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/\s+([,.;:])/g, '$1')
    .trim();

const normalizePhone = (value = '') =>
  cleanText(value)
    .replace(/\s*[–-]\s*/g, ' / ')
    .replace(/\s{2,}/g, ' ')
    .replace(/[.,;]+$/g, '')
    .trim();

const toKey = (item) =>
  `${item.city}|${item.name}|${item.address}`.toLowerCase().replace(/\s+/g, ' ');

const dedupe = (items) => {
  const seen = new Set();
  return items.filter((item) => {
    const key = toKey(item);
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
    return true;
  });
};

const findDistrict = (address, city, fallback) => {
  if (fallback) {
    return fallback;
  }

  const addressLower = address.toLowerCase();
  return districtLookup[city].find((district) =>
    addressLower.includes(district.toLowerCase()),
  );
};

const normalizeHeadingDistrict = (heading) => {
  const parts = heading.split(',');
  const lastPart = parts.at(-1)?.trim();

  if (!lastPart) {
    return undefined;
  }

  if (/^Quận\s+\D/i.test(lastPart)) {
    return lastPart.replace(/^Quận\s+/i, '').trim();
  }

  return lastPart.trim();
};

const pickFirstMatch = (body, patterns) => {
  for (const pattern of patterns) {
    const matched = pattern.exec(body);
    if (matched?.groups?.value) {
      return matched.groups.value;
    }
  }

  return '';
};

const parseLongKhanhCity = async (config) => {
  const html = await fetchText(config.url);
  const blocks = [
    ...html.matchAll(
      /<h2><span id="[^"]+">(?<heading>[\s\S]*?)<\/span><\/h2>(?<body>[\s\S]*?)(?=<h2><span id="[^"]+">|$)/g,
    ),
  ];

  const items = [];

  for (const block of blocks) {
    const body = block.groups.body;
    if (!body.includes('<h3>')) {
      continue;
    }

    const heading = cleanText(block.groups.heading);
    const district = normalizeHeadingDistrict(heading);
    const clinics = [
      ...body.matchAll(
        /<h3><span id="[^"]+">(?<name>[\s\S]*?)<\/span><\/h3>\s*<ul>(?<meta>[\s\S]*?)<\/ul>/g,
      ),
    ];

    for (const clinic of clinics) {
      const address = pickFirstMatch(clinic.groups.meta, [
        /Địa chỉ:\s*(?<value>[\s\S]*?)<\/li>/i,
        /Đia chỉ:\s*(?<value>[\s\S]*?)<\/li>/i,
      ]);
      const phone = pickFirstMatch(clinic.groups.meta, [
        /Điện thoại:\s*(?<value>[\s\S]*?)<\/li>/i,
      ]);

      items.push({
        name: cleanText(clinic.groups.name),
        city: config.city,
        district: findDistrict(cleanText(address), config.city, district),
        address: cleanText(address),
        phone: normalizePhone(phone),
        sourceUrl: config.url,
        sourceList: config.sourceList,
      });
    }
  }

  return dedupe(items)
    .slice(0, config.limit)
    .map((item, index) => ({
      ...item,
      sourceRank: index + 1,
      cityCode: config.cityCode,
    }));
};

const parseHaiPhong = async (config) => {
  const html = await fetchText(config.url);
  const blocks = [
    ...html.matchAll(/<h2[^>]*>(?<heading>[\s\S]*?)<\/h2>(?<body>[\s\S]*?)(?=<h2[^>]*>|$)/g),
  ];

  const items = [];

  for (const block of blocks) {
    const heading = cleanText(block.groups.heading);
    const headingMatch = heading.match(/^(?<index>\d+)\.\s*(?<title>.+)$/);
    if (!headingMatch) {
      continue;
    }

    const fullTitle = headingMatch.groups.title.trim();
    const address = pickFirstMatch(block.groups.body, [
      /Địa chỉ:\s*<\/(?:b|strong)>\s*(?:<a[^>]*>)?(?<value>[\s\S]*?)(?:<\/a>)?<\/li>/i,
      /Địa chỉ:\s*(?<value>[\s\S]*?)<\/li>/i,
    ]);
    const phone = pickFirstMatch(block.groups.body, [
      /Số điện thoại:\s*<\/(?:b|strong)>\s*(?<value>[\s\S]*?)<\/li>/i,
      /Số điện thoại:\s*(?<value>[\s\S]*?)<\/li>/i,
    ]);

    items.push({
      name: fullTitle.split(/\s+[–-]\s+/)[0].trim(),
      city: config.city,
      district: findDistrict(cleanText(address), config.city),
      address: cleanText(address),
      phone: normalizePhone(phone),
      sourceUrl: config.url,
      sourceList: config.sourceList,
      sourceRank: Number(headingMatch.groups.index),
      cityCode: config.cityCode,
    });
  }

  return dedupe(items).slice(0, config.limit);
};

const parseDaNang = async (config) => {
  const html = await fetchText(config.url);
  const blocks = [
    ...html.matchAll(
      /<h3 class="wp-block-heading">(?<heading>[\s\S]*?)<\/h3>\s*<ul class="wp-block-list">(?<body>[\s\S]*?)<\/ul>/g,
    ),
  ];

  const items = [];

  for (const [index, block] of blocks.entries()) {
    const listItems = [
      ...block.groups.body.matchAll(/<li>(?<value>[\s\S]*?)<\/li>/g),
    ].map((item) => cleanText(item.groups.value));
    const address = listItems[0]?.replace(/^[^:]+:\s*/, '') ?? '';
    const phone =
      listItems.find((item, itemIndex) => itemIndex > 0 && /\d{8,}/.test(item))
        ?.replace(/^[^:]+:\s*/, '') ?? '';

    items.push({
      name: cleanText(block.groups.heading),
      city: config.city,
      district: findDistrict(cleanText(address), config.city),
      address: cleanText(address),
      phone: normalizePhone(phone),
      sourceUrl: config.url,
      sourceList: config.sourceList,
      sourceRank: index + 1,
      cityCode: config.cityCode,
    });
  }

  return dedupe(items).slice(0, config.limit);
};

const toSeedRecord = (item, index) => ({
  id: `${item.cityCode}-${String(index + 1).padStart(3, '0')}`,
  name: item.name,
  city: item.city,
  district: item.district ?? null,
  address: item.address,
  phone: item.phone || null,
  latitude: null,
  longitude: null,
  website: null,
  is24h: null,
  openHours: [],
  services: [],
  photoUrls: [],
  averageRating: null,
  reviewCount: 0,
  sourceUrl: item.sourceUrl,
  sourceList: item.sourceList,
  sourceRank: item.sourceRank,
  priorityTier: 'high',
  selectionReason: 'curated-toplist-seed',
  enrichmentStatus: 'needs-geo-hours-services',
  readyForMap: false,
});

const build = async () => {
  const cityBuckets = await Promise.all([
    parseLongKhanhCity(sourceConfig.hanoi),
    parseLongKhanhCity(sourceConfig.hcmc),
    parseHaiPhong(sourceConfig.haiphong),
    parseDaNang(sourceConfig.danang),
  ]);

  const records = cityBuckets
    .flat()
    .map(toSeedRecord);

  const summary = cityBuckets.map((bucket) => ({
    city: bucket[0]?.city ?? 'unknown',
    count: bucket.length,
    sourceUrl: bucket[0]?.sourceUrl ?? null,
    sourceList: bucket[0]?.sourceList ?? null,
  }));

  await mkdir(outputDir, { recursive: true });
  await writeFile(
    outputPath,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        note:
          'Seed candidates are curated from public local toplist articles. Exact public star ratings are intentionally left null until a verified rating source is added. Geo coordinates, open hours, and service tags still need enrichment before Day 3 nearby-map work can be treated as ready.',
        total: records.length,
        summary,
        clinics: records,
      },
      null,
      2,
    ),
    'utf8',
  );

  console.log(`Wrote ${records.length} clinic seed candidates to ${outputPath}`);
};

build().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
