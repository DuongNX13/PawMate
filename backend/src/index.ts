import { buildApp } from './app';
import { ConfigError, loadEnv } from './config/env';

const start = async () => {
  let app: ReturnType<typeof buildApp> | undefined;

  try {
    const config = loadEnv();
    app = buildApp(
      {
        logger: {
          level: config.logLevel,
        },
      },
      { config },
    );
    await app.listen({ port: config.port, host: config.host });
  } catch (error) {
    const code =
      error instanceof ConfigError ? error.code : 'STARTUP_FAILED';
    process.stderr.write(
      `${JSON.stringify({ level: 'fatal', code, message: 'PawMate backend startup failed.' })}\n`,
    );
    if (app) await app.close().catch(() => undefined);
    process.exitCode = 1;
  }
};

start();
