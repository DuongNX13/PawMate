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

export type PetSpecies = 'dog' | 'cat' | 'other';

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
    microchip: string,
    ignorePetId?: string,
  ) => Promise<boolean>;
};

export type CreatePetInput = {
  name: string;
  species: string;
  breed: string;
  gender?: string;
  dob?: string;
  weight?: number;
  color: string;
  microchip?: string;
  isNeutered?: boolean;
  healthStatus?: string;
};

export type UpdatePetInput = {
  name?: string | null;
  species?: string | null;
  breed?: string | null;
  gender?: string | null;
  dob?: string | null;
  weight?: number | null;
  color?: string | null;
  microchip?: string | null;
  isNeutered?: boolean | null;
  healthStatus?: string | null;
};

export type UploadPetPhotoInput = {
  fileName: string;
  contentType?: string;
  base64Data?: string;
};

export type PetService = ReturnType<typeof createPetService>;

const allowedSpecies: PetSpecies[] = ['dog', 'cat', 'other'];
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

  async hasMicrochipConflict(microchip: string, ignorePetId?: string) {
    return [...this.pets.values()].some(
      (pet) =>
        pet.id !== ignorePetId && !pet.deletedAt && pet.microchip === microchip,
    );
  }
}

export const createPetService = (
  config: AppConfig,
  dependencies: {
    store?: PetStore;
    savePhoto?: typeof saveLocalPetPhoto;
    buildPhotoUrl?: typeof buildLocalPetPhotoUrl;
  } = {},
) => {
  const store = dependencies.store ?? new InMemoryPetStore();
  const savePhoto = dependencies.savePhoto ?? saveLocalPetPhoto;
  const buildPhotoUrl = dependencies.buildPhotoUrl ?? buildLocalPetPhotoUrl;

  const validateRequiredText = (
    value: string | null | undefined,
    options: {
      field: 'name' | 'breed' | 'color';
      maxLength: number;
      errorCode:
        | typeof PET_ERROR_CODES.invalidName
        | typeof PET_ERROR_CODES.invalidBreed
        | typeof PET_ERROR_CODES.invalidColor;
      label: string;
    },
  ) => {
    const normalized = value?.trim();
    if (!normalized || normalized.length > options.maxLength) {
      throw new AppError(
        options.errorCode,
        `${options.label} phải có từ 1 đến ${options.maxLength} ký tự.`,
        400,
        options.field,
      );
    }
    return normalized;
  };

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

  const validateWeight = (weight?: number | null) => {
    if (weight === undefined || weight === null) {
      return undefined;
    }

    if (!Number.isFinite(weight) || weight < 0.1 || weight > 99.9) {
      throw new AppError(
        PET_ERROR_CODES.invalidWeight,
        'Cân nặng phải từ 0.1 đến 99.9 kg.',
        400,
        'weight',
      );
    }

    return Number(weight.toFixed(2));
  };

  const validateDate = (value?: string | null) => {
    if (value === undefined || value === null || value.trim() === '') {
      return undefined;
    }

    const normalized = value.trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(normalized)) {
      throw new AppError(
        PET_ERROR_CODES.invalidDate,
        'Ngày sinh phải theo định dạng YYYY-MM-DD.',
        400,
        'dob',
      );
    }

    const [year, month, day] = normalized.split('-').map(Number);
    const parsed = new Date(Date.UTC(year, month - 1, day));

    if (
      Number.isNaN(parsed.getTime()) ||
      parsed.getUTCFullYear() !== year ||
      parsed.getUTCMonth() !== month - 1 ||
      parsed.getUTCDate() !== day ||
      parsed.getTime() > Date.now()
    ) {
      throw new AppError(
        PET_ERROR_CODES.invalidDate,
        'Ngày sinh không hợp lệ hoặc lớn hơn ngày hiện tại.',
        400,
        'dob',
      );
    }

    return normalized;
  };

  const validateMicrochip = (value?: string | null) => {
    const normalized = value?.trim();
    if (!normalized) {
      return undefined;
    }
    if (normalized.length > 32 || !/^[A-Za-z0-9-]+$/.test(normalized)) {
      throw new AppError(
        PET_ERROR_CODES.invalidMicrochip,
        'Số microchip chỉ gồm chữ, số, dấu gạch ngang và tối đa 32 ký tự.',
        400,
        'microchip',
      );
    }
    return normalized;
  };

  const decodePhotoContent = (base64Data?: string) => {
    if (!base64Data?.trim()) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Nội dung ảnh là bắt buộc.',
        400,
        'base64Data',
      );
    }

    const normalized = base64Data.replace(/^data:[^;]+;base64,/, '').trim();
    if (
      !normalized ||
      normalized.length % 4 !== 0 ||
      !/^[A-Za-z0-9+/]+={0,2}$/.test(normalized)
    ) {
      throw new AppError(
        PET_ERROR_CODES.invalidPhotoReference,
        'Nội dung ảnh không hợp lệ.',
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

  const updatePetIdentity = (pet: PetRecord, input: UpdatePetInput) => ({
    name:
      input.name === undefined
        ? pet.name
        : validateRequiredText(input.name, {
            field: 'name',
            maxLength: 50,
            errorCode: PET_ERROR_CODES.invalidName,
            label: 'Tên thú cưng',
          }),
    species: input.species ? validateSpecies(input.species) : pet.species,
    breed:
      input.breed === undefined
        ? pet.breed
        : validateRequiredText(input.breed, {
            field: 'breed',
            maxLength: 80,
            errorCode: PET_ERROR_CODES.invalidBreed,
            label: 'Giống loài',
          }),
    gender: input.gender ? validateGender(input.gender) : pet.gender,
  });

  const updatePetCharacteristics = (
    pet: PetRecord,
    input: UpdatePetInput,
    microchip: string | undefined,
  ) => ({
    dob: input.dob === undefined ? pet.dob : validateDate(input.dob),
    weight:
      input.weight === undefined ? pet.weight : validateWeight(input.weight),
    color:
      input.color === undefined
        ? pet.color
        : validateRequiredText(input.color, {
            field: 'color',
            maxLength: 80,
            errorCode: PET_ERROR_CODES.invalidColor,
            label: 'Màu lông',
          }),
    microchip: input.microchip === undefined ? pet.microchip : microchip,
    isNeutered:
      input.isNeutered === undefined || input.isNeutered === null
        ? pet.isNeutered
        : input.isNeutered,
    healthStatus:
      input.healthStatus === undefined || input.healthStatus === null
        ? pet.healthStatus
        : validateHealthStatus(input.healthStatus),
  });

  return {
    async list(userId: string) {
      return store.listByUser(userId);
    },

    async get(userId: string, petId: string) {
      return requirePetForUser(userId, petId);
    },

    async create(userId: string, input: CreatePetInput) {
      const name = validateRequiredText(input.name, {
        field: 'name',
        maxLength: 50,
        errorCode: PET_ERROR_CODES.invalidName,
        label: 'Tên thú cưng',
      });
      const species = validateSpecies(input.species);
      const breed = validateRequiredText(input.breed, {
        field: 'breed',
        maxLength: 80,
        errorCode: PET_ERROR_CODES.invalidBreed,
        label: 'Giống loài',
      });
      const color = validateRequiredText(input.color, {
        field: 'color',
        maxLength: 80,
        errorCode: PET_ERROR_CODES.invalidColor,
        label: 'Màu lông',
      });
      const microchip = validateMicrochip(input.microchip);

      if (microchip && (await store.hasMicrochipConflict(microchip))) {
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
        species,
        breed,
        gender: validateGender(input.gender),
        dob: validateDate(input.dob),
        weight: validateWeight(input.weight),
        color,
        microchip,
        isNeutered: Boolean(input.isNeutered),
        healthStatus: validateHealthStatus(input.healthStatus),
        createdAt: timestamp,
        updatedAt: timestamp,
      };

      await store.save(pet);
      return pet;
    },

    async update(userId: string, petId: string, input: UpdatePetInput) {
      const existingPet = await requirePetForUser(userId, petId);
      const microchip = validateMicrochip(input.microchip);

      if (microchip && (await store.hasMicrochipConflict(microchip, petId))) {
        throw new AppError(
          PET_ERROR_CODES.duplicateMicrochip,
          'Ma microchip da ton tai.',
          409,
          'microchip',
        );
      }

      const nextPet: PetRecord = {
        ...existingPet,
        ...updatePetIdentity(existingPet, input),
        ...updatePetCharacteristics(existingPet, input, microchip),
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

    async attachPhoto(
      userId: string,
      petId: string,
      input: UploadPetPhotoInput,
    ) {
      const pet = await requirePetForUser(userId, petId);
      const photo = validatePhotoMetadata(input);

      try {
        await savePhoto(petId, photo.fileName, photo.content);
      } catch {
        throw new AppError(
          PET_ERROR_CODES.photoStorageFailure,
          'Không thể lưu ảnh thú cưng. Vui lòng thử lại.',
          503,
          'base64Data',
        );
      }

      const avatarUrl = buildPhotoUrl(config, petId, photo.fileName);
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
