describe('getPrismaClient', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  it('caches clients per database URL', async () => {
    const PrismaClientMock = jest
      .fn()
      .mockImplementation(function PrismaClient(this: Record<string, unknown>, options?: unknown) {
        this.options = options;
      });

    jest.doMock('@prisma/client', () => ({
      PrismaClient: PrismaClientMock,
    }));

    const { getPrismaClient } = await import('../src/infrastructure/prisma');

    const defaultClientA = getPrismaClient();
    const defaultClientB = getPrismaClient();
    const customClientA = getPrismaClient('postgresql://first');
    const customClientB = getPrismaClient('postgresql://first');
    const customClientC = getPrismaClient('postgresql://second');

    expect(defaultClientA).toBe(defaultClientB);
    expect(customClientA).toBe(customClientB);
    expect(customClientC).not.toBe(customClientA);
    expect(PrismaClientMock).toHaveBeenCalledTimes(3);
    expect(PrismaClientMock).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        datasources: {
          db: {
            url: 'postgresql://first',
          },
        },
      }),
    );
  });
});

describe('getRedisClient', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  it('creates a single lazy redis client', async () => {
    const RedisMock = jest
      .fn()
      .mockImplementation(function Redis(this: Record<string, unknown>, url: string, options: unknown) {
        this.url = url;
        this.options = options;
      });

    jest.doMock('ioredis', () => ({
      __esModule: true,
      default: RedisMock,
    }));

    const { getRedisClient } = await import('../src/infrastructure/redis');

    const clientA = getRedisClient('redis://127.0.0.1:6379');
    const clientB = getRedisClient('redis://127.0.0.1:6380');

    expect(clientA).toBe(clientB);
    expect(RedisMock).toHaveBeenCalledTimes(1);
    expect(RedisMock).toHaveBeenCalledWith('redis://127.0.0.1:6379', {
      lazyConnect: true,
      maxRetriesPerRequest: 1,
    });
  });
});
