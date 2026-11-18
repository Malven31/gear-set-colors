# CurseForge checklist

Everything the CurseForge project and file upload ask for, ready to paste.

## Before the first upload

1. **Test in the game** after a full restart (the icon and the TOC are new), then check the BugSack for errors:
   - The addon list and the addon compartment show the new icon.
   - With at least two equipment sets saved, open the bags: each set's items have a border and a tint in the set's colour, and other items have none. Try the combined bags and the separate bag windows.
   - An item in two sets gets a border alternating the two colours.
   - `/gsc` opens the options. Each style checkbox changes the bags at once, and so do a new colour and "Mark its items".
   - The colour picker's Cancel puts the old colour back.
   - In the Character window's Equipment Manager, each set's icon has a colour square on its top-left corner. Clicking it opens the colour picker. It doesn't hide the equipped tick, nor the edit and delete buttons that show on hover.
   - Moving a set item to another bag slot moves its mark with it. Equipping a set updates the marks.
   - Saving a new set gives it the next free colour.
2. **Repository:** `github.com/Malven31/gear-set-colors`.
3. **Visibility:** the repository is public (checked 2026-11-18), so the Source and Issues links below work. Keep it public.
4. **Logo:** [logo.png](logo.png) (512×512, the addon's own). The in-game icon `GearSetColors/media/icon.tga` (64×64) is the same picture. `scripts/make-icon.ps1` draws both.
5. **Screenshots:** see [gallery/README.md](gallery/README.md).

## Moderation rules to keep in mind

From CurseForge's moderation policies (<https://support.curseforge.com/support/solutions/articles/9000197279-moderation-policies>):

- The name, logo, summary and description are the addon's own.
- Outside links, such as the GitHub repository and any donation link, go at the very bottom of the description, small.
- Keep a channel for bug reports open: the project's comments, plus GitHub Issues.
- If CurseForge asks for changes or rejects the project, fix it and reply or appeal. Never delete the project or file to upload it again.

## Create the project

| Field | Value |
|---|---|
| Game | World of Warcraft |
| Project type | Addons |
| Name | Gear Set Colors |
| Summary | Marks the items of your equipment sets in your bags with each set's colour, so you never sell them by mistake. Made for Forever. |
| Description | [description.md](description.md) |
| Category | Bags & Inventory |
| Licence | MIT License |
| Logo | [logo.png](logo.png) |
| Source | `https://github.com/Malven31/gear-set-colors` |
| Issues | `https://github.com/Malven31/gear-set-colors/issues` |

If the description editor has no Markdown mode, open `description.md` in a Markdown preview (VS Code: Ctrl+Shift+V) and copy the rendered text. The formatting comes along.

## Project ID

The project ID is **1814234** (project created 2026-11-18; the ID is in the "About Project" box of the project page).

- It is in `GearSetColors/GearSetColors.toc` as `## X-Curse-Project-ID: 1814234`. Without it, the workflow refuses tags and `scripts/release.ps1` refuses to tag.
- The top of `description.md` and `README.md` shows the download count, `https://img.shields.io/curseforge/dt/1814234?logo=curseforge&label=downloads`. Until CurseForge's public API lists the project, the badge reads "downloads: not found", and then shows the count. The fallback badge service is `https://cf.way2muchnoise.eu/full_1814234_downloads.svg`, which answers with a server error until then.
- Links to the project use `https://www.curseforge.com/projects/1814234`, which leads to the project page whatever its URL slug.

## Automatic packaging (set up once)

Files are packaged and uploaded by GitHub when a version tag is pushed: `.github/workflows/release.yml` runs the BigWigs packager, following `.pkgmeta`.

- **The zip** contains `GearSetColors` at its root, with the licence inside it. `.pkgmeta` moves the folder there and leaves out the docs, `curseforge/` and `scripts/`.
- **The project** comes from `## X-Curse-Project-ID:` in `GearSetColors/GearSetColors.toc`. A tag without it fails at the "Check the CurseForge project ID" step, because the packager would otherwise skip the upload without a word. A dry run only warns.
- **The game version** comes from `## Interface: 16001`, which the packager knows as Forever.
- **The changelog** of each file is that version's section of `CHANGELOG.md`, in Markdown. `scripts/release-notes.sh` extracts it into `RELEASE_NOTES.md` before packaging. The workflow fails if the section is missing or lists nothing.
- **The token is checked on every run**, with CurseForge itself and without uploading anything. A missing, wrong or revoked token fails the run.
- **Every push to `main` is a dry run.** It checks the token, builds the zip, checks it (`GearSetColors/` alone at the root, with its TOC, Lua files, icon and licence, and no repository files) and attaches it to the run. Nothing is uploaded: only a pushed tag uploads.
- **File name and display name:** `GearSetColors-<version>`.
- **The release type** comes from the tag: one containing `beta` or `alpha` makes a beta or alpha file, any other a release.

To set it up:

1. Create a CurseForge API token at <https://authors.curseforge.com/#/settings/api-tokens>, or reuse an existing one: a token belongs to the CurseForge account, not to a project.
2. On GitHub, open this repository's Settings > Secrets and variables > Actions > New repository secret. Name it `CF_API_TOKEN` and paste the token. Secrets are per repository: another repository's secret doesn't reach this one.
3. **Leave CurseForge's own "package on tagged commit" option off, and never add CurseForge's webhook** (Settings > Webhooks on GitHub). That packaging only runs when the webhook calls it. With both, every tag would be uploaded twice, and CurseForge's copy would have no changelog. Linking the repository as the project's source is fine.
4. **Dry run:** push to `main`, or on GitHub open Actions > Package > Run workflow. A green run means CurseForge accepts the token and the zip holds exactly what players should get. Nothing is uploaded.

## Releasing a version

1. Add a section at the top of `CHANGELOG.md`, for example `## 1.0.1 (2026-12-01)`, with `- ` entries under `### New`, `### Fixed` and `### Changed`: a player-facing summary of the new features and fixed bugs. Commit it.
2. Run `powershell -File scripts/release.ps1 -Version 1.0.1`. It checks that the working tree is clean, the TOC has the project ID and the changelog has the section, sets `## Version:` in the TOC, commits, and tags.
3. Push `main` and the tag (Sourcetree: Push with "Push all tags" ticked, or add `-Push` to the command).
4. Follow the upload in GitHub's Actions tab, then check the new file on CurseForge: game version Forever 1.60.1, release type, changelog.

**First version:** publish it as a beta, `scripts/release.ps1 -Version 1.0.0-beta1` (it uses the `## 1.0.0` changelog section). Once it is confirmed in-game, release `1.0.0`.

If an automatic upload fails, build the zip by hand with `powershell -File scripts/package.ps1` and upload `dist/GearSetColors-<version>.zip` on the project's Files page: game version Forever 1.60.1, changelog type Markdown, the text from `bash scripts/release-notes.sh <version>`.
