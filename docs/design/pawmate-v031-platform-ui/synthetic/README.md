# PawMate v0.31 synthetic Rescue fixtures

Hai ảnh trong thư mục này là **Dữ liệu minh họa** do Image Gen tạo cho design review và automated test. Chúng không phải ảnh ca cứu hộ thật, không được khai báo trong production asset bundle và không được dùng làm bằng chứng dữ liệu người dùng.

## Files

| File | Subject | Size | SHA-256 |
| --- | --- | ---: | --- |
| `lulu-rescue-test-fixture.webp` | Lulu, apricot toy poodle, deep-green collar | 187,612 bytes | `44FCE6A6CCA269F758EEA8E2DB0A2CA8674BBBF8D150242B1EDD648D4D4F960C` |
| `muc-rescue-test-fixture.webp` | Mực, black-white tuxedo cat, brown breakaway collar | 143,202 bytes | `639AD776E49E4A761EAEFE7D2D73CA320353D89A3B819AFB9AB0FBA1653DCCCF` |

Both files are 1024x768 WebP, encoded at quality 82 with metadata removed. Test-only copies live under `mobile/test/fixtures/rescue/` and must remain absent from `mobile/pubspec.yaml`.

## Final prompts

Lulu:

> Create a single realistic documentary-style test fixture photo for the PawMate pet-rescue UI. Landscape 4:3 composition, long side suitable for later resize to 1024 px. One animal only: Lulu, a small apricot toy poodle with natural proportions and realistic fur, wearing a plain deep-green collar. Lulu stands on a generic residential walkway in Ho Chi Minh City, Vietnam; quiet warm daylight, ordinary walls and plants, no recognizable landmark. Keep the dog clearly visible with safe crop space around the subject for responsive cards. The image must look like a neutral phone photo, not a glossy AI advertisement. Absolutely no people, other animals, text, signs, addresses, house numbers, license plates, logos, watermark, GPS/location overlay, injury, blood, medical distress, fantasy styling, decorative frame, or UI elements.

Mực:

> Create a separate single realistic documentary-style test fixture photo for the PawMate pet-rescue UI. Landscape 4:3 composition, long side suitable for later resize to 1024 px. One animal only: Mực, a black-and-white tuxedo domestic cat with natural anatomy and realistic fur, wearing a plain brown breakaway collar. Mực sits alert but calm in a generic Vietnamese residential courtyard with simple walls, a few plants, and soft overcast daylight; no recognizable landmark. Keep the cat clearly visible with safe crop space around the subject for responsive cards. The image must resemble a neutral phone photo, not a glossy AI advertisement. Absolutely no people, other animals, text, signs, addresses, house numbers, license plates, logos, watermark, GPS/location overlay, injury, blood, medical distress, fantasy styling, decorative frame, or UI elements.

No regeneration was required after visual inspection.
