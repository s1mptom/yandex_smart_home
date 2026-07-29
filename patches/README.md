# Fork patches

`.github/workflows/sync-upstream.yml` rebuilds the `dev` branch daily as
**pristine upstream tag + these patches + domain rename**. Anything not in a
patch here is lost on the next sync.

Patches are written against **upstream** paths and the **upstream** domain
(`custom_components/yandex_smart_home`, `DOMAIN = "yandex_smart_home"`) because
the workflow applies them before renaming the integration to
`yandex_smart_home_fork`.

## Changing the fork

1. Edit `custom_components/yandex_smart_home_fork/` on `dev` as usual.
2. Run `scripts/make-fork-patch.sh` — it regenerates
   `0001-configurable-cloud.patch` from the working tree (translating paths and
   the domain back to upstream form).
3. Commit both the code and the patch.

`manifest.json` and `hacs.json` are deliberately **not** patched: the workflow
rewrites the fork domain, name and HACS metadata itself, and the version stays
whatever upstream shipped (bump it by hand only for fork-only interim releases,
which use a 4th version segment: `1.1.2.1`, `1.1.2.2`, …).

## What the patch contains

Makes the cloud/relay address configurable from the Home Assistant UI instead of
hardcoding it: the address is entered when adding the integration and can be
changed later in the integration options ("Адрес облака"), and is stored in the
config entry (`cloud_base_url` / `cloud_stream_base_url`). Defaults are the
official Yaha Cloud addresses, so no private domain ever lands in this repo.

A config entry created before this change has no address stored: the integration
still loads, the cloud connection is skipped and a repair issue asks the user to
fill the address in. Entering it reloads the entry and reconnects with the
existing instance id/token — no re-linking in the Yandex app is needed.
