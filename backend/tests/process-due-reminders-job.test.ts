import {
  parseProcessDueReminderArgs,
  processDueRemindersOnce,
} from '../src/jobs/process-due-reminders-job';
import { type ReminderRecord } from '../src/services/reminders/reminder-service';

const buildReminder = (id: string): ReminderRecord => ({
  id,
  petId: '1a299045-9b41-4f33-9929-000000000001',
  createdByUserId: '1a299045-9b41-4f33-9929-000000000002',
  title: 'Tiem phong',
  note: 'Den lich tiem phong.',
  reminderAt: '2026-05-05T08:00:00.000Z',
  nextTriggerAt: '2026-05-05T08:00:00.000Z',
  repeatRule: 'none',
  timezone: 'Asia/Bangkok',
  status: 'sent',
  lastTriggeredAt: '2026-05-05T08:30:00.000Z',
  createdAt: '2026-05-04T08:00:00.000Z',
  updatedAt: '2026-05-05T08:30:00.000Z',
});

describe('process due reminders job', () => {
  it('runs reminder processing once and returns a safe summary', async () => {
    const now = new Date('2026-05-05T08:30:00.000Z');
    const service = {
      processDueReminders: jest.fn().mockResolvedValue({
        processedCount: 2,
        items: [buildReminder('reminder-1'), buildReminder('reminder-2')],
      }),
    };

    const summary = await processDueRemindersOnce(service, {
      now,
      limit: 25,
    });

    expect(service.processDueReminders).toHaveBeenCalledWith(now, 25);
    expect(summary).toEqual({
      processedCount: 2,
      reminderIds: ['reminder-1', 'reminder-2'],
      ranAt: '2026-05-05T08:30:00.000Z',
      limit: 25,
    });
  });

  it('uses the production-safe default limit', async () => {
    const service = {
      processDueReminders: jest.fn().mockResolvedValue({
        processedCount: 0,
        items: [],
      }),
    };

    await processDueRemindersOnce(service, {
      now: new Date('2026-05-05T08:30:00.000Z'),
    });

    expect(service.processDueReminders).toHaveBeenCalledWith(
      new Date('2026-05-05T08:30:00.000Z'),
      100,
    );
  });

  it('rejects invalid limits before touching reminder processing', async () => {
    const service = {
      processDueReminders: jest.fn(),
    };

    await expect(
      processDueRemindersOnce(service, { limit: 0 }),
    ).rejects.toThrow('Reminder processing limit must be an integer from 1 to 500.');
    expect(service.processDueReminders).not.toHaveBeenCalled();
  });

  it('parses CLI limit and fixed now arguments', () => {
    expect(
      parseProcessDueReminderArgs([
        '--limit',
        '50',
        '--now',
        '2026-05-05T08:30:00.000Z',
      ]),
    ).toEqual({
      limit: 50,
      now: new Date('2026-05-05T08:30:00.000Z'),
    });
  });

  it('rejects unknown CLI arguments', () => {
    expect(() => parseProcessDueReminderArgs(['--bad-flag'])).toThrow(
      'Unknown argument: --bad-flag',
    );
  });
});
