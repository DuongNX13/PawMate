import assert from 'node:assert/strict';
export type PhotoScope={origin:string;bucket:string;vetId:string;userIds:string[];runId:string;ownedKeys:Set<string>;cleanup:boolean};
export function classifyPhotoRequest(s:PhotoScope,url:string,method:string,body:unknown,headers:Headers){
  const u=new URL(url);assert.equal(u.origin,s.origin,'WRONG_PROJECT');assert.equal(u.search,'','NO_QUERY_SECRET');
  const base='/storage/v1/object/',p=decodeURIComponent(u.pathname),bucket=s.bucket;
  if(method==='POST'&&p.startsWith(base+bucket+'/')&&!s.cleanup){
    const key=p.slice((base+bucket+'/').length),parts=key.split('/');
    assert.equal(parts.length,3);assert.equal(parts[0],s.vetId);assert(s.userIds.includes(parts[1]));
    assert.match(parts[2],/^\d+-[a-f0-9-]{36}-d137-review-photo-[a-z0-9-]+\.png$/);
    assert(parts[2].endsWith(s.runId+'.png'));assert.equal(headers.get('x-upsert'),'false','NO_OVERWRITE');
    assert(!s.ownedKeys.has(key),'NO_UPLOAD_REPLAY');return{kind:'upload',key,cleanup:false};
  }
  if(method==='GET'&&p.startsWith(base+bucket+'/')&&!s.cleanup){
    const key=p.slice((base+bucket+'/').length);assert(s.ownedKeys.has(key),'UNKNOWN_DOWNLOAD');
    assert(headers.has('authorization'),'AUTHENTICATED_NATIVE_SDK_READ');return{kind:'download',key,cleanup:false};
  }
  const payload=typeof body==='string'?JSON.parse(body):body as any;
  if(s.cleanup&&method==='DELETE'&&p===base+bucket){
    assert(Array.isArray(payload.prefixes)&&payload.prefixes.length>0);
    assert.deepEqual([...payload.prefixes].sort(),[...s.ownedKeys].sort(),'EXACT_OWNED_DELETE_ONLY');
    return{kind:'delete',keys:payload.prefixes,cleanup:true};
  }
  if(s.cleanup&&method==='POST'&&p===base+'list/'+bucket){
    assert.equal(payload.prefix,s.vetId,'OWNED_VET_PREFIX');assert.equal(payload.limit,10);assert.equal(payload.offset,0);
    return{kind:'list',key:s.vetId,cleanup:true};
  }
  throw Error('PHOTO_CLOUD_ALLOWLIST');
}

export function preparePhotoDispatch(
  scope: PhotoScope, url: string, method: string, body: unknown, headers: Headers,
  expectedBytes: Buffer,
  hooks: { claim: (cleanup: boolean) => void; stop: (reason: string) => void },
) {
  try {
    const request = classifyPhotoRequest(scope, url, method, body, headers);
    if (request.kind === 'upload') {
      assert(Buffer.isBuffer(body) || body instanceof Uint8Array, 'FIXTURE_BYTES_REQUIRED');
      assert.deepEqual(Buffer.from(body as Uint8Array), expectedBytes, 'EXACT_FIXTURE_BYTES');
    }
    hooks.claim(request.cleanup);
    // A failed response can still leave a committed object: claim ownership
    // before dispatch, never only after a successful transport response.
    if (request.kind === 'upload') scope.ownedKeys.add(request.key!);
    return request;
  } catch (error) {
    if (!scope.cleanup) hooks.stop(String(error));
    throw error;
  }
}

// Both cleanup calls are independently attempted within their pre-reserved
// budget. An uncertain delete must never hide the remaining-object readback.
export async function completePhotoCleanup(
  ownedKeys: Set<string>,
  operations: {
    remove: (keys: string[]) => Promise<{ error: unknown }>;
    list: () => Promise<{ error: unknown; data: unknown[] | null }>;
  },
) {
  const errors: string[] = [];
  let remainingOwnedPrefixEntries: number | null = null;
  if (!ownedKeys.size) return { errors, remainingOwnedPrefixEntries: 0 };
  try {
    const removed = await operations.remove([...ownedKeys]);
    assert.equal(removed.error, null, 'OWNED_DELETE_FAILED');
  } catch (error) { errors.push('DELETE: ' + String(error)); }
  try {
    const listed = await operations.list();
    assert.equal(listed.error, null, 'OWNED_READBACK_FAILED');
    assert(Array.isArray(listed.data), 'OWNED_READBACK_MISSING');
    remainingOwnedPrefixEntries = listed.data.length;
    assert.equal(remainingOwnedPrefixEntries, 0, 'OWNED_OBJECTS_REMAIN');
  } catch (error) { errors.push('READBACK: ' + String(error)); }
  return { errors, remainingOwnedPrefixEntries };
}

export async function executePhotoDispatch<T>(
  scope: PhotoScope,
  operations: {
    prepare: () => void;
    transport: () => Promise<T>;
    complete: (result: T) => Promise<void>;
    failed: (error: unknown) => void;
    stop: (reason: string) => void;
  },
): Promise<T> {
  try {
    operations.prepare();
    const result = await operations.transport();
    await operations.complete(result);
    return result;
  } catch (error) {
    // Latch before writing diagnostics, which can itself fail.
    if (!scope.cleanup) operations.stop(String(error));
    operations.failed(error);
    throw error;
  }
}
