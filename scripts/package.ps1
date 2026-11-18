# Builds the upload-ready zip in dist/: the GearSetColors folder at the root of the archive, with the
# licence inside it, named after the version in the TOC. Same contents as the GitHub workflow's zip.
# Entries use forward slashes, which Compress-Archive on PowerShell 5.1 does not guarantee.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $root 'dist'
$folder = 'GearSetColors'
New-Item -ItemType Directory -Force $dist | Out-Null

$toc = Join-Path $root "$folder\$folder.toc"
$line = Select-String -LiteralPath $toc -Pattern '^##\s*Version:\s*(.+?)\s*$' | Select-Object -First 1
if (-not $line) { throw "No ## Version line in $toc" }
$version = $line.Matches[0].Groups[1].Value

$zipPath = Join-Path $dist "GearSetColors-$version.zip"
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Confirm:$false }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $count = 0
    $base = Join-Path $root $folder
    foreach ($file in Get-ChildItem -LiteralPath $base -Recurse -File) {
        $entry = $folder + '/' + $file.FullName.Substring($base.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entry) | Out-Null
        $count++
    }
    # The licence goes inside the addon folder, as in the zip the GitHub workflow builds (.pkgmeta).
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root 'LICENSE'), "$folder/LICENSE") | Out-Null
    $count++
} finally {
    $zip.Dispose()
}
Write-Output "$zipPath ($count files)"
