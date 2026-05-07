import { loadEnv } from '../config/env';
import {
  createDueReminderJobResources,
  parseProcessDueReminderArgs,
  processDueRemindersOnce,
} from './process-due-reminders-job';

const main = async () => {
  const options = parseProcessDueReminderArgs(process.argv.slice(2));
  const resources = createDueReminderJobResources(loadEnv());

  try {
    const summary = await processDueRemindersOnce(
      resources.reminderService,
      options,
    );
    process.stdout.write(`${JSON.stringify({ data: summary })}\n`);
  } finally {
    await resources.close();
  }
};

main().catch((error) => {
  process.stderr.write(
    `${JSON.stringify({
      success: false,
      error: {
        message: error instanceof Error ? error.message : 'Unknown error',
      },
    })}\n`,
  );
  process.exit(1);
});
