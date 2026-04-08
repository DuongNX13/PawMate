const path = require('path');
const dotenv = require('dotenv');
const { createClient } = require('@supabase/supabase-js');

const backendRoot = path.resolve(__dirname, '..');
const envPath = path.join(backendRoot, '.env');
const envLocalPath = path.join(backendRoot, '.env.local');

dotenv.config({ path: envPath, override: false });
dotenv.config({ path: envLocalPath, override: true });

const supabaseUrl = process.env.SUPABASE_URL?.trim();
const serviceKey = (
  process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY
)?.trim();

if (!supabaseUrl) {
  throw new Error(
    'SUPABASE_URL is required. Create backend/.env.local first or export the variable.',
  );
}

if (!serviceKey) {
  throw new Error(
    'SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY is required to bootstrap storage buckets.',
  );
}

const desiredBuckets = [
  process.env.SUPABASE_BUCKET_AVATARS?.trim() || 'avatars',
  process.env.SUPABASE_BUCKET_PET_PHOTOS?.trim() || 'pet-photos',
  process.env.SUPABASE_BUCKET_POSTS?.trim() || 'posts',
];

const supabase = createClient(supabaseUrl, serviceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

const ensureBuckets = async () => {
  const { data: existingBuckets, error: listError } =
    await supabase.storage.listBuckets();

  if (listError) {
    throw new Error(`Unable to list Supabase buckets: ${listError.message}`);
  }

  const existingNames = new Set((existingBuckets || []).map((bucket) => bucket.name));

  for (const bucketName of desiredBuckets) {
    if (existingNames.has(bucketName)) {
      console.log(`Bucket already exists: ${bucketName}`);
      continue;
    }

    const { error: createError } = await supabase.storage.createBucket(
      bucketName,
      {
        public: false,
      },
    );

    if (createError) {
      throw new Error(
        `Unable to create Supabase bucket "${bucketName}": ${createError.message}`,
      );
    }

    console.log(`Bucket created: ${bucketName}`);
  }

  console.log('Supabase storage bootstrap finished.');
};

ensureBuckets().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
