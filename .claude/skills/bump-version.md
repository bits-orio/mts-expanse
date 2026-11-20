# Bump Version

## When to use
When the user asks to bump the version, release a new version, or after the version in `info.json` has been changed.

## Steps

1. **Bump the version in `info.json`** if not already done. **Default to a patch bump** (e.g. `0.1.25` → `0.1.26`), which is how every release of this mod has been numbered. Only do a minor or major bump if the user explicitly asks for one — do not infer from the diff.

2. **Verify user-facing docs** are still accurate for the changes since the last release:
   - `README.md` — the GitHub-facing description.
   - `docs/portal.md` and `tools/portal_meta.json` — the mod-portal page. Run `python3 tools/portal_lint.py` after any edit.
   - The in-game welcome text and mission wording in `locale/en/expanse.cfg`.

   All must be **correct**: no claim that contradicts current behavior. Do not invent or expand claims to features that have not been tested. Show any doc edits to the user for approval before committing.

3. **Generate a changelog entry** at the top of `changelog.txt`:
   - Determine the previous version's git tag (format: `v<old_version>`). If no tag exists, use `git log` to find commits since the last changelog entry.
   - Collect the diff: `git log --pretty=format:"- %s" v<old_version>..HEAD`.
   - Write a new entry at the **top** of `changelog.txt` following the existing format exactly. This changelog writes its dates as `DD. MM. YYYY`:
     ```
     ---------------------------------------------------------------------------------------------------
     Version: <new_version>
     Date: <DD. MM. YYYY>
       Features:
         - ...
       Changes:
         - ...
       Bugfixes:
         - ...
       Tests:
         - ...
     ```
   - Only include sections that have entries. Reword commit messages into clear, player-facing descriptions — don't just paste raw commit subjects. Keep lines under 100 characters; continuation lines are indented six spaces.
   - Show the draft entry to the user for approval before writing it.

4. **Run the suites** the change touches (see `docs/development.md`). The window test and the save-upgrade tests need Factorio 2.1.24 or newer and a 2.0 binary in `PREVIOUS_FACTORIO`.

5. **Recreate the mod link** by running:
   ```bash
   scripts/link-mod.sh
   ```
   The link is unversioned, so this only matters when the tree's `factorio_version` changed.

6. **Commit the version bump**: stage `info.json`, `changelog.txt`, and any doc edits from step 2. Commit with message `Release <new_version>: <one-line summary>`, matching the recent history. Do NOT add a Claude co-author line.

7. **Release** (when the user asks): push the commit, then run `./tools/release.sh`. The script verifies the changelog entry, creates and pushes `v<new_version>` to `origin` (the bits-orio fork, where the release workflow and its secrets live), and GitHub Actions takes over (build zip → GitHub release → Discord → mod portal upload → portal page sync). See `docs/RELEASING.md`.
   - If the mod-portal upload step fails (portal outage, etc.), the GitHub release and tag remain. Re-run the upload via the **Upload to Mod Portal** workflow (Actions tab → workflow_dispatch). The upload script is idempotent — it noops if the version is already published.
   - Required secret on the fork: `FACTORIO_API_KEY` (scopes: ModPortal: Upload Mods and ModPortal: Edit Mods, from an account with rights on the `mts-expanse` page). Optional: `DISCORD_WEBHOOK` and `DISCORD_ANNOUNCEMENTS_WEBHOOK`.
