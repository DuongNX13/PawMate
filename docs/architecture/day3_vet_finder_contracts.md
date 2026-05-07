# PawMate Day 3 Vet Finder Contracts

Updated: `2026-04-23`

## Overview

Tài liệu này gom lại contract đang dùng thật cho Day 3A và contract đã chốt trước cho Day 3B.

## Live Routes In Day 3A

### `GET /vets/search`

#### Query params

| Param | Type | Required | Default | Notes |
|---|---|---:|---|---|
| `q` | string | No | - | tìm theo tên, địa chỉ, số điện thoại, service tag |
| `city` | string | No | - | accent-insensitive |
| `district` | string | No | - | accent-insensitive |
| `is24h` | boolean | No | false | chỉ trả vet có `is24h=true` |
| `isOpenNow` | boolean | No | false | chỉ trả vet đang mở nếu tính được |
| `minRating` | float | No | - | từ `1` đến `5` |
| `sort` | enum | No | `curated` | `curated`, `rating-desc`, `name-asc` |
| `limit` | int | No | `20` | max `50` |
| `cursor` | string | No | - | offset token dạng số |

#### Validation

- `limit` phải là số nguyên từ `1` đến `50`
- `is24h` và `isOpenNow` chỉ nhận `true/false` hoặc `1/0`
- `minRating` phải nằm trong khoảng `1-5`
- `sort` chỉ nhận `curated`, `rating-desc`, `name-asc`
- lỗi validation trả `400` với:
  - `error.code = VET_001`
  - `error.field = <field-name>`

#### Response

```json
{
  "data": [
    {
      "id": "hn-001",
      "name": "Gaia Hanoi Pet Clinic",
      "city": "Hà Nội",
      "district": "Tây Hồ",
      "address": "38 Đường 1, Yên Phụ",
      "phone": "02437956956",
      "summary": "Tiêm phòng • Khám tổng quát",
      "services": ["Tiêm phòng", "Khám tổng quát"],
      "seedRank": 1,
      "averageRating": 4.7,
      "reviewCount": 18,
      "is24h": true,
      "isOpen": true,
      "readyForMap": false
    }
  ],
  "pagination": {
    "total": 1,
    "limit": 20,
    "nextCursor": null
  }
}
```

### `GET /vets/:id`

#### Response

```json
{
  "data": {
    "id": "hcm-001",
    "name": "New Pet Hospital",
    "city": "TP Hồ Chí Minh",
    "district": "Quận 1",
    "address": "53 Đặng Dung",
    "phone": "02862693939",
    "summary": "Cấp cứu 24/7",
    "services": ["Cấp cứu 24/7"],
    "seedRank": 2,
    "averageRating": 4.8,
    "reviewCount": 12,
    "is24h": false,
    "isOpen": true,
    "readyForMap": false,
    "website": "https://example.com/hcm",
    "latitude": null,
    "longitude": null,
    "openHours": ["08:00-20:00"],
    "photoUrls": [],
    "source": {
      "url": "https://example.com/hcm",
      "list": "Danh sách HCM",
      "priorityTier": "high",
      "enrichmentStatus": "needs-geo-hours-services",
      "selectionReason": "curated-toplist-seed"
    }
  }
}
```

## D3-09 Planned Contract For Day 3B

### `GET /vets/nearby`

#### Planned query params

| Param | Type | Required | Default | Notes |
|---|---|---:|---|---|
| `lat` | float | Yes | - | geo query |
| `lng` | float | Yes | - | geo query |
| `radius` | int | No | `3000` | meters, clamp `1000-10000` |
| `is24h` | boolean | No | false | optional filter |
| `isOpenNow` | boolean | No | false | optional filter |
| `minRating` | float | No | - | range `1-5` |
| `cursor` | string | No | - | cursor pagination |
| `limit` | int | No | `20` | max `50` |

### Planned validation

- `lat` trong khoảng `8-24`
- `lng` trong khoảng `102-110`
- `radius` clamp `1000-10000`
- `minRating` range `1-5`

## Deep Link Contract

### Call

- client scheme: `tel:`
- sanitize:
  - giữ số và dấu `+`

### Directions fallback order

- iOS/macOS:
  - `maps://?daddr=<destination>`
  - `https://waze.com/ul?ll=<lat,lng>&navigate=yes`
  - `https://www.google.com/maps/dir/?api=1&destination=<destination>`
- Android:
  - `google.navigation:?q=<lat,lng>`
  - `https://www.google.com/maps/dir/?api=1&destination=<destination>`
  - `https://waze.com/ul?ll=<lat,lng>&navigate=yes`

## Data Readiness Caveat

Seed hiện tại là curated directory foundation, chưa phải geo dataset hoàn chỉnh.

### Có thể dùng ngay

- name
- city
- district
- address
- phone
- source attribution
- một phần rating/openHours/is24h nếu đã enrich

### Chưa đủ để mở map lane production

- latitude
- longitude
- photoUrls thật
- openHours đầy đủ cho phần lớn record
- service taxonomy chuẩn hóa

## Test Coverage Expectations

- route test cho search success + pagination
- route test cho filter `is24h`, `isOpenNow`, `minRating`, `sort`
- route test cho validation lỗi field-level
- widget test cho vet list/detail state chính
