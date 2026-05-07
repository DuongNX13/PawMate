# PawMate Day 2 Pet Profile Data Contract

Scope: D2-07. This is the source of truth for the `Pet` domain model and the create/update payloads used by `/pets`.

## Contract rules

- `species` is one of `dog`, `cat`, `bird`, `rabbit`, `other`.
- `gender` is one of `male`, `female`, `unknown`.
- `healthStatus` is one of `healthy`, `monitoring`, `chronic`, `recovery`, `unknown`.
- `weight` is stored in kilograms.
- `microchip` is nullable and should be treated as unique when present.
- Update payloads may omit mutable fields; create payloads require `name`, `species`, and `gender`.

## Prisma model sketch

```prisma
enum PetSpecies {
  dog
  cat
  bird
  rabbit
  other
}

enum PetGender {
  male
  female
  unknown
}

enum PetHealthStatus {
  healthy
  monitoring
  chronic
  recovery
  unknown
}

model Pet {
  id           String          @id @default(uuid()) @db.Uuid
  userId       String          @db.Uuid
  name         String
  species      PetSpecies
  breed        String?
  gender       PetGender
  dob          DateTime?
  weight       Float?
  color        String?
  microchip    String?         @unique
  isNeutered   Boolean         @default(false)
  avatarUrl    String?
  healthStatus PetHealthStatus @default(healthy)

  user         User            @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
}
```

## Payload shape

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | uuid | yes | Server-generated |
| `userId` | uuid | yes | Owner scope |
| `name` | string | yes | Display name |
| `species` | enum | yes | Drives breed UI |
| `breed` | string | no | Free text or species-specific list |
| `gender` | enum | yes | `unknown` allowed |
| `dob` | date | no | ISO date only |
| `weight` | number | no | Kilograms |
| `color` | string | no | Visible coat color |
| `microchip` | string | no | Nullable unique value |
| `isNeutered` | boolean | yes | Defaults to `false` |
| `avatarUrl` | uri | no | Supabase Storage/CDN URL |
| `healthStatus` | enum | yes | Defaults to `healthy` |

## Migration note

- Create the `pets` table with the enum columns above.
- Add an index on `user_id`.
- Use a uniqueness strategy for `microchip` only when the value is present.
- If soft-delete metadata is needed for `DELETE /pets/:id`, keep it as storage-only state and do not expose it in the API contract.
