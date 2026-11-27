import { AppError } from '../src/errors/app-error';
import { createAdoptionService } from '../src/services/adoption/adoption-service';
import {
  ADOPTER_USER_ID,
  buildAdoptionRepositoryMock,
} from './helpers/adoption-fixtures';

describe('Day 108 Adoption age filter contract', () => {
  it('normalizes species age and distance into one repository query', async () => {
    const harness = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository: harness.repository });

    await service.listListings(ADOPTER_USER_ID, {
      species: 'cat',
      ageGroup: 'one_to_three',
      lat: '10.7769',
      lng: '106.7009',
      distanceKm: '10',
      sort: 'distance',
    });

    expect(harness.listListings).toHaveBeenCalledWith(
      expect.objectContaining({
        species: 'cat',
        ageGroup: 'one_to_three',
        latitude: 10.7769,
        longitude: 106.7009,
        distanceKm: 10,
        sort: 'distance',
      }),
    );
  });

  it('rejects unsupported age groups before repository access', async () => {
    const harness = buildAdoptionRepositoryMock();
    const service = createAdoptionService({ repository: harness.repository });

    await expect(
      service.listListings(ADOPTER_USER_ID, { ageGroup: 'unknown' }),
    ).rejects.toBeInstanceOf(AppError);
    expect(harness.listListings).not.toHaveBeenCalled();
  });
});
