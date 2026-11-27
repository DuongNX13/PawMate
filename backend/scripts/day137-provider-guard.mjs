// Test-only transport allowlist. No secrets, URLs with query tokens, or response bodies are logged.
import assert from 'node:assert/strict';
export function createProviderGuard({emails, buckets}) {
  assert.equal(emails.length,5); assert.equal(new Set(emails).size,5);
  const authIds=new Set(), tokens=new Set(), ticketKeys=new Map(), objects=new Map(), attemptedEmails=new Set();
  const prefixes=new Map();
  let cleanup=false;
  return {
    authIds, objects, ticketKeys, attemptedEmails,
    setCleanup(){cleanup=true;},
    ownAuth(id){assert(/^[a-f0-9-]{36}$/.test(id));assert(authIds.size<5||authIds.has(id));authIds.add(id);},
    ownToken(token){assert(typeof token==='string'&&token.length>10);tokens.add(token);},
    ticket(bucket,key){assert.equal(bucket,buckets[0]);assert(ticketKeys.size<4);assert(!ticketKeys.has(key));ticketKeys.set(key,bucket);prefixes.set(bucket+':'+key.substring(0,key.lastIndexOf('/')),true);},
    object(bucket,key){assert(buckets.slice(0,2).includes(bucket));assert(objects.size<2||objects.has(key));assert(!objects.has(key));objects.set(key,bucket);prefixes.set(bucket+':'+key.substring(0,key.lastIndexOf('/')),true);},
    check(url,method,body){
      assert.equal(url.origin,'https://qeoowayxfqyhfcgnrfnv.supabase.co','PROJECT_ALLOWLIST');
      const p=decodeURIComponent(url.pathname);
      if(p==='/auth/v1/admin/generate_link'&&method==='POST'){
        assert(!cleanup);assert.equal(body?.type,'signup');assert(emails.includes(body.email),'OWNED_EMAIL');
        assert(!attemptedEmails.has(body.email),'DUPLICATE_AUTH_CREATION');attemptedEmails.add(body.email);return 'auth_generate_owned_no_email';
      }
      if(p==='/auth/v1/verify'&&method==='POST'){
        assert(!cleanup);assert.equal(body?.type,'signup');assert(tokens.has(body.token_hash),'OWNED_TOKEN');return 'auth_verify_owned';
      }
      const id=p.match(/^\/auth\/v1\/admin\/users\/([a-f0-9-]{36})$/)?.[1];
      if(id){assert(authIds.has(id),'OWNED_AUTH_ID');assert(method==='GET'||(cleanup&&method==='DELETE'));return method==='GET'?'auth_owned_readback':'auth_owned_delete';}
      if(p==='/auth/v1/admin/users'&&method==='GET'&&cleanup){assert.equal(url.searchParams.get('per_page'),'1000');return 'auth_cleanup_discovery';}
      if(method==='GET'&&buckets.some(b=>p===`/storage/v1/bucket/${b}`))return 'bucket_read_only';
      if(method==='POST'&&buckets.some(b=>p===`/storage/v1/object/list/${b}`)){
        const bucket=p.split('/').at(-1);assert(prefixes.has(bucket+':'+body?.prefix),'OWNED_LIST_PREFIX');assert(body.limit<=10);return 'owned_objects_readback';
      }
      const signed=p.match(/^\/storage\/v1\/object\/upload\/sign\/([^/]+)\/(.+)$/);
      if(signed){const [,bucket,key]=signed;assert.equal(ticketKeys.get(key),bucket,'OWNED_SIGNED_PATH');
        if(method==='POST'){assert(!cleanup);assert.deepEqual(body,{});return 'owned_signed_ticket';}
        assert.equal(method,'PUT');assert(!cleanup);assert.equal(objects.get(key),bucket,'OWNED_UPLOAD_OBJECT');return 'owned_original_upload';
      }
      const obj=p.match(/^\/storage\/v1\/object\/(?:public\/)?([^/]+)\/(.+)$/);
      if(obj){const [,bucket,key]=obj;assert.equal(objects.get(key),bucket,'OWNED_OBJECT');
        assert(method==='GET'||(!cleanup&&method==='POST'));return method==='GET'?'owned_download':'owned_derivative_upload';
      }
      const deletion=p.match(/^\/storage\/v1\/object\/([^/]+)$/);
      if(deletion&&method==='DELETE'){
        assert(Array.isArray(body?.prefixes)&&body.prefixes.length===1);assert.equal(objects.get(body.prefixes[0]),deletion[1],'OWNED_DELETE');
        assert(cleanup||deletion[1]===buckets[0],'EARLY_PUBLIC_DELETE');return 'owned_object_delete';
      }
      throw new Error('CLOUD_OPERATION_FORBIDDEN:'+method+':'+p);
    }
  };
}
