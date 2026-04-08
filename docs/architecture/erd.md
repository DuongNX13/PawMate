# PawMate Phase 1 ERD

This ERD covers the Day 1 and Phase 1 domain only: auth, pet profile, vet finder, reviews, health records, reminders, and notifications.

```mermaid
erDiagram
  users ||--o{ sessions : has
  users ||--o{ pets : owns
  users ||--o{ reviews : writes
  users ||--o{ notifications : receives
  pets ||--o{ health_records : has
  pets ||--o{ reminders : has
  pets ||--o{ notifications : references
  vets ||--o{ vet_services : offers
  vets ||--o{ reviews : receives
  reminders ||--o{ notifications : triggers

  users {
    uuid id PK
    string email UK
    string password_hash
    string display_name
    string phone
    string avatar_url
    string auth_provider
    boolean email_verified
    timestamp created_at
    timestamp updated_at
    timestamp deleted_at
  }

  sessions {
    uuid id PK
    uuid user_id FK
    string refresh_token_hash UK
    string device_id
    string user_agent
    string ip_address
    timestamp expires_at
    timestamp revoked_at
    timestamp created_at
  }

  pets {
    uuid id PK
    uuid user_id FK
    string name
    string species
    string breed
    string gender
    date dob
    decimal weight_kg
    string color
    string microchip_number UK
    boolean is_neutered
    string avatar_url
    string health_status
    timestamp created_at
    timestamp updated_at
    timestamp deleted_at
  }

  vets {
    uuid id PK
    string name
    string phone
    string email
    string address
    string ward
    string district
    string city
    geography location
    jsonb opening_hours
    boolean is_24h
    decimal average_rating
    integer review_count
    timestamp created_at
    timestamp updated_at
  }

  vet_services {
    uuid id PK
    uuid vet_id FK
    string service_name
    boolean is_emergency
    timestamp created_at
  }

  reviews {
    uuid id PK
    uuid vet_id FK
    uuid user_id FK
    integer rating
    string title
    text body
    boolean is_anonymous
    timestamp created_at
    timestamp updated_at
  }

  health_records {
    uuid id PK
    uuid pet_id FK
    uuid created_by_user_id FK
    string record_type
    date record_date
    text notes
    jsonb attachments
    timestamp created_at
    timestamp updated_at
  }

  reminders {
    uuid id PK
    uuid pet_id FK
    uuid created_by_user_id FK
    string title
    timestamp reminder_at
    string repeat_rule
    string status
    timestamp created_at
    timestamp updated_at
  }

  notifications {
    uuid id PK
    uuid user_id FK
    uuid pet_id FK
    uuid reminder_id FK
    string type
    string title
    text body
    timestamp read_at
    timestamp delivered_at
    timestamp created_at
  }
```

## Relationship notes
- A user can own many pets and can create many sessions.
- A pet belongs to exactly one user in Phase 1.
- A clinic can expose many services and receive many reviews.
- A pet can have many health records and many reminders.
- A reminder can generate zero or more notifications over time.
- Notifications are user-scoped, with optional links back to a pet and reminder.

## Key constraints
- `users.email` is unique.
- `sessions.refresh_token_hash` is unique and revocable.
- `pets.microchip_number` is unique when provided.
- `reviews` should enforce one active review per user per vet if product rules require it.
- `vets.location` should use `geography(Point, 4326)` or equivalent PostGIS support.

## Index plan
- `users(email)`
- `sessions(user_id, revoked_at)`
- `pets(user_id, deleted_at)`
- `vets USING GIST(location)`
- `vets(is_24h, average_rating)`
- `vet_services(vet_id, service_name)`
- `reviews(vet_id, created_at desc)`
- `reviews(user_id)`
- `health_records(pet_id, record_date desc)`
- `reminders(pet_id, reminder_at)`
- `notifications(user_id, read_at, created_at desc)`

## Phase 1 scope guard
- Public profiles, marketplace, rescue, adoption, payments, and AI features are out of scope.
- Reminder delivery can be documented now even if the worker implementation lands later.
- Review analytics beyond basic counts and averages are deferred.
