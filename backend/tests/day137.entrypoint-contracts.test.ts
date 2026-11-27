import type { AppConfig } from '../src/config/env';

jest.mock('../src/app', () => ({ buildApp: jest.fn() }));
jest.mock('../src/config/env', () => ({
  ...jest.requireActual('../src/config/env'),
  loadEnv: jest.fn(),
}));
jest.mock('../src/jobs/process-due-reminders-job', () => ({
  parseProcessDueReminderArgs: jest.fn(),
  createDueReminderJobResources: jest.fn(),
  processDueRemindersOnce: jest.fn(),
}));

const settle = () =>
  new Promise<void>((resolve) => {
    setImmediate(resolve);
  });
const config = {
  logLevel: 'warn',
  host: '127.0.0.1',
  port: 12345,
} as AppConfig;
let load: jest.Mock;
let build: jest.Mock;
let listen: jest.Mock;
let close: jest.Mock;
let parse: jest.Mock;
let resources: jest.Mock;
let processOnce: jest.Mock;
let stdout: jest.SpyInstance;
let stderr: jest.SpyInstance;
let exit: jest.SpyInstance;
let oldExitCode: typeof process.exitCode;

beforeEach(() => {
  jest.resetModules();
  load = jest.requireMock('../src/config/env').loadEnv;
  build = jest.requireMock('../src/app').buildApp;
  const job = jest.requireMock('../src/jobs/process-due-reminders-job');
  parse = job.parseProcessDueReminderArgs;
  resources = job.createDueReminderJobResources;
  processOnce = job.processDueRemindersOnce;
  load.mockReturnValue(config);
  listen = jest.fn().mockResolvedValue(undefined);
  close = jest.fn().mockResolvedValue(undefined);
  build.mockReturnValue({ listen, close });
  parse.mockReturnValue({ limit: 3 });
  resources.mockReturnValue({ reminderService: { synthetic: true }, close });
  processOnce.mockResolvedValue({ processedCount: 1 });
  stdout = jest.spyOn(process.stdout, 'write').mockImplementation(() => true);
  stderr = jest.spyOn(process.stderr, 'write').mockImplementation(() => true);
  exit = jest
    .spyOn(process, 'exit')
    .mockImplementation(() => undefined as never);
  oldExitCode = process.exitCode;
  process.exitCode = undefined;
});
afterEach(() => {
  process.exitCode = oldExitCode;
  jest.restoreAllMocks();
});

describe('backend entrypoint side-effect contract, with no server or network', () => {
  it('starts the configured server and keeps resources alive on success', async () => {
    await import('../src/index');
    await settle();
    expect(build).toHaveBeenCalledWith(
      { logger: { level: 'warn' } },
      { config },
    );
    expect(listen).toHaveBeenCalledWith({ host: '127.0.0.1', port: 12345 });
    expect(close).not.toHaveBeenCalled();
    expect(stderr).not.toHaveBeenCalled();
  });
  it('reports config error code without leaking config or starting resources', async () => {
    const { ConfigError } = jest.requireMock('../src/config/env');
    load.mockImplementation(() => {
      throw new ConfigError('ENV_001', 'fixture');
    });
    await import('../src/index');
    await settle();
    expect(build).not.toHaveBeenCalled();
    expect(close).not.toHaveBeenCalled();
    expect(JSON.parse(String(stderr.mock.calls[0][0]))).toEqual({
      level: 'fatal',
      code: 'ENV_001',
      message: 'PawMate backend startup failed.',
    });
    expect(process.exitCode).toBe(1);
  });
  it('reports generic failure when configuration throws a non-config error', async () => {
    load.mockImplementation(() => {
      throw Error('never log me');
    });
    await import('../src/index');
    await settle();
    expect(String(stderr.mock.calls[0][0])).not.toContain('never log me');
    expect(JSON.parse(String(stderr.mock.calls[0][0])).code).toBe(
      'STARTUP_FAILED',
    );
    expect(process.exitCode).toBe(1);
  });
  it('does not try to close an app that failed construction', async () => {
    build.mockImplementation(() => {
      throw Error('fixture construction');
    });
    await import('../src/index');
    await settle();
    expect(close).not.toHaveBeenCalled();
    expect(process.exitCode).toBe(1);
  });
  it.each([false, true])(
    'closes failed startup; secondary close failure=%s is contained',
    async (closeFails) => {
      listen.mockRejectedValue(Error('fixture listen'));
      if (closeFails) close.mockRejectedValue(Error('fixture close'));
      await import('../src/index');
      await settle();
      expect(close).toHaveBeenCalledTimes(1);
      expect(process.exitCode).toBe(1);
      expect(JSON.parse(String(stderr.mock.calls[0][0])).code).toBe(
        'STARTUP_FAILED',
      );
    },
  );
});
describe('reminder CLI resource lifecycle, with no database or Redis', () => {
  it('prints one safe summary and closes resources', async () => {
    await import('../src/jobs/process-due-reminders');
    await settle();
    expect(parse).toHaveBeenCalledWith(process.argv.slice(2));
    expect(resources).toHaveBeenCalledWith(config);
    expect(processOnce).toHaveBeenCalledWith({ synthetic: true }, { limit: 3 });
    expect(JSON.parse(String(stdout.mock.calls[0][0]))).toEqual({
      data: { processedCount: 1 },
    });
    expect(close).toHaveBeenCalledTimes(1);
    expect(exit).not.toHaveBeenCalled();
  });
  it.each([Error('processing fixture'), { synthetic: true }])(
    'closes failed processing and reports the right error kind',
    async (error) => {
      processOnce.mockRejectedValue(error);
      await import('../src/jobs/process-due-reminders');
      await settle();
      expect(close).toHaveBeenCalledTimes(1);
      expect(exit).toHaveBeenCalledWith(1);
      expect(JSON.parse(String(stderr.mock.calls[0][0])).error.message).toBe(
        error instanceof Error ? error.message : 'Unknown error',
      );
    },
  );
  it('does not construct resources when parsing fails', async () => {
    parse.mockImplementation(() => {
      throw Error('bad argument fixture');
    });
    await import('../src/jobs/process-due-reminders');
    await settle();
    expect(resources).not.toHaveBeenCalled();
    expect(close).not.toHaveBeenCalled();
    expect(exit).toHaveBeenCalledWith(1);
  });
  it('reports a close failure rather than silently accepting cleanup', async () => {
    close.mockRejectedValue(Error('close fixture'));
    await import('../src/jobs/process-due-reminders');
    await settle();
    expect(exit).toHaveBeenCalledWith(1);
    expect(JSON.parse(String(stderr.mock.calls[0][0])).error.message).toBe(
      'close fixture',
    );
  });
});
