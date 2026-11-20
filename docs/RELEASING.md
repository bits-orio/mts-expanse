# Releasing MTS Expanse

Releases are cut from the bits-orio fork with the same tooling as the other
mods of the MTS family. Pushing a tag `v<version>` to the fork starts
`.github/workflows/release.yml`, which builds the zip, creates the GitHub
release, posts to Discord, uploads the version to the mod portal and deploys the
portal page from this repository.

## Once per repository

The mod's portal page belongs to zzh8829, so the API key must come from an
account that has rights on `mts-expanse` there. Set the secrets on the fork:

```bash
gh secret set FACTORIO_API_KEY -R bits-orio/mts-expanse < ~/.config/factorio/api-key
gh secret set DISCORD_WEBHOOK -R bits-orio/mts-expanse
gh secret set DISCORD_ANNOUNCEMENTS_WEBHOOK -R bits-orio/mts-expanse
```

`FACTORIO_API_KEY` needs the scopes "ModPortal: Upload Mods" and "ModPortal:
Edit Mods". Without the key the workflow still builds the zip and the GitHub
release and skips the portal steps. The two webhooks are optional.

## Every release

1. Bump `info.json` and add the `changelog.txt` entry (the bump-version skill in
   `.claude/skills/` walks through it). Commit and push.
2. Run `./tools/release.sh`. It checks that the tree is clean and pushed and that
   the changelog has an entry for the version, then creates and pushes the tag.
3. Watch the run under Actions on the fork. If only the portal upload failed,
   run the "Upload to Mod Portal" workflow; it is safe to repeat.

`tools/pack.sh` builds the same zip by hand for a playtest.

## The portal page

`docs/portal.md` is the page description and `tools/portal_meta.json` holds the
title, summary, category, tags, license and links. Every release deploys both,
and "Sync Portal Details" under Actions does it on demand.

```bash
python3 tools/portal_lint.py              # house rules, before committing an edit
tools/sync_portal_details.sh --check      # what differs from the live page
tools/sync_portal_details.sh --dry-run    # what a sync would send
```

The gallery images and the thumbnail are set by hand on the site.

## The two game versions

0.1.24 is the last version for Factorio 2.0 and 0.1.25 the first for 2.1. A
release is built from the tagged commit, so the release tooling has to be part of
that commit: to cut a 2.0 fix release, branch from the 0.1.24 commit, bring
`tools/` and `.github/` over, and tag there.
