# PawMate Phase 1 ADRs

This document records the core architecture decisions needed to unblock Phase 1 delivery.

## ADR-001 - Use Flutter for the mobile client
**Status:** Accepted

**Context**  
PawMate Phase 1 needs a single mobile codebase for iOS and Android, with a fast path to onboarding, pet profile, and vet finder screens.

**Decision**  
Use Flutter for the mobile app.

**Consequences**  
The team gets one UI codebase, shared logic, and consistent rendering across platforms. The tradeoff is dependence on the Flutter toolchain and a more opinionated widget stack.

## ADR-002 - Use Fastify with TypeScript for the backend
**Status:** Accepted

**Context**  
Phase 1 needs a small but typed API surface with predictable routing, validation, and testability.

**Decision**  
Use Fastify with TypeScript for the backend API.

**Consequences**  
The service stays lightweight, schema-friendly, and easy to test. The team must keep route contracts and validation explicit instead of relying on framework magic.

## ADR-003 - Use Supabase for identity and storage, keep app data in the domain database
**Status:** Accepted

**Context**  
Auth must support email/password plus Google and Apple sign-in, and the app also needs avatar and pet photo storage.

**Decision**  
Use Supabase for auth flows and storage buckets, while keeping domain data such as pets, vets, reviews, health records, reminders, and notifications in the app database.

**Consequences**  
The team gets OAuth and file storage faster. The app still owns its own domain models and session rules, so auth integration must be handled deliberately across the backend.

## ADR-004 - Use PostGIS for clinic proximity search
**Status:** Accepted

**Context**  
Vet Finder must support nearby search, radius filtering, and map-based clinic browsing.

**Decision**  
Store clinic coordinates with PostGIS geometry or geography support and add a spatial index on the clinic location column.

**Consequences**  
Nearby search becomes accurate and index-backed. The database layer becomes a little more specialized, but the app avoids fragile distance math in application code.

## ADR-005 - Use Redis-backed queues for session and reminder workflows
**Status:** Accepted

**Context**  
Phase 1 needs safe session rotation and a future path for reminder delivery or scheduled background work.

**Decision**  
Use Redis-backed queue and scheduler patterns for session-related work and reminder jobs.

**Consequences**  
The app can revoke sessions and later expand into reminder processing without redesigning the background job model. This introduces an operational dependency on Redis and a worker process, but keeps the job path simple.

## Notes
- These ADRs are Phase 1 only.
- Social feed, rescue, adoption, marketplace, and payment decisions are intentionally deferred.
- If the implementation diverges from these decisions, update the ADR before the codebase spreads the new behavior.
