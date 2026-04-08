import Fastify, { type FastifyServerOptions } from 'fastify';
import healthRoute from './routes/health';

export const buildApp = (options: FastifyServerOptions = {}) => {
  const app = Fastify({
    logger: true,
    ...options,
  });

  app.register(healthRoute);

  return app;
};
