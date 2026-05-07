import { randomUUID } from 'node:crypto';

import { AppError } from '../../errors/app-error';
import { HEALTH_ERROR_CODES } from '../../errors/error-codes';
import { type PetRecord } from '../pets/pet-service';

export type HealthRecordType =
  | 'vaccination'
  | 'checkup'
  | 'deworming'
  | 'grooming'
  | 'medication'
  | 'allergy'
  | 'note';

export type HealthRecord = {
  id: string;
  petId: string;
  createdByUserId: string;
  type: HealthRecordType;
  date: string;
  title?: string;
  note?: string;
  vetId?: string;
  attachments: string[];
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
};

export type HealthRecordListInput = {
  limit?: number;
  cursor?: string;
  type?: string;
};

export type HealthRecordListResult = {
  items: HealthRecord[];
  nextCursor?: string;
  total: number;
  limit: number;
};

export type CreateHealthRecordInput = {
  type?: string;
  recordType?: string;
  date?: string;
  recordDate?: string;
  title?: string;
  note?: string;
  notes?: string;
  vetId?: string;
  attachments?: unknown;
};

export type UpdateHealthRecordInput = Partial<CreateHealthRecordInput>;

export type HealthRecordStore = {
  listByPet: (
    petId: string,
    input: {
      limit: number;
      cursor?: string;
      type?: HealthRecordType;
    },
  ) => Promise<HealthRecordListResult>;
  findById: (recordId: string) => Promise<HealthRecord | undefined>;
  save: (record: HealthRecord) => Promise<void>;
};

export type HealthRecordService = ReturnType<typeof createHealthRecordService>;

type PetReader = {
  get: (userId: string, petId: string) => Promise<PetRecord>;
};

const allowedHealthRecordTypes: HealthRecordType[] = [
  'vaccination',
  'checkup',
  'deworming',
  'grooming',
  'medication',
  'allergy',
  'note',
];

class InMemoryHealthRecordStore implements HealthRecordStore {
  private readonly records = new Map<string, HealthRecord>();

  async listByPet(
    petId: string,
    input: {
      limit: number;
      cursor?: string;
      type?: HealthRecordType;
    },
  ) {
    const sorted = [...this.records.values()]
      .filter(
        (record) =>
          record.petId === petId &&
          !record.deletedAt &&
          (!input.type || record.type === input.type),
      )
      .sort((left, right) => {
        const dateCompare = right.date.localeCompare(left.date);
        return dateCompare || right.createdAt.localeCompare(left.createdAt);
      });

    const startIndex = input.cursor
      ? sorted.findIndex((record) => record.id === input.cursor) + 1
      : 0;
    const safeStartIndex = Math.max(startIndex, 0);
    const page = sorted.slice(safeStartIndex, safeStartIndex + input.limit);

    return {
      items: page,
      nextCursor:
        safeStartIndex + input.limit < sorted.length
          ? page.at(-1)?.id
          : undefined,
      total: sorted.length,
      limit: input.limit,
    };
  }

  async findById(recordId: string) {
    return this.records.get(recordId);
  }

  async save(record: HealthRecord) {
    this.records.set(record.id, record);
  }
}

const validateType = (value?: string): HealthRecordType => {
  const normalized = value?.trim().toLowerCase();
  if (
    !normalized ||
    !allowedHealthRecordTypes.includes(normalized as HealthRecordType)
  ) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Loai su kien suc khoe khong hop le.',
      400,
      'type',
    );
  }

  return normalized as HealthRecordType;
};

const validateOptionalType = (value?: string): HealthRecordType | undefined => {
  if (value === undefined) {
    return undefined;
  }

  return validateType(value);
};

const validateDate = (value?: string, options: { required?: boolean } = {}) => {
  if (!value) {
    if (options.required) {
      throw new AppError(
        HEALTH_ERROR_CODES.invalidInput,
        'Ngay su kien suc khoe la bat buoc.',
        400,
        'date',
      );
    }
    return undefined;
  }

  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Ngay su kien suc khoe khong hop le.',
      400,
      'date',
    );
  }

  const [, yearValue, monthValue, dayValue] = match;
  const year = Number(yearValue);
  const month = Number(monthValue);
  const day = Number(dayValue);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Ngay su kien suc khoe khong hop le.',
      400,
      'date',
    );
  }

  return value;
};

const trimLimited = (
  value: string | undefined,
  field: string,
  maxLength: number,
) => {
  if (value === undefined) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return undefined;
  }

  if (trimmed.length > maxLength) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      `Truong ${field} vuot qua ${maxLength} ky tu.`,
      400,
      field,
    );
  }

  return trimmed;
};

const validateAttachments = (value: unknown) => {
  if (value === undefined) {
    return [];
  }

  if (!Array.isArray(value)) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Danh sach tep dinh kem khong hop le.',
      400,
      'attachments',
    );
  }

  if (value.length > 5) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Moi su kien suc khoe chi ho tro toi da 5 tep dinh kem.',
      400,
      'attachments',
    );
  }

  return value.map((item, index) => {
    const url = item?.toString().trim();
    if (!url || !/^https?:\/\//i.test(url)) {
      throw new AppError(
        HEALTH_ERROR_CODES.invalidInput,
        'Tep dinh kem phai la URL hop le.',
        400,
        `attachments.${index}`,
      );
    }
    return url;
  });
};

const validateLimit = (value?: number) => {
  const limit = value ?? 20;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Limit phai nam trong khoang 1-50.',
      400,
      'limit',
    );
  }

  return limit;
};

export const createHealthRecordService = (dependencies: {
  petReader: PetReader;
  store?: HealthRecordStore;
}) => {
  const store = dependencies.store ?? new InMemoryHealthRecordStore();

  const requireOwnedPet = (userId: string, petId: string) =>
    dependencies.petReader.get(userId, petId);

  const requireOwnedRecord = async (
    userId: string,
    petId: string,
    recordId: string,
  ) => {
    await requireOwnedPet(userId, petId);
    const record = await store.findById(recordId);
    if (!record || record.deletedAt || record.petId !== petId) {
      throw new AppError(
        HEALTH_ERROR_CODES.notFound,
        'Khong tim thay su kien suc khoe.',
        404,
      );
    }

    return record;
  };

  return {
    async list(
      userId: string,
      petId: string,
      input: HealthRecordListInput = {},
    ) {
      await requireOwnedPet(userId, petId);
      return store.listByPet(petId, {
        limit: validateLimit(input.limit),
        cursor: input.cursor?.trim() || undefined,
        type: validateOptionalType(input.type),
      });
    },

    async create(
      userId: string,
      petId: string,
      input: CreateHealthRecordInput,
    ) {
      await requireOwnedPet(userId, petId);
      const timestamp = new Date().toISOString();
      const record: HealthRecord = {
        id: randomUUID(),
        petId,
        createdByUserId: userId,
        type: validateType(input.type ?? input.recordType),
        date: validateDate(input.date ?? input.recordDate, { required: true })!,
        title: trimLimited(input.title, 'title', 120),
        note: trimLimited(input.note ?? input.notes, 'note', 1000),
        vetId: input.vetId?.trim() || undefined,
        attachments: validateAttachments(input.attachments),
        createdAt: timestamp,
        updatedAt: timestamp,
      };

      await store.save(record);
      return record;
    },

    async update(
      userId: string,
      petId: string,
      recordId: string,
      input: UpdateHealthRecordInput,
    ) {
      const existingRecord = await requireOwnedRecord(userId, petId, recordId);
      const nextRecord: HealthRecord = {
        ...existingRecord,
        type:
          input.type === undefined && input.recordType === undefined
            ? existingRecord.type
            : validateType(input.type ?? input.recordType),
        date:
          input.date === undefined && input.recordDate === undefined
            ? existingRecord.date
            : validateDate(input.date ?? input.recordDate, { required: true })!,
        title:
          input.title === undefined
            ? existingRecord.title
            : trimLimited(input.title, 'title', 120),
        note:
          input.note === undefined && input.notes === undefined
            ? existingRecord.note
            : trimLimited(input.note ?? input.notes, 'note', 1000),
        vetId:
          input.vetId === undefined
            ? existingRecord.vetId
            : input.vetId.trim() || undefined,
        attachments:
          input.attachments === undefined
            ? existingRecord.attachments
            : validateAttachments(input.attachments),
        updatedAt: new Date().toISOString(),
      };

      await store.save(nextRecord);
      return nextRecord;
    },

    async remove(userId: string, petId: string, recordId: string) {
      const existingRecord = await requireOwnedRecord(userId, petId, recordId);
      const timestamp = new Date().toISOString();
      await store.save({
        ...existingRecord,
        deletedAt: timestamp,
        updatedAt: timestamp,
      });
    },
  };
};
