import { PrismaClient } from '@prisma/client';

const prismaClients = new Map<string, PrismaClient>();

export const getPrismaClient = (databaseUrl?: string) => {
  const cacheKey = databaseUrl ?? 'default';
  const existingClient = prismaClients.get(cacheKey);

  if (existingClient) {
    return existingClient;
  }

  const prismaClient = databaseUrl
    ? new PrismaClient({
        datasources: {
          db: {
            url: databaseUrl,
          },
        },
      })
    : new PrismaClient();

  prismaClients.set(cacheKey, prismaClient);
  return prismaClient;
};
