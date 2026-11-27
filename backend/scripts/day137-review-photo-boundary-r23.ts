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
