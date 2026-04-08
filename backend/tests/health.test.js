"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const app_1 = require("../src/app");
describe('GET /health', () => {
    it('returns 200 with ok status', async () => {
        const app = (0, app_1.buildApp)();
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
