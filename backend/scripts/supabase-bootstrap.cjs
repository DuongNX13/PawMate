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

let parsedSupabaseUrl;
try {
  parsedSupabaseUrl = new URL(supabaseUrl);
} catch {
  throw new Error(
    'SUPABASE_URL must be a valid absolute URL in the form https://<project-ref>.supabase.co.',
  );
}

if (
  parsedSupabaseUrl.hostname === 'supabase.com' ||
  parsedSupabaseUrl.pathname.startsWith('/dashboard/')
) {
  throw new Error(
    'SUPABASE_URL must use the project API host in the form https://<project-ref>.supabase.co, not a dashboard URL.',
  );
}

if (!serviceKey) {
  throw new Error(
    'SUPABASE_SECRET_KEY or SUPABASE_SERVICE_ROLE_KEY is required to bootstrap storage buckets.',
  );
}

const desiredBuckets = [
  {
    name: process.env.SUPABASE_BUCKET_AVATARS?.trim() || 'avatars',
    public: false,
  },
  {
    name: process.env.SUPABASE_BUCKET_PET_PHOTOS?.trim() || 'pet-photos',
    public: false,
  },
  {
    name: process.env.SUPABASE_BUCKET_POSTS?.trim() || 'posts',
    public: false,
  },
  {
    name: process.env.SUPABASE_BUCKET_REVIEW_PHOTOS?.trim() || 'review-photos',
    public: true,
  },
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

  const existingBucketsByName = new Map(
    (existingBuckets || []).map((bucket) => [bucket.name, bucket]),
  );

  for (const bucket of desiredBuckets) {
    const existingBucket = existingBucketsByName.get(bucket.name);
    if (existingBucket) {
      if (existingBucket.public !== bucket.public) {
        const { error: updateError } = await supabase.storage.updateBucket(
          bucket.name,
          {
            public: bucket.public,
          },
        );

        if (updateError) {
          throw new Error(
            `Unable to update Supabase bucket "${bucket.name}": ${updateError.message}`,
          );
        }

        console.log(`Bucket updated: ${bucket.name}`);
        continue;
      }

      console.log(`Bucket already exists: ${bucket.name}`);
      continue;
    }

    const { error: createError } = await supabase.storage.createBucket(
      bucket.name,
      {
        public: bucket.public,
      },
    );

    if (createError) {
      throw new Error(
        `Unable to create Supabase bucket "${bucket.name}": ${createError.message}`,
      );
    }

    console.log(`Bucket created: ${bucket.name}`);
  }

  console.log('Supabase storage bootstrap finished.');
};

ensureBuckets().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
