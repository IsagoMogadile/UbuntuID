# Proposed Supabase Storage setup for document viewing — for your review

**Status: proposal only, nothing created.**

**Note on scope:** an earlier pass of this project had citizens uploading
documents from the app (`DocumentUploadScreen` +
`CitizenRepository.uploadDocument`). The project's scope correction (see
`docs/PROJECT_SCOPE.md`) removed that entirely — UbuntuID is not a
document-submission platform, and citizens only ever *view* documents
already associated with their identity. This proposal is updated
accordingly: only a SELECT/download policy is proposed for the citizen
role. `documents` rows (and their underlying files) are assumed to be
created by a simulated back-office/department process — seeding them
directly via SQL/the Supabase dashboard is enough for demo purposes; no
client-facing INSERT path is needed or proposed.

This session's Flutter code assumes a bucket named **`documents`**, private
(not public), with the path convention `<citizen_id>/<file_name>` for
whatever seeds it.

## 1. Create the bucket

In the Supabase dashboard: Storage → New bucket → name `documents` →
**Public: off**. (Or via SQL: `insert into storage.buckets (id, name, public) values ('documents', 'documents', false);`)

## 2. Storage RLS policies

Storage access is itself governed by RLS on `storage.objects`, scoped by
matching the path prefix to the caller's own `citizen_id` via the
`current_citizen_id()` helper function, which already exists live (see
`docs/KNOWN_LIMITATIONS.md`) — no dependency to apply first, it's already
there:

```sql
drop policy if exists "documents_bucket_select_own" on storage.objects;
create policy "documents_bucket_select_own" on storage.objects for select
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = current_citizen_id()::text
  );

drop policy if exists "documents_bucket_select_admin" on storage.objects;
create policy "documents_bucket_select_admin" on storage.objects for select
  using (bucket_id = 'documents' and is_admin());
```

`storage.foldername(name)` splits the object path on `/` and returns the
folder segments as an array; `[1]` is the first segment, which is the
`citizen_id` in the path convention above.

## 3. Why this wasn't just created automatically

Creating a bucket and its policies is a database/infrastructure change, and
this session's Supabase access was unavailable in any case (see
`docs/KNOWN_LIMITATIONS.md`).
