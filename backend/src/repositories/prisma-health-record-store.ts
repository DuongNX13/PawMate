import { $Enums, PrismaClient } from '@prisma/client';

import {
  type HealthRecord,
  type HealthRecordListResult,
  type HealthRecordStore,
  type HealthRecordType,
} from '../services/health/health-record-service';

const mapHealthRecord = (record: {
  id: string;
  petId: string;
  createdByUserId: string;
  recordType: $Enums.HealthRecordType;
  recordDate: Date;
  title: string | null;
  notes: string | null;
  vetId: string | null;
  attachments: unknown;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}): HealthRecord => ({
  id: record.id,
  petId: record.petId,
  createdByUserId: record.createdByUserId,
  type: record.recordType as HealthRecordType,
  date: record.recordDate.toISOString().slice(0, 10),
  title: record.title ?? undefined,
  note: record.notes ?? undefined,
  vetId: record.vetId ?? undefined,
  attachments: Array.isArray(record.attachments)
    ? record.attachments.map((item) => item.toString())
    : [],
  createdAt: record.createdAt.toISOString(),
  updatedAt: record.updatedAt.toISOString(),
  deletedAt: record.deletedAt?.toISOString(),
});

export class PrismaHealthRecordStore implements HealthRecordStore {
  constructor(private readonly prisma: PrismaClient) {}

  async listByPet(
    petId: string,
    input: {
      limit: number;
      cursor?: string;
      type?: HealthRecordType;
    },
  ): Promise<HealthRecordListResult> {
    const where = {
      petId,
      deletedAt: null,
      ...(input.type
        ? { recordType: input.type as $Enums.HealthRecordType }
        : {}),
    };
    const [records, total] = await Promise.all([
      this.prisma.healthRecord.findMany({
        where,
        orderBy: [{ recordDate: 'desc' }, { createdAt: 'desc' }],
        take: input.limit + 1,
        ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
      }),
      this.prisma.healthRecord.count({ where }),
    ]);
    const page = records.slice(0, input.limit);

    return {
      items: page.map(mapHealthRecord),
      nextCursor: records.length > input.limit ? page.at(-1)?.id : undefined,
      total,
      limit: input.limit,
    };
  }

  async findById(recordId: string) {
    const record = await this.prisma.healthRecord.findUnique({
      where: { id: recordId },
    });

    return record ? mapHealthRecord(record) : undefined;
  }

  async save(record: HealthRecord) {
    await this.prisma.healthRecord.upsert({
      where: { id: record.id },
      update: {
        petId: record.petId,
        createdByUserId: record.createdByUserId,
        recordType: record.type as $Enums.HealthRecordType,
        recordDate: new Date(record.date),
        title: record.title,
        notes: record.note,
        vetId: record.vetId,
        attachments: record.attachments,
        updatedAt: new Date(record.updatedAt),
        deletedAt: record.deletedAt ? new Date(record.deletedAt) : null,
      },
      create: {
        id: record.id,
        petId: record.petId,
        createdByUserId: record.createdByUserId,
        recordType: record.type as $Enums.HealthRecordType,
        recordDate: new Date(record.date),
        title: record.title,
        notes: record.note,
        vetId: record.vetId,
        attachments: record.attachments,
        createdAt: new Date(record.createdAt),
        updatedAt: new Date(record.updatedAt),
        deletedAt: record.deletedAt ? new Date(record.deletedAt) : null,
      },
    });
  }
}
