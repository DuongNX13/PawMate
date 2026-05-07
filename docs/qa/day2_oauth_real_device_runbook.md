# PawMate Day 2 OAuth Real-Device Runbook

Updated: `2026-04-09`

## Muc tieu

- Hoan tat `D2-20` bang bang chung thiet bi that cho:
  - Google Sign-In tren Android
  - Apple Sign-In tren iPhone
- Luu evidence de Cypher co the ket luan test pass/fail ro rang.

## Tinh trang hien tai cua may nay

- IDE co emulator extension: `diemasmichiels.emulate`
- May Windows hien khong co:
  - Android SDK tools trong `PATH`
  - Android AVD da tao san
  - iOS Simulator runtime
- iOS Simulator khong the chay tren Windows
- Theo task Day 2, `D2-20` yeu cau `real device`, nen emulator khong du de dong task

## Emulator co the giup gi

- Co the giup test phu cho:
  - UI flow
  - deep link/callback shell
  - trang thai loading, error, retry
- Khong du de sign-off `D2-20` cho:
  - Google Sign-In final acceptance
  - Apple Sign-In final acceptance
  - proof tren thiet bi that

## Step by step de dong `D2-20`

### A. Chot moi truong truoc khi test

1. Xac nhan backend Day 2 dang xanh:
   - `npm run build`
   - `npm run lint`
   - `npm test`
   - `npm run test:coverage`
   - `npm run smoke:runtime`
2. Xac nhan Supabase da co:
   - `SUPABASE_URL` dung dang `https://<project-ref>.supabase.co`
   - provider Google bat trong Supabase Auth
   - provider Apple bat trong Supabase Auth
   - redirect URL web va mobile trung voi config cua app
3. Xac nhan mobile build co callback scheme dung:
   - `pawmate://auth/callback`

### B. Android real device cho Google Sign-In

1. Tren dien thoai Android:
   - bat Developer options
   - bat USB debugging
2. Cam day USB vao may Windows
3. Xac nhan ket noi ADB:
   - `adb devices`
   - ket qua can thay 1 device o trang thai `device`
4. Chay app len may that:
   - `flutter devices`
   - `flutter run -d <android-device-id>`
5. Thuc hien case test Google:
   - mo app
   - chon `Dang nhap voi Google`
   - chon tai khoan Google
   - quay lai app
6. Xac nhan ket qua:
   - app dang nhap thanh cong
   - backend tra user dung email
   - `authProvider = google`
   - session duoc tao
7. Capture evidence:
   - screenshot man hinh chon tai khoan
   - screenshot man hinh vao app thanh cong
   - log backend hoac response payload da duoc mask token

### C. iPhone real device cho Apple Sign-In

1. Can mot may Mac co Xcode
   - day la yeu cau ky thuat, Windows khong build va deploy iOS app hoan chinh duoc
2. Tren iPhone:
   - dang nhap Apple ID
   - bat cap phep can thiet cho developer build neu duoc nhac
3. Tren Mac:
   - mo project Flutter iOS
   - cau hinh team signing trong Xcode
   - build va run len iPhone that
4. Thuc hien case test Apple:
   - lan dau dang nhap: kiem tra name co the duoc tra ve
   - lan sau dang nhap lai: kiem tra name co the null nhung user van map dung
5. Xac nhan ket qua:
   - app dang nhap thanh cong
   - backend tra `authProvider = apple`
   - user cu duoc nhan dien dung
6. Capture evidence:
   - screenshot flow Apple Sign-In
   - screenshot vao app thanh cong
   - note ro lan dau hay lan dang nhap lai

## Checklist evidence cho Cypher

- 1 video ngan hoac screenshot cho Android Google flow
- 1 video ngan hoac screenshot cho iPhone Apple flow
- log backend da mask token
- bang ket qua:
  - device
  - os version
  - account test
  - ket qua
  - bug neu co

## Cach giai block nhanh nhat

- Neu chi co Windows: dong duoc phan Android Google, chua dong duoc Apple
- Neu can dong tron `D2-20`: can them 1 may Mac + 1 iPhone that
- Neu chua co Mac:
  - nho Neo hoac Cypher chay lane Apple tren may khac
  - hoac dung cloud/remote Mac de build va run iOS
