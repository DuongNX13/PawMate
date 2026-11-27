import type { FastifyPluginAsync } from 'fastify';

export type ReadinessCheck = {
  name: string;
  check: () => Promise<boolean>;
};

type HealthRouteOptions = {
  readinessChecks?: ReadinessCheck[];
};

const healthRoute: FastifyPluginAsync<HealthRouteOptions> = async (
  app,
  options,
) => {
  app.get('/health', async () => ({ status: 'ok' }));

  app.get('/ready', async (_request, reply) => {
    const results = await Promise.allSettled(
      (options.readinessChecks ?? []).map((readinessCheck) =>
        readinessCheck.check(),
      ),
    );
    const ready = results.every(
      (result) => result.status === 'fulfilled' && result.value === true,
    );

    if (!ready) {
      return reply.status(503).send({ status: 'not_ready' });
    }

    return reply.send({ status: 'ready' });
  });
};

export default healthRoute;
