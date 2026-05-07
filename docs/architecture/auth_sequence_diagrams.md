# PawMate Day 2 Auth Sequence Diagrams

Scope: D2-05. These flows assume Supabase handles identity verification and PawMate backend owns the app session boundary.

## 1) Email register + verification

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant APP as Flutter app
  participant API as PawMate API
  participant DB as App DB
  participant SUPA as Supabase Auth
  participant MAIL as Email service

  U->>APP: Submit email + password
  APP->>API: POST /auth/register
  API->>DB: Check duplicate email
  alt Email is free
    API->>SUPA: Create auth user
    SUPA->>MAIL: Send verification email
    API-->>APP: 201 {userId, message}
    U->>MAIL: Open verification link
    MAIL->>SUPA: Mark email verified
    Note over API,APP: Login is allowed after email_verified = true
  else Email already exists
    API-->>APP: 409 Global error
  end
```

## 2) Login + refresh token rotation

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant APP as Flutter app
  participant API as PawMate API
  participant SUPA as Supabase Auth
  participant REDIS as Redis
  participant DB as App DB

  U->>APP: Enter email + password
  APP->>API: POST /auth/login
  API->>SUPA: Verify credentials / verified email
  SUPA-->>API: Identity OK
  API->>DB: Load user profile
  API->>REDIS: Store refresh token hash + session id
  API-->>APP: accessToken + refreshToken

  U->>APP: Continue session after 15m
  APP->>API: POST /auth/refresh
  API->>REDIS: Validate refresh token hash
  API->>REDIS: Invalidate old token, save rotated token
  API-->>APP: New accessToken + refreshToken

  U->>APP: Tap logout
  APP->>API: POST /auth/logout
  API->>REDIS: Revoke all refresh tokens for user
  API-->>APP: 204 No Content
```

## 3) Google OAuth PKCE

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant APP as Flutter app
  participant GOOGLE as Google OAuth
  participant API as PawMate API
  participant DB as App DB
  participant REDIS as Redis

  U->>APP: Tap Continue with Google
  APP->>GOOGLE: Start PKCE auth code flow
  GOOGLE-->>APP: Authorization code
  APP->>API: POST /auth/oauth {provider: google, credential: authCode, redirectUri}
  API->>GOOGLE: Exchange code + verify ID token
  GOOGLE-->>API: ID token / profile claims
  API->>DB: Upsert user by google sub or email
  API->>REDIS: Save refresh token hash
  API-->>APP: AuthSession
```

## 4) Apple Sign In

```mermaid
sequenceDiagram
  autonumber
  actor U as User
  participant APP as Flutter app
  participant APPLE as Apple Sign In
  participant API as PawMate API
  participant DB as App DB
  participant REDIS as Redis

  U->>APP: Tap Continue with Apple
  APP->>APPLE: Start sign-in with nonce
  APPLE-->>APP: Identity token + authorization code
  APP->>API: POST /auth/oauth {provider: apple, credential: identityToken, displayName?}
  API->>APPLE: Verify JWT signature + nonce
  APPLE-->>API: Token is valid
  API->>DB: Upsert user by apple sub or email
  API->>REDIS: Save refresh token hash
  API-->>APP: AuthSession
```

## Notes

- Access tokens are short-lived; refresh tokens are rotated on every refresh.
- Apple name data may only be present on first sign-in.
- The app should not treat Supabase session state as the final API session source.
