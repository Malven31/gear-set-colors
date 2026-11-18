# Prepares a release: sets the version in the TOC file, commits that change, and creates the tag.
# Pushing the tag makes GitHub package the addon and upload it to CurseForge
# (.github/workflows/release.yml).
#
#   powershell -File scripts/release.ps1 -Version 1.0.1         # prepare, then push from Sourcetree
#   powershell -File scripts/release.ps1 -Version 1.0.1 -Push   # prepare and push
#
# A version containing "beta" or "alpha" (for example 1.1.0-beta1) is uploaded as a beta or alpha file,
# any other version as a release. CHANGELOG.md needs a section for the version first, "## 1.0.1 (date)":
# it becomes the changelog of the CurseForge file. A beta may use the section of its final version
# (1.1.0-beta1 can use "## 1.1.0"). The TOC needs its "## X-Curse-Project-ID:" line, or the upload fails.
param(
    [Parameter(Mandatory)][string]$Version,
    [switch]$Push
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tocs = @('GearSetColors\GearSetColors.toc')

function Invoke-Git {
    $output = & git -C $root @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit code $LASTEXITCODE)" }
    $output
}

if ($Version -notmatch '^\d+\.\d+\.\d+(-(alpha|beta)\d*)?$') {
    throw "The version must look like 1.2.3, 1.2.3-beta1 or 1.2.3-alpha1, not '$Version'."
}
$baseVersion = $Version -replace '-.*$', ''

$branch = Invoke-Git rev-parse --abbrev-ref HEAD
if ($branch -ne 'main') { throw "Releases are made from main. The current branch is $branch." }
if (Invoke-Git status --porcelain) { throw 'The working tree has uncommitted changes. Commit or discard them first.' }
if (Invoke-Git tag --list $Version) { throw "The tag $Version already exists." }

# Without a project ID the packager skips the upload, and the workflow refuses the tag.
$mainToc = [System.IO.File]::ReadAllText((Join-Path $root $tocs[0]))
if ($mainToc -notmatch '(?m)^## X-Curse-Project-ID:[ \t]*\d+') {
    throw "$($tocs[0]) has no '## X-Curse-Project-ID: <id>' line. Add the CurseForge project's ID first."
}

# The section is what players read on CurseForge (website and app): it must exist and list something.
# Same rule as scripts/release-notes.sh, which the GitHub workflow runs: the version's own section,
# otherwise for a beta or alpha the section of its final version.
$changelog = [System.IO.File]::ReadAllText((Join-Path $root 'CHANGELOG.md')) -replace "`r", ''
function Get-ChangelogSection([string]$v) {
    $m = [regex]::Match($changelog, "(?ms)^## $([regex]::Escape($v))(?:[ \t][^\n]*)?\n(.*?)(?=^## |\z)")
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}
$section = Get-ChangelogSection $Version
if ($null -eq $section -and $baseVersion -ne $Version) { $section = Get-ChangelogSection $baseVersion }
if ($null -eq $section) {
    throw "CHANGELOG.md has no '## $Version' section. Add one first, listing what is new, fixed or changed: it becomes the changelog of the CurseForge file."
}
if ($section -notmatch '(?m)^- \S') {
    throw "The CHANGELOG.md section for $Version lists nothing. Add '- ' entries under ### New, ### Fixed or ### Changed: players read them on CurseForge."
}

# Rewrite only the "## Version:" line, keeping the file's encoding (UTF-8 without BOM) and line endings.
$utf8 = New-Object System.Text.UTF8Encoding $false
foreach ($toc in $tocs) {
    $path = Join-Path $root $toc
    $text = [System.IO.File]::ReadAllText($path)
    if ($text -notmatch '(?m)^## Version:') { throw "No '## Version:' line in $toc." }
    $text = [regex]::Replace($text, '(?m)^(## Version:[ \t]*)[^\r\n]*', "`${1}$Version")
    [System.IO.File]::WriteAllText($path, $text, $utf8)
}

Invoke-Git add -- ($tocs | ForEach-Object { $_.Replace('\', '/') }) | Out-Null
if (Invoke-Git status --porcelain) {
    Invoke-Git commit -q -m "Release $Version" | Out-Null
}
Invoke-Git tag -a $Version -m "Gear Set Colors $Version" | Out-Null
Write-Output "Tagged $Version on $(Invoke-Git rev-parse --short HEAD)."

if ($Push) {
    Invoke-Git push origin main | Out-Null
    Invoke-Git push origin $Version | Out-Null
    Write-Output "Pushed. GitHub is now packaging $($Version): follow it in the repository's Actions tab."
} else {
    Write-Output "Ready. Push the main branch and the tag to publish it (Sourcetree: Push, with 'Push all tags' ticked)."
}
