import {
  $Enums,
  PrismaClient,
} from '@prisma/client';

import { type PetRecord, type PetStore } from '../services/pets/pet-service';

const mapPet = (pet: {
  id: string;
  userId: string;
  name: string;
  species: $Enums.PetSpecies;
  breed: string | null;
  gender: $Enums.PetGender;
  dob: Date | null;
  weightKg: { toNumber: () => number } | null;
  color: string | null;
  microchipNumber: string | null;
  isNeutered: boolean;
  avatarUrl: string | null;
  healthStatus: $Enums.PetHealthStatus;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
}): PetRecord => ({
  id: pet.id,
  userId: pet.userId,
  name: pet.name,
  species: pet.species,
  breed: pet.breed ?? undefined,
  gender: pet.gender,
  dob: pet.dob ? pet.dob.toISOString().slice(0, 10) : undefined,
  weight: pet.weightKg ? pet.weightKg.toNumber() : undefined,
  color: pet.color ?? undefined,
  microchip: pet.microchipNumber ?? undefined,
  isNeutered: pet.isNeutered,
  avatarUrl: pet.avatarUrl ?? undefined,
  healthStatus: pet.healthStatus,
  createdAt: pet.createdAt.toISOString(),
  updatedAt: pet.updatedAt.toISOString(),
  deletedAt: pet.deletedAt?.toISOString(),
});

export class PrismaPetStore implements PetStore {
  constructor(private readonly prisma: PrismaClient) {}

  async listByUser(userId: string) {
    const pets = await this.prisma.pet.findMany({
      where: {
        userId,
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return pets.map(mapPet);
  }

  async findById(petId: string) {
    const pet = await this.prisma.pet.findUnique({
      where: { id: petId },
    });
    return pet ? mapPet(pet) : undefined;
  }

  async save(pet: PetRecord) {
    await this.prisma.pet.upsert({
      where: { id: pet.id },
      update: {
        userId: pet.userId,
        name: pet.name,
        species: pet.species as $Enums.PetSpecies,
        breed: pet.breed,
        gender: pet.gender as $Enums.PetGender,
        dob: pet.dob ? new Date(pet.dob) : null,
        weightKg: pet.weight,
        color: pet.color,
        microchipNumber: pet.microchip,
        isNeutered: pet.isNeutered,
        avatarUrl: pet.avatarUrl,
        healthStatus: pet.healthStatus as $Enums.PetHealthStatus,
        deletedAt: pet.deletedAt ? new Date(pet.deletedAt) : null,
      },
      create: {
        id: pet.id,
        userId: pet.userId,
        name: pet.name,
        species: pet.species as $Enums.PetSpecies,
        breed: pet.breed,
        gender: pet.gender as $Enums.PetGender,
        dob: pet.dob ? new Date(pet.dob) : null,
        weightKg: pet.weight,
        color: pet.color,
        microchipNumber: pet.microchip,
        isNeutered: pet.isNeutered,
        avatarUrl: pet.avatarUrl,
        healthStatus: pet.healthStatus as $Enums.PetHealthStatus,
        createdAt: new Date(pet.createdAt),
        updatedAt: new Date(pet.updatedAt),
        deletedAt: pet.deletedAt ? new Date(pet.deletedAt) : null,
      },
    });
  }

  async hasMicrochipConflict(userId: string, microchip: string, ignorePetId?: string) {
    const conflict = await this.prisma.pet.findFirst({
      where: {
        userId,
        microchipNumber: microchip,
        deletedAt: null,
        ...(ignorePetId ? { id: { not: ignorePetId } } : {}),
      },
      select: { id: true },
    });

    return Boolean(conflict);
  }
}
