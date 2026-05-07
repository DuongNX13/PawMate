import { randomUUID } from 'node:crypto';

import { type AppConfig } from '../../config/env';
import { AppError } from '../../errors/app-error';
import { PET_ERROR_CODES } from '../../errors/error-codes';
import {
  allowedPetPhotoContentTypes,
  buildLocalPetPhotoUrl,
  normalizePetPhotoFileName,
  saveLocalPetPhoto,
} from '../../infrastructure/pet-photo-storage';

export type PetSpecies = 'dog' | 'cat' | 'bird' | 'rabbit' | 'other';

export type PetGender = 'male' | 'female' | 'unknown';

export type PetHealthStatus =
  | 'healthy'
  | 'monitoring'
  | 'chronic'
  | 'recovery'
  | 'unknown';

export type PetRecord = {
  id: string;
  userId: string;
  name: string;
  species: PetSpecies;
  breed?: string;
  gender: PetGender;
  dob?: string;
  weight?: number;
  color?: string;
  microchip?: string;
  isNeutered: boolean;
  avatarUrl?: string;
  healthStatus: PetHealthStatus;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
};

export type PetStore = {
  listByUser: (userId: string) => Promise<PetRecord[]>;
  findById: (petId: string) => Promise<PetRecord | undefined>;
  save: (pet: PetRecord) => Promise<void>;
  hasMicrochipConflict: (
    userId: string,
    microchip: string,
    ignorePetId?: string,
  ) => Promise<boolean>;
};

export type CreatePetInput = {
  name: string;
  species: string;
  breed?: string;
  gender?: string;
  dob?: string;
  weight?: number;
  color?: string;
  microchip?: string;
  isNeutered?: boolean;
  avatarUrl?: string;
  healthStatus?: string;
};

export type UpdatePetInput = Partial<CreatePetInput>;

export type UploadPetPhotoInput = {
  fileName: string;
  contentType?: string;
  base64Data?: string;
};

export type PetService = ReturnType<typeof createPetService>;

const allowedSpecies: PetSpecies[] = ['dog', 'cat', 'bird', 'rabbit', 'other'];
const allowedGenders: PetGender[] = ['male', 'female', 'unknown'];
const allowedHealthStatuses: PetHealthStatus[] = [
  'healthy',
  'monitoring',
  'chronic',
  'recovery',
  'unknown',
];

class InMemoryPetStore implements PetStore {
  private readonly pets = new Map<string, PetRecord>();

  async listByUser(userId: string) {
    return [...this.pets.values()]
      .filter((pet) => pet.userId === userId && !pet.deletedAt)
      .sort((left, right) => right.createdAt.localeCompare(left.createdAt));
  }

  async findById(petId: string) {
    return this.pets.get(petId);
  }

  async save(pet: PetRecord) {
    this.pets.set(pet.id, pet);
  }

  async hasMicrochipConflict(
    userId: string,
    microchip: string,
    ignorePetId?: string,
  ) {
    return [...this.pets.values()].some(
      (pet) =>
        pet.userId === userId &&
        pet.id !== ignorePetId &&
        !pet.deletedAt &&
        pet.microchip === microchip,
    );
  }
}

export const createPetService = (
  config: AppConfig,
  dependencies: {
    store?: PetStore;
  } = {},
) => {
  const store = dependencies.store ?? new InMemoryPetStore();

  const validateSpecies = (species?: string): PetSpecies => {
    if (!species || !allowedSpecies.includes(species as PetSpecies)) {
      throw new AppError(
        PET_ERROR_CODES.invalidSpecies,
        'Loai thu cung khong hop le.',
        400,
        'species',
      );
    }

    return species as PetSpecies;
  };

  const validateGender = (
    gender?: string,
    options: { required?: boolean } = {},
  ): PetGender => {
    if (options.required && !gender) {
      throw new AppError(
        PET_ERROR_CODES.invalidGender,
        'Gioi tinh thu cung la bat buoc.',
        400,
        'gender',
      );
    }

    const value = gender ?? 'unknown';

    if (!allowedGenders.includes(value as PetGender)) {
      throw new AppError(
        PET_ERROR_CODES.invalidGender,
        'Gioi tinh thu cung khong hop le.',
        400,
        'gender',
      );
    }

    return value as PetGender;
  };

  const validateHealthStatus = (healthStatus?: string): PetHealthStatus => {
    const value = healthStatus ?? 'healthy';

    if (!allowedHealthStatuses.includes(value as PetHealthStatus)) {
      throw new AppError(
        PET_ERROR_CODES.invalidHealthStatus,
        'Tinh trang suc khoe khong hop le.',
        400,
        'healthStatus',
      );
    }

    return value as PetHealthStatus;
  };

  const validateWeight = (weight?: number) => {
    if (weight === undefined) {
      return undefined;
    }

    if (!Number.isFinite(weight) || weight <= 0) {
      throw new AppError(
        PET_ERROR_CODES.invalidWeight,
        'Can nang phai lon hon 0.',
        400,
        'weight',
      );
    }

    return Number(weight.toFixed(2));
  };

  const validateDate = (value?: string) => {
    if (!value) {
      return undefined;
    }

    const parsed = new Date(value);

    if (Number.isNaN(parsed.getTime())) {
      throw new AppError(
        PET_ERROR_CODES.invalidDate,
        'Ngay thang khong hop le.',
        400,
        'dob',
      );
    }

    return parsed.toISOString().slice(0, 10);
  };

  const decodePhotoContent = (base64Data?: string) => {
    if (!base64Data) {
      return undefined;
    }

    const normalized = base64Data.replace(/^data:[^;]+;base64,/, '').trim();
    if (!normalized) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Noi dung anh khong hop le.',
        400,
        'base64Data',
      );
    }

    return Buffer.from(normalized, 'base64');
  };

  const validatePhotoMetadata = (input: UploadPetPhotoInput) => {
    const content = decodePhotoContent(input.base64Data);
    const contentType = input.contentType?.trim();

    if (!input.fileName.trim()) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Ten anh khong hop le.',
        400,
        'fileName',
      );
    }

    if (!content) {
      return {
        content: undefined,
        contentType: undefined,
        fileName: normalizePetPhotoFileName(input.fileName),
      };
    }

    if (!contentType || !allowedPetPhotoContentTypes.has(contentType)) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Loai anh chi ho tro JPEG, PNG, hoac WEBP.',
        400,
        'contentType',
      );
    }

    if (content.byteLength > 5 * 1024 * 1024) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Kich thuoc anh vuot qua 5MB.',
        400,
        'base64Data',
      );
    }

    return {
      content,
      contentType,
      fileName: normalizePetPhotoFileName(input.fileName, contentType),
    };
  };

  const requirePetForUser = async (userId: string, petId: string) => {
    const pet = await store.findById(petId);

    if (!pet || pet.deletedAt) {
      throw new AppError(
        PET_ERROR_CODES.notFound,
        'Khong tim thay ho so thu cung.',
        404,
      );
    }

    if (pet.userId !== userId) {
      throw new AppError(
        PET_ERROR_CODES.forbidden,
        'Ban khong co quyen sua ho so nay.',
        403,
      );
    }

    return pet;
  };

  return {
    async list(userId: string) {
      return store.listByUser(userId);
    },

    async get(userId: string, petId: string) {
      return requirePetForUser(userId, petId);
    },

    async create(userId: string, input: CreatePetInput) {
      const name = input.name?.trim();
      if (!name) {
        throw new AppError(
          PET_ERROR_CODES.invalidSpecies,
          'Ten thu cung la bat buoc.',
          400,
          'name',
        );
      }

      const microchip = input.microchip?.trim() || undefined;

      if (microchip && (await store.hasMicrochipConflict(userId, microchip))) {
        throw new AppError(
          PET_ERROR_CODES.duplicateMicrochip,
          'Ma microchip da ton tai.',
          409,
          'microchip',
        );
      }

      const timestamp = new Date().toISOString();
      const pet: PetRecord = {
        id: randomUUID(),
        userId,
        name,
        species: validateSpecies(input.species),
        breed: input.breed?.trim() || undefined,
        gender: validateGender(input.gender, { required: true }),
        dob: validateDate(input.dob),
        weight: validateWeight(input.weight),
        color: input.color?.trim() || undefined,
        microchip,
        isNeutered: Boolean(input.isNeutered),
        avatarUrl: input.avatarUrl?.trim() || undefined,
        healthStatus: validateHealthStatus(input.healthStatus),
        createdAt: timestamp,
        updatedAt: timestamp,
      };

      await store.save(pet);
      return pet;
    },

    async update(userId: string, petId: string, input: UpdatePetInput) {
      const existingPet = await requirePetForUser(userId, petId);
      const microchip = input.microchip?.trim();

      if (
        microchip &&
        (await store.hasMicrochipConflict(userId, microchip, petId))
      ) {
        throw new AppError(
          PET_ERROR_CODES.duplicateMicrochip,
          'Ma microchip da ton tai.',
          409,
          'microchip',
        );
      }

      const nextPet: PetRecord = {
        ...existingPet,
        name: input.name?.trim() || existingPet.name,
        species: input.species
          ? validateSpecies(input.species)
          : existingPet.species,
        breed:
          input.breed === undefined
            ? existingPet.breed
            : input.breed.trim() || undefined,
        gender: input.gender
          ? validateGender(input.gender)
          : existingPet.gender,
        dob: input.dob === undefined ? existingPet.dob : validateDate(input.dob),
        weight:
          input.weight === undefined
            ? existingPet.weight
            : validateWeight(input.weight),
        color:
          input.color === undefined
            ? existingPet.color
            : input.color.trim() || undefined,
        microchip:
          input.microchip === undefined ? existingPet.microchip : microchip,
        isNeutered:
          input.isNeutered === undefined
            ? existingPet.isNeutered
            : input.isNeutered,
        avatarUrl:
          input.avatarUrl === undefined
            ? existingPet.avatarUrl
            : input.avatarUrl.trim() || undefined,
        healthStatus:
          input.healthStatus === undefined
            ? existingPet.healthStatus
            : validateHealthStatus(input.healthStatus),
        updatedAt: new Date().toISOString(),
      };

      await store.save(nextPet);
      return nextPet;
    },

    async remove(userId: string, petId: string) {
      const existingPet = await requirePetForUser(userId, petId);
      const timestamp = new Date().toISOString();
      await store.save({
        ...existingPet,
        deletedAt: timestamp,
        updatedAt: timestamp,
      });
    },

    async attachPhoto(userId: string, petId: string, input: UploadPetPhotoInput) {
      const pet = await requirePetForUser(userId, petId);
      const photo = validatePhotoMetadata(input);

      if (photo.content) {
        await saveLocalPetPhoto(petId, photo.fileName, photo.content);
      }

      const avatarUrl = photo.content
        ? buildLocalPetPhotoUrl(config, petId, photo.fileName)
        : buildLocalPetPhotoUrl(config, petId, photo.fileName);
      const updatedPet = {
        ...pet,
        avatarUrl,
        updatedAt: new Date().toISOString(),
      };
      await store.save(updatedPet);
      return {
        avatarUrl,
        pet: updatedPet,
      };
    },
  };
};
