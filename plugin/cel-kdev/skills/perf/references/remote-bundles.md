# Retrieving shared capture bundles

Testers often share a capture bundle (perf.data, perf.folded,
pre-generated reports, flamegraphs) as an anonymous OneDrive
`1drv.ms` folder link. The link serves a single-page-app shell,
not the files, and the legacy `api.onedrive.com` shares API
returns 401 for personal accounts migrated to SharePoint Online
(`migratedtospo=true` appears in its redirect URL). Retrieve the
bundle through the SharePoint personal-content API instead.

## Procedure

1. Obtain an anonymous "badger" token:

   ```bash
   tok=$(curl -s -X POST https://api-badgerp.svc.ms/v1.0/token \
     -H 'Content-Type: application/json' \
     -d '{"appId":"5cbed6ac-a083-4e14-b191-b4ba07653de2"}' \
     | jq -r .token)
   ```

   The token is the `token` field of the JSON response. The
   `appId` is a fixed public constant for this anonymous flow;
   use it verbatim, do not substitute a value from the share
   link. Confirm the token is set before proceeding -- an error
   response leaves `jq` emitting `null`:

   ```bash
   [ -n "$tok" ] && [ "$tok" != null ] || echo "token request failed"
   ```

2. base64url-encode the share URL with any `?e=...` query
   stripped, then prefix `u!`:

   ```bash
   url='<1drv.ms-url>'; url=${url%%\?*}   # strip any ?e=... first
   enc="u!$(printf %s "$url" | base64 -w0 | tr '+/' '-_' | tr -d '=')"
   ```

3. List the share. BOTH headers are required:

   ```bash
   resp=$(curl -s \
     -H "Authorization: Badger ${tok}" \
     -H 'Prefer: autoredeem' \
     "https://my.microsoftpersonalcontent.com/_api/v2.0/shares/${enc}/driveitem?%24expand=children")
   ```

   The response carries the top-level `driveId` and a `children`
   array with one entry per file. Bind the drive id and each
   file's item id from this listing -- not from any nested
   `parentReference.driveId` or `remoteItem.id`:

   ```bash
   driveId=$(printf %s "$resp" | jq -r .driveId)
   # list each file's item id and name:
   printf %s "$resp" | jq -r '.children[] | "\(.id)\t\(.name)"'
   ```

4. Navigate and download strictly by item id from the listing.
   Every request needs both headers, exactly as in step 3:

   ```bash
   # list a subfolder's children
   curl -s \
     -H "Authorization: Badger ${tok}" \
     -H 'Prefer: autoredeem' \
     "https://my.microsoftpersonalcontent.com/_api/v2.0/drives/<driveId>/items/<itemId>/children"

   # download a file (-L follows the redirect to the content blob;
   # curl drops the Authorization header on the cross-host hop)
   curl -s -L -o <filename> \
     -H "Authorization: Badger ${tok}" \
     -H 'Prefer: autoredeem' \
     "https://my.microsoftpersonalcontent.com/_api/v2.0/drives/<driveId>/items/<itemId>/content"
   ```

## Pitfalls

- **`Prefer: autoredeem` is required on every request**, not
  just the first. Omitting it yields 403 even for item ids that
  worked moments earlier.
- **Badger tokens are short-lived.** If a previously working
  request starts returning 401, re-run step 1 to mint a fresh
  token; a long download can outlive the original.
- **Item-id addressing only.** Path-based addressing through the
  share (`/driveitem:/dir:/children`) fails (500/403), as does
  nested `%24expand=children(%24expand=children)` (403).
- **Encode `$` as `%24` in any OData query parameter you add**
  (`%24select`, `%24top`). The literal URLs above already do
  this; an unencoded `$` is eaten by the shell and the
  parameter is silently dropped.
- **Download selectively.** perf.folded and the pre-generated
  reports usually suffice; defer perf.data (hundreds of MB) and
  perf.script (GB) until actually needed.
- **A transient DNS failure can mimic a dead endpoint.** When a
  request to a host in this path (`api-badgerp.svc.ms`,
  `my.microsoftpersonalcontent.com`) fails to resolve, retry
  before concluding the endpoint is gone and switching
  strategies.
