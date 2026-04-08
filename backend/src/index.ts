import { buildApp } from './app';
import { loadEnv } from './config/env';

const start = async () => {
  const config = loadEnv();
  const app = buildApp({
    logger: {
      level: config.logLevel,
    },
  });

  try {
    await app.listen({ port: config.port, host: config.host });
  } catch (error) {
    app.log.error(error);
    process.exit(1);
  }
};

start();
