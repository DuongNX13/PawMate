# Protected Paths Contract for PawMate v0.31 UI

- Status: **W0/W1 protection policy**
- Policy ID: `ui-v031-day37-day38-protected-v1`
- Config: `scripts/ci/ui-v031/protected/protected-paths.json`
- Verifier: `scripts/ci/ui-v031/protected/verify-protected-paths.ps1`

## 1. Goal

The v0.31 UI lane may consume the Day 34–38 Rescue foundation, but it may not edit, rebaseline, or silently absorb backend-lane changes. The repository already has a dirty baseline, so `git diff` alone cannot distinguish:

- a pre-existing owner change,
- a new UI-lane violation,
- an untracked protected file,
- or a legitimate concurrent Day 37/38 change.

This policy therefore compares a complete, portable manifest of protected files by repo-relative path, byte length, and SHA-256.

## 2. UI-lane write allowlist for W0/W1

Only these trees are authorized by this bounded task:

- `docs/design/pawmate-v031-platform-ui/contracts/**`
- `scripts/ci/ui-v031/protected/**`

Everything else is outside this task's write scope. The verifier does not grant permission to write any path; it only proves whether protected content changed.

## 3. Protected surfaces

The machine-readable config is authoritative. It protects these categories:

- Backend source, tests, Prisma/schema/SQL/migrations, and backend scripts.
- Backend dependency/toolchain manifests.
- Canonical API and Phase 2 route/data contracts.
- Rescue/Adoption Day 5 foundation contract.
- Day 34–38 engineering and QA status/review/test-matrix documents, including files added later that match their day prefix.
- Official Phase 2 roadmap and execution ledger.
- Day 34–38 output evidence.

The policy intentionally does **not** hash the entire repository, UI-owned mobile/design paths, dependency caches, build outputs, temp folders, logs, coverage, or environment/secret files.

## 4. Baseline manifest

`Snapshot` mode is read-only. It writes the full baseline JSON to stdout; the orchestrator chooses an approved artifact destination.

```powershell
$script = '.\scripts\ci\ui-v031\protected\verify-protected-paths.ps1'
& $script -Mode Snapshot > '<approved-artifact-root>\ui-v031-protected-baseline.json'
```

Baseline fields:

- `schemaVersion`
- `kind`
- `policyId`
- `baselineId`: SHA-256 of sorted `path|sha256|length` rows
- `generatedAtUtc`
- `configSha256`
- `files[]`: repo-relative path, SHA-256, and byte length

The manifest stores no absolute machine path, token, environment value, or file content.

Baseline creation rules:

1. Create it only at an explicit W0/G5A rollback point.
2. Review current Day 37/38 ownership before accepting it.
3. Store it as a CI/release artifact or another team-approved durable location.
4. Record its `baselineId` in the wave evidence manifest.
5. Never create a new baseline merely because verification failed.

## 5. Verification

```powershell
& $script `
  -Mode Verify `
  -BaselineManifest '<artifact-root>\ui-v031-protected-baseline.json'
```

Verifier exit codes:

| Exit | Meaning |
|---:|---|
| `0` | Protected set matches, or every delta is exactly covered by a valid owner approval. |
| `2` | Integrity mismatch: unapproved added, removed, or modified protected file. |
| `3` | Invalid config/manifest, expired approval, unsafe path, symlink/reparse point, or execution error. |

`Verify` emits a compact JSON result. It does not modify the baseline, protected files, Git index, or worktree.

For a no-file smoke test, `-BaselineManifest STDIN` reads the baseline JSON from standard input. Persistent CI evidence should still use an approved manifest artifact.

## 6. Concurrent Day 37/38 work and owner delta manifest

A legitimate concurrent backend-lane change is accepted only through a signed-off owner delta manifest. Example:

```json
{
  "schemaVersion": 1,
  "kind": "pawmate-protected-path-owner-delta",
  "policyId": "ui-v031-day37-day38-protected-v1",
  "baselineId": "<baseline SHA-256>",
  "owner": "Day 38 backend owner",
  "approvedBy": "G5A approver",
  "reason": "Reconcile Rescue public contact contract",
  "approvedAtUtc": "2026-07-21T10:00:00Z",
  "expiresAtUtc": "2026-07-22T10:00:00Z",
  "changes": [
    {
      "path": "docs/architecture/pawmate_api_contract_v1.json",
      "changeType": "modified",
      "beforeSha256": "<64 hex characters>",
      "afterSha256": "<64 hex characters>"
    }
  ]
}
```

Verification command:

```powershell
& $script `
  -Mode Verify `
  -BaselineManifest '<artifact-root>\ui-v031-protected-baseline.json' `
  -OwnerDeltaManifest '<artifact-root>\approved-owner-delta.json'
```

Acceptance is exact:

- `policyId`, `baselineId`, and every required approval field must match.
- Approval must be parseable, already effective, and not expired.
- Each actual delta path appears exactly once.
- No extra approved path is allowed.
- `changeType`, before hash, and after hash must match the observed delta.
- Added files require `beforeSha256: null`; removed files require `afterSha256: null`.

An accepted owner delta is not a rebaseline. At the next explicit G5A rollback point, the owner reviews the accepted change and deliberately creates a replacement baseline.

## 7. CI/wave usage

Minimum sequence for every W1+ wave:

1. Verify the baseline before work.
2. Execute only the wave allowlist.
3. Verify again after tests and before sign-off.
4. Attach verifier JSON, baseline ID, command, exit code, commit SHA, executor, and reviewer to wave evidence.
5. Fail the wave on exit `2` or `3`; do not continue to a later wave.

If Day 37/38 is still actively changing protected files, the UI wave can continue only on unconnected design/platform-neutral work. Live Rescue wiring remains blocked until the owner delta is approved or G5A establishes a new reviewed baseline.

## 8. Security and privacy

- Snapshot records hashes and lengths only, never file content.
- Environment files and common secret-bearing/temp/cache paths are excluded.
- Do not upload local absolute paths or credentials with evidence.
- Day 34–38 Rescue screenshots and proofs may contain sensitive context; store only generated test data and run the normal redaction/secret scan before publishing.
- A config change invalidates an existing baseline through `configSha256`; it cannot silently reduce coverage.

## 9. Known limitations

- This is a file-integrity guard, not proof that backend behavior is correct.
- It does not replace Day 35/36 tests, G5A review, Git review, or API contract checks.
- Git tracked/untracked state is intentionally not part of the portable hash. Added and removed files under protected rules are still detected by set comparison.
- The verifier rejects reparse points instead of following them, preventing a protected rule from hashing outside the repository.
- The script is read-only; artifact retention and approver identity are enforced by the calling workflow/team process.
