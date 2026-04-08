import { buildApp } from '../src/app';

describe('GET /health', () => {
  it('returns 200 with ok status', async () => {
    const app = buildApp({ logger: false });
    await app.ready();

    const response = await app.inject({
      method: 'GET',
      url: '/health',
    });

    expect(response.statusCode).toBe(200);
    expect(response.json()).toEqual({ status: 'ok' });

    await app.close();
  });
});
