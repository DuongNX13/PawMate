import { type FastifyPluginAsync } from 'fastify';

import { AppError } from '../errors/app-error';
import {
  HEALTH_ERROR_CODES,
  PET_ERROR_CODES,
  REMINDER_ERROR_CODES,
} from '../errors/error-codes';
import {
  readLocalPetPhoto,
  resolvePetPhotoContentType,
} from '../infrastructure/pet-photo-storage';
import { type AuthService } from '../services/auth/auth-service';
import {
  type CreateHealthRecordInput,
  type HealthRecordService,
  type UpdateHealthRecordInput,
} from '../services/health/health-record-service';
import {
  type CreatePetInput,
  type PetService,
  type UpdatePetInput,
  type UploadPetPhotoInput,
} from '../services/pets/pet-service';
import {
  type CreateReminderInput,
  type ReminderService,
  type SnoozeReminderInput,
  type UpdateReminderInput,
} from '../services/reminders/reminder-service';

type PetRouteOptions = {
  authService: AuthService;
  petService: PetService;
  healthRecordService: HealthRecordService;
  reminderService: ReminderService;
};

type HealthRecordListQuerystring = {
  limit?: string;
  cursor?: string;
  type?: string;
};

type ReminderListQuerystring = {
  limit?: string;
  cursor?: string;
  from?: string;
  to?: string;
  includeDone?: string;
};

const getUserIdFromRequest = (
  authService: AuthService,
  authorization?: string,
) => {
  if (!authorization?.startsWith('Bearer ')) {
    throw new AppError(
      PET_ERROR_CODES.unauthorized,
      'Ban can dang nhap de xem ho so thu cung.',
      401,
    );
  }

  const accessToken = authorization.replace('Bearer ', '').trim();
  return authService.verifyAccessToken(accessToken).userId;
};

const parseLimit = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!/^\d+$/.test(trimmed)) {
    throw new AppError(
      HEALTH_ERROR_CODES.invalidInput,
      'Truong limit phai la so nguyen hop le.',
      400,
      'limit',
    );
  }

  return Number(trimmed);
};

const parseHealthRecordListQuery = (query: HealthRecordListQuerystring) => ({
  limit: parseLimit(query.limit),
  cursor: query.cursor?.trim() || undefined,
  type: query.type?.trim() || undefined,
});

const parseReminderLimit = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const trimmed = value.trim();
  if (!/^\d+$/.test(trimmed)) {
    throw new AppError(
      REMINDER_ERROR_CODES.invalidInput,
      'Truong limit phai la so nguyen hop le.',
      400,
      'limit',
    );
  }

  return Number(trimmed);
};

const parseReminderBoolean = (value: string | undefined) => {
  if (value === undefined) {
    return undefined;
  }

  const normalized = value.trim().toLowerCase();
  if (['1', 'true', 'yes'].includes(normalized)) {
    return true;
  }
  if (['0', 'false', 'no'].includes(normalized)) {
    return false;
  }

  throw new AppError(
    REMINDER_ERROR_CODES.invalidInput,
    'Truong includeDone khong hop le.',
    400,
    'includeDone',
  );
};

const parseReminderListQuery = (query: ReminderListQuerystring) => ({
  limit: parseReminderLimit(query.limit),
  cursor: query.cursor?.trim() || undefined,
  from: query.from?.trim() || undefined,
  to: query.to?.trim() || undefined,
  includeDone: parseReminderBoolean(query.includeDone),
});

const petRoute: FastifyPluginAsync<PetRouteOptions> = async (app, options) => {
  app.get<{ Params: { petId: string; fileName: string } }>(
    '/assets/pet-photos/:petId/:fileName',
    async (request, reply) => {
      try {
        const fileContent = await readLocalPetPhoto(
          request.params.petId,
          request.params.fileName,
        );
        reply.type(resolvePetPhotoContentType(request.params.fileName));
        return await reply.send(fileContent);
      } catch {
        throw new AppError(
          PET_ERROR_CODES.notFound,
          'Khong tim thay anh thu cung.',
          404,
        );
      }
    },
  );

  app.get('/pets', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.petService.list(userId),
    };
  });

  app.post<{ Body: CreatePetInput }>('/pets', async (request, reply) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    const pet = await options.petService.create(userId, request.body);
    reply.code(201).send({ data: pet });
  });

  app.get<{ Params: { petId: string } }>('/pets/:petId', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.petService.get(userId, request.params.petId),
    };
  });

  app.put<{ Params: { petId: string }; Body: UpdatePetInput }>(
    '/pets/:petId',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.petService.update(
          userId,
          request.params.petId,
          request.body,
        ),
      };
    },
  );

  app.delete<{ Params: { petId: string } }>(
    '/pets/:petId',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      await options.petService.remove(userId, request.params.petId);
      reply.code(204).send();
    },
  );

  app.post<{ Params: { petId: string }; Body: UploadPetPhotoInput }>(
    '/pets/:petId/photo',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return options.petService.attachPhoto(
        userId,
        request.params.petId,
        request.body,
      );
    },
  );

  app.get<{
    Params: { petId: string };
    Querystring: HealthRecordListQuerystring;
  }>('/pets/:petId/health-records', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.healthRecordService.list(
        userId,
        request.params.petId,
        parseHealthRecordListQuery(request.query),
      ),
    };
  });

  app.post<{ Params: { petId: string }; Body: CreateHealthRecordInput }>(
    '/pets/:petId/health-records',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      const record = await options.healthRecordService.create(
        userId,
        request.params.petId,
        request.body,
      );
      reply.code(201).send({ data: record });
    },
  );

  app.put<{
    Params: { petId: string; recordId: string };
    Body: UpdateHealthRecordInput;
  }>('/pets/:petId/health-records/:recordId', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.healthRecordService.update(
        userId,
        request.params.petId,
        request.params.recordId,
        request.body,
      ),
    };
  });

  app.delete<{ Params: { petId: string; recordId: string } }>(
    '/pets/:petId/health-records/:recordId',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      await options.healthRecordService.remove(
        userId,
        request.params.petId,
        request.params.recordId,
      );
      reply.code(204).send();
    },
  );

  app.get<{
    Params: { petId: string };
    Querystring: ReminderListQuerystring;
  }>('/pets/:petId/reminders', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.reminderService.list(
        userId,
        request.params.petId,
        parseReminderListQuery(request.query),
      ),
    };
  });

  app.post<{ Params: { petId: string }; Body: CreateReminderInput }>(
    '/pets/:petId/reminders',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      const reminder = await options.reminderService.create(
        userId,
        request.params.petId,
        request.body,
      );
      reply.code(201).send({ data: reminder });
    },
  );

  app.patch<{
    Params: { petId: string; reminderId: string };
    Body: UpdateReminderInput;
  }>('/pets/:petId/reminders/:reminderId', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.reminderService.update(
        userId,
        request.params.petId,
        request.params.reminderId,
        request.body,
      ),
    };
  });

  app.delete<{ Params: { petId: string; reminderId: string } }>(
    '/pets/:petId/reminders/:reminderId',
    async (request, reply) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      await options.reminderService.remove(
        userId,
        request.params.petId,
        request.params.reminderId,
      );
      reply.code(204).send();
    },
  );

  app.post<{
    Params: { petId: string; reminderId: string };
    Body: SnoozeReminderInput;
  }>('/pets/:petId/reminders/:reminderId/snooze', async (request) => {
    const userId = getUserIdFromRequest(
      options.authService,
      request.headers.authorization,
    );

    return {
      data: await options.reminderService.snooze(
        userId,
        request.params.petId,
        request.params.reminderId,
        request.body,
      ),
    };
  });

  app.post<{ Params: { petId: string; reminderId: string } }>(
    '/pets/:petId/reminders/:reminderId/mark-done',
    async (request) => {
      const userId = getUserIdFromRequest(
        options.authService,
        request.headers.authorization,
      );

      return {
        data: await options.reminderService.markDone(
          userId,
          request.params.petId,
          request.params.reminderId,
        ),
      };
    },
  );
};

export default petRoute;
