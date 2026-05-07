import Redis from 'ioredis';

let redisClient: Redis | undefined;

export const getRedisClient = (redisUrl: string) => {
  if (!redisClient) {
    redisClient = new Redis(redisUrl, {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
    });
  }

  return redisClient;
};
