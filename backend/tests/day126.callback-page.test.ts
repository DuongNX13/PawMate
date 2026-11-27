import { buildApp } from '../src/app';

describe('Day 126 D126-P3-001 email callback page wording', () => {
  it('guides link-based verification instead of OTP entry', async () => {
    const app = buildApp({ logger: false });
    await app.ready();

    const response = await app.inject({ method: 'GET', url: '/auth/callback' });

    expect(response.statusCode).toBe(200);
    expect(response.body).not.toMatch(/OTP|Gửi lại mã|nhập mã/);
    expect(response.body).toContain('Gửi lại email');
    await app.close();
  });
});
