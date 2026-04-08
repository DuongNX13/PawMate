const { spawnSync } = require('node:child_process');

const env = {
  ...process.env,
  DATABASE_URL:
    process.env.DATABASE_URL ||
    'postgresql://pawmate:pawmate@localhost:5432/pawmate',
};

const result = spawnSync('npx', ['prisma', 'validate'], {
  stdio: 'inherit',
  env,
  shell: process.platform === 'win32',
});

process.exit(result.status ?? 1);
