const fs = require('fs');
const path = require('path');

const dotenv = require('dotenv');
const { PrismaClient } = require('@prisma/client');

const backendRoot = path.resolve(__dirname, '..');
const patchFile = path.join(
  backendRoot,
  'prisma',
  'sql',
  'day6_reminder_notification_patch.sql',
);

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
      'No database URL found. Set PAWMATE_DB_MIGRATION_URL, DATABASE_DIRECT_URL, SUPABASE_DATABASE_URL, SUPABASE_DB_URL, or DATABASE_URL.',
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

const readSqlStatements = () =>
  fs
    .readFileSync(patchFile, 'utf8')
    .split(/;\s*(?:\r?\n|$)/)
    .map((statement) => statement.trim())
    .filter(Boolean);

const applyPatch = async (prisma) => {
  const statements = readSqlStatements();
  for (const statement of statements) {
    await prisma.$executeRawUnsafe(statement);
  }
  return statements.length;
};

const verifySchema = async (prisma) => {
  const columns = await prisma.$queryRawUnsafe(
    "select table_name, column_name from information_schema.columns where table_schema = 'public' and ((table_name = 'reminders' and column_name in ('note','next_trigger_at','last_triggered_at','timezone','completed_at','cancelled_at','snoozed_until','deleted_at')) or (table_name = 'notifications' and column_name = 'dismissed_at')) order by table_name, column_name",
  );
  const enumValues = await prisma.$queryRawUnsafe(
    "select enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid where t.typname = 'ReminderStatus' and enumlabel = 'done'",
  );
  const indexes = await prisma.$queryRawUnsafe(
    "select indexname from pg_indexes where schemaname = 'public' and indexname in ('reminders_pet_deleted_reminder_at_idx','reminders_created_by_status_next_trigger_idx','notifications_user_dismissed_read_created_idx') order by indexname",
  );

  const columnKeys = columns.map(
    (row) => `${row.table_name}.${row.column_name}`,
  );
  const summary = {
    columns: columnKeys,
    enumValues: enumValues.map((row) => row.enumlabel),
    indexes: indexes.map((row) => row.indexname),
  };
  const missing = [];

  for (const column of [
    'reminders.cancelled_at',
    'reminders.completed_at',
    'reminders.deleted_at',
    'reminders.last_triggered_at',
    'reminders.next_trigger_at',
    'reminders.note',
    'reminders.snoozed_until',
    'reminders.timezone',
    'notifications.dismissed_at',
  ]) {
    if (!summary.columns.includes(column)) {
      missing.push(`column:${column}`);
    }
  }

  if (!summary.enumValues.includes('done')) {
    missing.push('enum:ReminderStatus.done');
  }

  for (const index of [
    'notifications_user_dismissed_read_created_idx',
    'reminders_created_by_status_next_trigger_idx',
    'reminders_pet_deleted_reminder_at_idx',
  ]) {
    if (!summary.indexes.includes(index)) {
      missing.push(`index:${index}`);
    }
  }

  if (missing.length > 0) {
    throw new Error(`Day 6 schema verification failed. Missing: ${missing.join(', ')}`);
  }

  return summary;
};

const runCrudSmoke = async (prisma) => {
  const suffix = Date.now();
  const email = `day6-cloud-proof-${suffix}@pawmate.local`;
  const user = await prisma.user.create({
    data: {
      email,
      displayName: 'Day6 Cloud Proof',
      emailVerified: true,
    },
  });
  const pet = await prisma.pet.create({
    data: {
      userId: user.id,
      name: 'Reminder Proof Pet',
      species: 'dog',
    },
  });

  try {
    const reminder = await prisma.reminder.create({
      data: {
        petId: pet.id,
        createdByUserId: user.id,
        title: 'Day 6 reminder proof',
        note: 'Schema proof reminder.',
        reminderAt: new Date('2026-05-05T08:00:00.000Z'),
        nextTriggerAt: new Date('2026-05-05T08:00:00.000Z'),
        repeatRule: 'none',
        timezone: 'Asia/Bangkok',
        status: 'scheduled',
      },
    });
    const notification = await prisma.notification.create({
      data: {
        userId: user.id,
        petId: pet.id,
        reminderId: reminder.id,
        type: 'reminder_due',
        title: 'Day 6 notification proof',
        body: 'Reminder notification proof.',
        deliveredAt: new Date('2026-05-05T08:00:00.000Z'),
      },
    });
    const dismissedNotification = await prisma.notification.update({
      where: { id: notification.id },
      data: {
        readAt: new Date('2026-05-05T08:01:00.000Z'),
        dismissedAt: new Date('2026-05-05T08:02:00.000Z'),
      },
    });
    const doneReminder = await prisma.reminder.update({
      where: { id: reminder.id },
      data: {
        status: 'done',
        completedAt: new Date('2026-05-05T08:03:00.000Z'),
        nextTriggerAt: null,
      },
    });

    return {
      reminderStatus: doneReminder.status,
      reminderCompleted: Boolean(doneReminder.completedAt),
      notificationDismissed: Boolean(dismissedNotification.dismissedAt),
    };
  } finally {
    await prisma.notification.deleteMany({ where: { userId: user.id } });
    await prisma.reminder.deleteMany({ where: { createdByUserId: user.id } });
    await prisma.pet.delete({ where: { id: pet.id } });
    await prisma.user.delete({ where: { id: user.id } });
  }
};

const main = async () => {
  const parsedUrl = parseDatabaseUrl(migrationUrl);
  const verifyOnly = process.argv.includes('--verify-only');
  const prisma = new PrismaClient({
    datasources: {
      db: {
        url: migrationUrl,
      },
    },
  });

  try {
    const appliedStatements = verifyOnly ? 0 : await applyPatch(prisma);
    const schema = await verifySchema(prisma);
    const crudSmoke = await runCrudSmoke(prisma);

    console.log(
      JSON.stringify(
        {
          status: 'ok',
          target: {
            url: redactUrl(migrationUrl),
            host: parsedUrl.hostname,
            port: Number(parsedUrl.port || 5432),
            database: parsedUrl.pathname.replace(/^\//, '') || 'postgres',
          },
          mode: verifyOnly ? 'verify-only' : 'apply-and-verify',
          appliedStatements,
          schema,
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
