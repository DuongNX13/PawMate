const fs = require('fs');
const net = require('net');
const path = require('path');
const { spawnSync } = require('child_process');

const dotenv = require('dotenv');
const { PrismaClient } = require('@prisma/client');

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const workspaceRoot = path.resolve(repoRoot, '..');
const patchFile = path.join(backendRoot, 'prisma', 'sql', 'day5_health_records_patch.sql');

dotenv.config({ path: path.join(backendRoot, '.env'), override: false });
dotenv.config({ path: path.join(backendRoot, '.env.local'), override: true });

const migrationUrl =
  process.env.PAWMATE_DB_MIGRATION_URL ||
  process.env.DATABASE_DIRECT_URL ||
  process.env.SUPABASE_DATABASE_URL ||
  process.env.SUPABASE_DB_URL ||
  process.env.DATABASE_URL;

const redactUrl = (rawUrl) => {
  const parsed = new URL(rawUrl);
  const auth = parsed.username
    ? `${decodeURIComponent(parsed.username)}${parsed.password ? ':<redacted>' : ''}@`
    : '';
  const port = parsed.port ? `:${parsed.port}` : '';
  return `${parsed.protocol}//${auth}${parsed.hostname}${port}${parsed.pathname}`;
};

const parseDatabaseUrl = (rawUrl) => {
  if (!rawUrl) {
    throw new Error(
      'No database URL found. Set DATABASE_URL or PAWMATE_DB_MIGRATION_URL.',
    );
  }

  const parsed = new URL(rawUrl);
  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    throw new Error(
      `Unsupported database URL protocol "${parsed.protocol}". Expected postgres/postgresql.`,
    );
  }

  return parsed;
};

const isLocalHost = (host) =>
  ['localhost', '127.0.0.1', '::1'].includes(host.toLowerCase());

const tcpReachable = (host, port, timeoutMs = 1500) =>
  new Promise((resolve) => {
    const socket = new net.Socket();
    let settled = false;

    const finish = (ok) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };

    socket.setTimeout(timeoutMs);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));
    socket.connect(port, host);
  });

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: options.cwd || repoRoot,
    env: options.env || process.env,
    encoding: 'utf8',
    shell: false,
  });

  if (result.status !== 0) {
    throw new Error(
      [
        `Command failed: ${command} ${args.join(' ')}`,
        result.stdout?.trim(),
        result.stderr?.trim(),
      ]
        .filter(Boolean)
        .join('\n'),
    );
  }

  return result;
};

const ensurePortablePostgres = () => {
  const startScript = path.join(repoRoot, 'scripts', 'dev', 'start-portable-postgres.ps1');
  if (!fs.existsSync(startScript)) {
    throw new Error(`Portable PostgreSQL start script not found: ${startScript}`);
  }

  run(
    'powershell.exe',
    ['-ExecutionPolicy', 'Bypass', '-File', startScript],
    { cwd: repoRoot },
  );
};

const resolvePsql = () => {
  const localPsql = path.join(workspaceRoot, 'tools', 'pgsql', 'bin', 'psql.exe');
  if (process.platform === 'win32' && fs.existsSync(localPsql)) {
    return localPsql;
  }

  const probe = spawnSync(process.platform === 'win32' ? 'where.exe' : 'which', ['psql'], {
    encoding: 'utf8',
  });
  if (probe.status === 0) {
    return probe.stdout.split(/\r?\n/).find(Boolean).trim();
  }

  throw new Error(
    `psql not found. Expected portable psql at ${localPsql} or psql on PATH.`,
  );
};

const buildPsqlConnInfo = (url) => {
  const database = url.pathname.replace(/^\//, '') || 'postgres';
  const pairs = [
    ['host', url.hostname],
    ['port', url.port || '5432'],
    ['user', decodeURIComponent(url.username)],
    ['dbname', database],
  ];

  const sslMode = url.searchParams.get('sslmode');
  if (sslMode) {
    pairs.push(['sslmode', sslMode]);
  }

  return pairs
    .filter(([, value]) => Boolean(value))
    .map(([key, value]) => `${key}=${value}`)
    .join(' ');
};

const applyPatchWithPsql = (url) => {
  if (!fs.existsSync(patchFile)) {
    throw new Error(`Day 5 SQL patch not found: ${patchFile}`);
  }

  const psql = resolvePsql();
  const env = { ...process.env };
  if (url.password) {
    env.PGPASSWORD = decodeURIComponent(url.password);
  }

  run(
    psql,
    ['-v', 'ON_ERROR_STOP=1', buildPsqlConnInfo(url), '-f', patchFile],
    { cwd: backendRoot, env },
  );
};

const verifySchema = async (databaseUrl) => {
  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: databaseUrl,
      },
    },
  });

  try {
    const columns = await prisma.$queryRawUnsafe(
      "select column_name from information_schema.columns where table_schema = 'public' and table_name = 'health_records' and column_name in ('title','vet_id','deleted_at') order by column_name",
    );
    const enumValues = await prisma.$queryRawUnsafe(
      "select enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid where t.typname = 'HealthRecordType' and enumlabel in ('deworming','grooming') order by enumlabel",
    );
    const indexes = await prisma.$queryRawUnsafe(
      "select indexname from pg_indexes where schemaname = 'public' and tablename = 'health_records' and indexname in ('health_records_pet_deleted_record_date_idx','health_records_vet_id_idx') order by indexname",
    );
    const constraints = await prisma.$queryRawUnsafe(
      "select conname from pg_constraint where conname = 'health_records_vet_id_fkey'",
    );

    const summary = {
      columns: columns.map((row) => row.column_name),
      enumValues: enumValues.map((row) => row.enumlabel),
      indexes: indexes.map((row) => row.indexname),
      constraints: constraints.map((row) => row.conname),
    };

    const missing = [];
    for (const column of ['deleted_at', 'title', 'vet_id']) {
      if (!summary.columns.includes(column)) missing.push(`column:${column}`);
    }
    for (const enumValue of ['deworming', 'grooming']) {
      if (!summary.enumValues.includes(enumValue)) missing.push(`enum:${enumValue}`);
    }
    for (const index of [
      'health_records_pet_deleted_record_date_idx',
      'health_records_vet_id_idx',
    ]) {
      if (!summary.indexes.includes(index)) missing.push(`index:${index}`);
    }
    if (!summary.constraints.includes('health_records_vet_id_fkey')) {
      missing.push('constraint:health_records_vet_id_fkey');
    }

    if (missing.length > 0) {
      throw new Error(`Day 5 schema verification failed. Missing: ${missing.join(', ')}`);
    }

    return { prisma, summary };
  } catch (error) {
    await prisma.$disconnect();
    throw error;
  }
};

const runCrudSmoke = async (prisma) => {
  const suffix = Date.now();
  const email = `day5-db-unblock-${suffix}@pawmate.local`;

  const user = await prisma.user.create({
    data: {
      email,
      displayName: 'Day5 DB Unblock',
      emailVerified: true,
    },
  });
  const pet = await prisma.pet.create({
    data: {
      userId: user.id,
      name: 'DB Unblock Pet',
      species: 'dog',
    },
  });

  try {
    const created = await prisma.healthRecord.create({
      data: {
        petId: pet.id,
        createdByUserId: user.id,
        recordType: 'deworming',
        recordDate: new Date('2026-05-05T00:00:00.000Z'),
        title: 'Tay giun dinh ky',
        notes: 'Day 5 DB unblock smoke',
        attachments: [{ type: 'note', url: 'local://day5-db-unblock' }],
      },
    });
    const updated = await prisma.healthRecord.update({
      where: { id: created.id },
      data: { deletedAt: new Date() },
    });
    const visibleCountAfterSoftDelete = await prisma.healthRecord.count({
      where: {
        petId: pet.id,
        deletedAt: null,
      },
    });

    return {
      createdType: created.recordType,
      titlePersisted: created.title,
      softDeleted: Boolean(updated.deletedAt),
      visibleCountAfterSoftDelete,
    };
  } finally {
    await prisma.healthRecord.deleteMany({ where: { petId: pet.id } });
    await prisma.pet.delete({ where: { id: pet.id } });
    await prisma.user.delete({ where: { id: user.id } });
  }
};

const main = async () => {
  const parsedUrl = parseDatabaseUrl(migrationUrl);
  const port = Number(parsedUrl.port || 5432);
  let reachable = await tcpReachable(parsedUrl.hostname, port);

  if (!reachable && isLocalHost(parsedUrl.hostname)) {
    ensurePortablePostgres();
    reachable = await tcpReachable(parsedUrl.hostname, port, 3000);
  }

  if (!reachable) {
    throw new Error(
      `Database is not reachable at ${parsedUrl.hostname}:${port}. For Supabase cloud, configure PAWMATE_DB_MIGRATION_URL/DATABASE_DIRECT_URL with the direct or session-pooler Postgres connection string.`,
    );
  }

  applyPatchWithPsql(parsedUrl);
  const { prisma, summary } = await verifySchema(migrationUrl);

  try {
    const crudSmoke = await runCrudSmoke(prisma);
    console.log(
      JSON.stringify(
        {
          status: 'ok',
          target: {
            url: redactUrl(migrationUrl),
            host: parsedUrl.hostname,
            port,
            database: parsedUrl.pathname.replace(/^\//, '') || 'postgres',
          },
          schema: summary,
          crudSmoke,
        },
        null,
        2,
      ),
    );
  } finally {
    await prisma.$disconnect();
  }
};

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
