# PawMate Day 3 Vet Finder Acceptance Criteria

Updated: `2026-04-23`  
Scope owner: `Phase 1 Day 3A / Day 3B prep`

## Goal

Người dùng mở PawMate và có thể tìm phòng khám thú y theo từ khóa, khu vực và bộ lọc cơ bản trước khi map lane được mở hoàn chỉnh.

## Current Source Of Truth

- UI/UX: Figma `Pawmate Desgin` page `PawMate Stitch Intake`
- Mobile routes:
  - `/vets/list`
  - `/vets/:id`
  - `/vets/map` hiện vẫn là placeholder có chủ đích
- Backend routes:
  - `GET /vets/search`
  - `GET /vets/:id`

## D3-01 Acceptance Criteria - Nearby And Filter

### Current Day 3A scope

- Người dùng tìm được vet bằng:
  - từ khóa
  - thành phố
  - quận
  - bộ lọc `24h`
  - bộ lọc `Đang mở`
  - bộ lọc `Rating 4+`
  - sắp xếp `Ưu tiên PawMate`, `Rating cao`, `Tên A-Z`
- Danh sách trả về tối đa `50` kết quả mỗi request.
- Nếu dữ liệu giờ mở cửa hoặc rating chưa enrich thì app vẫn render được, nhưng các filter liên quan chỉ áp dụng trên record đã có dữ liệu tương ứng.

### Deferred for Day 3B

- `GET /vets/nearby`
- default radius `3km`
- các mức `1 / 3 / 5 / 10km`
- sort theo distance
- max `50` results theo geo query

### Acceptance

- Khi nhập từ khóa hợp lệ, danh sách vet đổi đúng theo backend response.
- Khi bật `24h`, chỉ giữ lại vet có `is24h=true`.
- Khi bật `Đang mở`, chỉ giữ lại vet có thể tính được trạng thái mở cửa là `true`.
- Khi bật `Rating 4+`, chỉ giữ lại vet có `averageRating >= 4`.
- Khi dữ liệu không đủ để áp dụng filter, app không crash và hiển thị empty state rõ ràng.

## D3-02 Content Spec - Vet Data Format

### Địa chỉ hiển thị

- Ưu tiên format:
  - `Số nhà + Đường + Phường/Xã + Quận/Huyện + Thành phố`
- Nếu seed chỉ có địa chỉ rút gọn:
  - hiển thị nguyên văn, không tự bịa thêm trường còn thiếu

### Số điện thoại

- App hiển thị nguyên chuỗi phone có trong nguồn seed để tránh làm mất đầu số hoặc hotline phụ.
- Khi bấm gọi:
  - client sẽ sanitize về dạng chỉ còn số và dấu `+`

### Giờ mở cửa

- Nếu `is24h=true` hoặc text có `24/7`:
  - hiển thị `Mở cửa 24/7`
- Nếu có chuỗi giờ kiểu `HH:mm-HH:mm`:
  - hiển thị nguyên chuỗi đó
- Nếu chưa có dữ liệu:
  - hiển thị `Giờ mở cửa đang cập nhật`

### Service tags

- Hiển thị tối đa `3` tag trong vet list
- Hiển thị toàn bộ tag hiện có trong vet detail
- Nếu nguồn seed chưa có service:
  - hiển thị `Đang cập nhật dịch vụ`

## D3-11 Directions Deep Link Acceptance

- iOS/macOS:
  - thử Apple Maps trước
  - nếu không được thì fallback Waze
  - cuối cùng fallback Google Maps web
- Android:
  - thử `google.navigation:` trước
  - nếu không được thì fallback Google Maps web
  - sau đó fallback Waze
- Nếu tất cả fail:
  - hiển thị snackbar báo lỗi rõ ràng

## UX Acceptance

- Vet list có:
  - search field
  - city chips
  - filter chips
  - sort action
  - loading / error / empty / success state
- Vet detail có:
  - hero block
  - info card gọn cho địa chỉ + liên hệ + trạng thái mở cửa
  - action row `Gọi ngay / Chỉ đường / Đánh giá` ngay trong flow màn hình theo confirmed screen
  - service tags
  - recent review preview slot để Day 4 chỉ cần nối data thật
  - source attribution section gọn, không lấn át nội dung chính

## Out Of Scope For Day 3A

- carousel ảnh thật
- map marker clustering
- bottom sheet preview
- geo radius search
- review CRUD
- booking thật

## Release Note For Team

Day 3 hiện nên được coi là:

- `DONE` cho vet search/detail foundation
- `DONE` cho filter contract có thể chạy với seed hiện tại
- `PARTIAL` cho map/nearby vì còn phụ thuộc geo enrichment
