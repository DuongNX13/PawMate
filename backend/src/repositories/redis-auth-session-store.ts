import Redis from 'ioredis';

import {
  type AuthSessionStore,
  type SessionRecord,
} from '../services/auth/auth-service';

const buildSessionKey = (sessionId: string) => `auth:session:${sessionId}`;
const buildUserSessionSetKey = (userId: string) => `auth:user-sessions:${userId}`;

const serializeSession = (session: SessionRecord) =>
  JSON.stringify({
    ...session,
    expiresAt: session.expiresAt.toISOString(),
    revokedAt: session.revokedAt?.toISOString(),
    createdAt: session.createdAt.toISOString(),
  });

const parseSession = (value: string): SessionRecord => {
  const parsed = JSON.parse(value) as {
    id: string;
    userId: string;
    refreshTokenHash: string;
    deviceId?: string;
    userAgent?: string;
    ipAddress?: string;
    expiresAt: string;
    revokedAt?: string;
    createdAt: string;
  };

  return {
    ...parsed,
    expiresAt: new Date(parsed.expiresAt),
    revokedAt: parsed.revokedAt ? new Date(parsed.revokedAt) : undefined,
    createdAt: new Date(parsed.createdAt),
  };
};

export class RedisAuthSessionStore implements AuthSessionStore {
  constructor(private readonly redis: Redis) {}

  async listActiveSessionsByUser(userId: string) {
    const sessionIds = await this.redis.zrange(buildUserSessionSetKey(userId), 0, -1);
    if (sessionIds.length === 0) {
      return [];
    }

    const rawSessions = await this.redis.mget(
      sessionIds.map((sessionId) => buildSessionKey(sessionId)),
    );

    return rawSessions
      .filter((value): value is string => Boolean(value))
      .map(parseSession)
      .filter((session) => !session.revokedAt)
      .sort((left, right) => left.createdAt.getTime() - right.createdAt.getTime());
  }

  async findSessionById(sessionId: string) {
    const rawValue = await this.redis.get(buildSessionKey(sessionId));
    return rawValue ? parseSession(rawValue) : undefined;
  }

  async saveSession(session: SessionRecord) {
    const ttlMs = Math.max(session.expiresAt.getTime() - Date.now(), 1);
    const pipeline = this.redis.multi();
    pipeline.set(buildSessionKey(session.id), serializeSession(session), 'PX', ttlMs);
    pipeline.zadd(
      buildUserSessionSetKey(session.userId),
      session.createdAt.getTime(),
      session.id,
    );
    pipeline.pexpire(buildUserSessionSetKey(session.userId), ttlMs);
    await pipeline.exec();
  }

  async revokeSession(sessionId: string, revokedAt: Date) {
    const existing = await this.findSessionById(sessionId);
    if (!existing) {
      return;
    }

    await this.saveSession({
      ...existing,
      revokedAt,
    });
  }

  async revokeAllSessionsForUser(userId: string, revokedAt: Date) {
    const activeSessions = await this.listActiveSessionsByUser(userId);
    await Promise.all(
      activeSessions.map((session) => this.revokeSession(session.id, revokedAt)),
    );
  }
}
