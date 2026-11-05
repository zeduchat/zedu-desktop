# run_windows.ps1 - one-command local run of Zedu Desktop on Windows.
#
# Prepares the project and applies every workaround a Windows build needs, then runs
# `flutter run -d windows` (or a debug build). Works on a fresh machine with a fresh clone,
# an already set-up machine, a half set-up one, and one broken by an earlier failed run:
# every step detects the current state and then skips, repairs or redoes its work. It never
# fails just because something already exists. Each step prints one line:
#   [n/N] <step>: done | skipped (already OK) | repaired (<what>)
#
# Requirements: Flutter on PATH, Visual Studio with "Desktop development with C++",
# Windows Developer Mode on (Flutter needs it to create plugin symlinks).
#
# Usage (PowerShell):
#   .\run_windows.ps1                     -> flutter run -d windows
#   .\run_windows.ps1 build               -> flutter build windows --debug
#   .\run_windows.ps1 --release           -> flutter run -d windows --release
#   .\run_windows.ps1 run --release       -> same as above
#   .\run_windows.ps1 -ShortPath D:\zd    -> choose where the short junction goes
# Every argument except -ShortPath goes to flutter; a leading 'run' or 'build' only picks the mode.
# -ShortPath defaults to $env:ZEDU_SHORT_PATH, then C:\zd-<hash of this clone's path>.
# (-ShortPath is read from $args on purpose: a param() block would make PowerShell treat
#  flutter's own -d and -v as its -Debug and -Verbose, and bind 'build' to the wrong value.)
#
# If PowerShell blocks scripts, run: powershell -ExecutionPolicy Bypass -File .\run_windows.ps1
$ErrorActionPreference = 'Stop'
$totalSteps = 11

function Write-Step($n, $name, $status = 'done') {
    $color = 'Green'
    if ($status -like 'skipped*') { $color = 'DarkGray' }
    elseif ($status -like 'repaired*') { $color = 'Yellow' }
    elseif ($status -like 'failed*') { $color = 'Red' }
    Write-Host "[$n/$totalSteps] ${name}: $status" -ForegroundColor $color
}

function Resolve-RealPath([string]$Path) {
    # Follows junctions and symlinks on every path component, so a script started from inside
    # a junction still reports the clone's real location.
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $parts = $full -split '\\'
    $cur = $parts[0] + '\'
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $cur = Join-Path $cur $parts[$i]
        $item = Get-Item -LiteralPath $cur -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            $target = @($item.Target)[0]
            if ($target) {
                if (-not [System.IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path $cur) $target }
                $cur = [System.IO.Path]::GetFullPath($target).TrimEnd('\')
            }
        }
    }
    return $cur
}

$repo = Resolve-RealPath $PSScriptRoot

# -ShortPath, then $env:ZEDU_SHORT_PATH, then C:\zd-<first 6 hex chars of SHA1(real clone path)>,
# so every clone gets its own junction and several clones can coexist.
$sha1 = [System.Security.Cryptography.SHA1]::Create()
$hash = (($sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($repo.ToLowerInvariant())) | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 6)
$short = if ($env:ZEDU_SHORT_PATH) { $env:ZEDU_SHORT_PATH } else { "C:\zd-$hash" }
$passThrough = [System.Collections.Generic.List[string]]::new()
for ($i = 0; $i -lt $args.Count; $i++) {
    if ($args[$i] -eq '-ShortPath') {
        if ($i + 1 -ge $args.Count) { throw '-ShortPath needs a folder, e.g. -ShortPath D:\zd' }
        $short = $args[++$i]
    } else {
        $passThrough.Add($args[$i])
    }
}
# Only an exact 'run' or 'build' as the first argument is a mode; anything else (e.g. --release)
# is a flutter argument, so treating it as the mode would silently drop it.
if ($passThrough.Count -gt 0 -and $passThrough[0] -cin 'run', 'build') {
    $mode = $passThrough[0]
    $rest = if ($passThrough.Count -gt 1) { $passThrough.GetRange(1, $passThrough.Count - 1).ToArray() } else { @() }
} else {
    $mode = 'run'
    $rest = $passThrough.ToArray()
}
$flutterArgs = if ($mode -eq 'build') { @('build', 'windows', '--debug') + $rest } else { @('run', '-d', 'windows') + $rest }

# 1. Preflight. Fail fast, with the exact fix, on problems that would otherwise surface as
#    confusing errors many minutes into a build.
if ($env:OS -ne 'Windows_NT') {
    throw 'run_windows.ps1 only supports Windows. On macOS or Linux use: flutter run -d macos (or linux).'
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'flutter was not found on PATH. Install Flutter, reopen PowerShell, and check it with: flutter doctor'
}
$devMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devMode -ne 1) {
    throw 'Windows Developer Mode is off. Flutter needs it to create plugin symlinks. Turn it on with: start ms-settings:developers  (then switch on Developer Mode) and run this script again.'
}
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = if (Test-Path $vswhere) { & $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath } else { $null }
if (-not $vsPath) {
    throw 'Visual Studio with the "Desktop development with C++" workload was not found. Open the Visual Studio Installer, choose Modify, tick "Desktop development with C++", install it, and run this script again.'
}
if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning 'Running as administrator. Flutter should not be run elevated; open a normal PowerShell window instead.'
}
# A running app locks its exe, and the link step then fails with LNK1168.
$running = Get-Process zedu -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -and $_.Path -like '*\build\windows\x64\runner\*\zedu.exe' -and ($_.Path.StartsWith($repo, 'OrdinalIgnoreCase') -or $_.Path.StartsWith($short, 'OrdinalIgnoreCase'))
}
if ($running) {
    throw "Close the running Zedu app first (zedu.exe, PID $(@($running)[0].Id)), then run this script again."
}
Write-Step 1 'Preflight'

# 2. Build through a short junction. A deep clone path pushes Agora's SDK headers past the
#    260-char MAX_PATH limit that MSVC enforces ("Cannot open include file: AgoraMediaBase.h").
#    A junction that already points at this clone is reused. One that points elsewhere, or whose
#    target is gone, is replaced (rmdir removes only the link, never the target). A real folder
#    is never touched.
$link = Get-Item -LiteralPath $short -Force -ErrorAction SilentlyContinue
$junctionStatus = 'done'
if ($link) {
    if (-not ($link.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw "$short already exists and is a real folder, not a junction. Move or delete it yourself, or choose another path with -ShortPath."
    }
    $target = @($link.Target)[0]
    if ($target -and (Test-Path -LiteralPath $target) -and ($target.TrimEnd('\') -ieq $repo.TrimEnd('\'))) {
        $junctionStatus = 'skipped (already OK)'
    } else {
        $was = if ($target) { $target } else { 'nowhere' }
        cmd /c rmdir "$short"
        if ($LASTEXITCODE -ne 0) { throw "Could not remove the old junction $short. Remove it yourself with: cmd /c rmdir $short" }
        $link = $null
        $junctionStatus = "repaired (replaced junction that pointed to $was)"
    }
}
if (-not $link) {
    try {
        New-Item -ItemType Junction -Path $short -Target $repo -ErrorAction Stop | Out-Null
    } catch {
        throw "Could not create the junction $short ($($_.Exception.Message)). A folder directly under C:\ may need admin rights; use one you can write to, e.g. -ShortPath D:\zd"
    }
}
Write-Step 2 'Short-path junction' $junctionStatus

# Push-Location (not Set-Location) so the finally block can put your terminal back where it was.
Push-Location $short
try {
    # 3. .env is a pubspec asset, so the build fails without it. Never overwrite an existing one.
    if (Test-Path .env) {
        Write-Step 3 '.env' 'skipped (already OK)'
    } else {
        if (-not (Test-Path .env.example)) { throw '.env.example is missing, so .env cannot be created. Restore it with: git restore .env.example' }
        Copy-Item .env.example .env
        $apiUrl = (Select-String -Path .env -Pattern '^\s*API_BASE_URL\s*=\s*(.*)$' | Select-Object -First 1).Matches.Groups[1].Value
        Write-Host ".env was created from .env.example and holds example values (API_BASE_URL=$apiUrl). Edit .env and set real values, especially the backend URL." -ForegroundColor Yellow
        Write-Step 3 '.env' 'repaired (created from .env.example)'
    }

    # 4. Flutter's Windows engine files and cpp_client_wrapper. Flutter can leave
    #    windows\flutter\ephemeral\cpp_client_wrapper empty ("Cannot open source file ...
    #    core_implementations.cc"), and its build cache does not always unpack it again, so refill
    #    it from the engine cache. The flutter root is found without assuming flutter.bat sits in
    #    <root>\bin, so shims (fvm, puro, scoop) work too.
    $wrapper = 'windows\flutter\ephemeral\cpp_client_wrapper'

    function Get-FlutterRoot {
        $candidates = @()
        if ($env:FLUTTER_ROOT) { $candidates += $env:FLUTTER_ROOT }
        $candidates += Split-Path (Split-Path (Get-Command flutter).Source)
        foreach ($c in $candidates) {
            if (Test-Path (Join-Path $c 'bin\flutter.bat')) { return $c }
        }
        try {
            $out = flutter --version --machine 2>$null | Out-String
            $brace = $out.IndexOf('{')
            if ($brace -ge 0) { return (ConvertFrom-Json $out.Substring($brace)).flutterRoot }
        } catch { }
        return $null
    }

    function Get-EngineWrapperPath {
        $root = Get-FlutterRoot
        if (-not $root) { return $null }
        return Join-Path $root 'bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper'
    }

    function Restore-CppClientWrapper {
        # Returns $true when the sources were missing and have been copied back.
        if (Get-ChildItem $wrapper -Recurse -Filter *.cc -ErrorAction SilentlyContinue) { return $false }
        $engineWrapper = Get-EngineWrapperPath
        if (-not $engineWrapper -or -not (Test-Path $engineWrapper)) { return $false }
        New-Item -ItemType Directory -Force $wrapper | Out-Null
        Copy-Item "$engineWrapper\*" $wrapper -Recurse -Force
        return $true
    }

    $repairs = @()
    $engineWrapper = Get-EngineWrapperPath
    if (-not $engineWrapper -or -not (Test-Path $engineWrapper)) {
        flutter precache --windows
        if ($LASTEXITCODE -ne 0) { throw 'flutter precache --windows failed. Check your network, then run this script again.' }
        $engineWrapper = Get-EngineWrapperPath
        if (-not $engineWrapper -or -not (Test-Path $engineWrapper)) {
            throw "Flutter's Windows engine files were not found even after: flutter precache --windows. Set FLUTTER_ROOT to your Flutter folder and run again."
        }
        $repairs += 'ran flutter precache --windows'
    }
    if (Restore-CppClientWrapper) { $repairs += 'refilled cpp_client_wrapper from the engine cache' }
    if ($repairs.Count -gt 0) { Write-Step 4 'Flutter engine files' "repaired ($($repairs -join '; '))" } else { Write-Step 4 'Flutter engine files' 'skipped (already OK)' }

    # 5. Packages. This also creates the plugin links the later steps read from.
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed (exit code $LASTEXITCODE). Check your network and pubspec.yaml, then run this script again." }
    Write-Step 5 'flutter pub get'

    # 6. Agora SDK. Without the SDKs in the plugin's lib folders and an empty .plugin_dev file,
    #    the plugin extracts its SDK zips through a symlink on every build, and CMake fails with
    #    "Cannot extract through symlink". The plugin version comes from pubspec.lock because the
    #    Pub cache folder is named after it, so a version bump gets a fresh fix automatically.
    #    An SDK folder put there by hand (the old manual guide) passes validation and is kept.
    $lock = Get-Content pubspec.lock -Raw
    if ($lock -notmatch '(?m)^  agora_rtc_engine:\r?\n(?:    .*\r?\n)*?    version: "([^"]+)"') {
        throw 'agora_rtc_engine was not found in pubspec.lock. Run flutter pub get and check pubspec.yaml.'
    }
    $agoraVersion = $Matches[1]
    $pubCache = if ($env:PUB_CACHE) { $env:PUB_CACHE } else { Join-Path $env:LOCALAPPDATA 'Pub\Cache' }
    $plugin = Join-Path $pubCache "hosted\pub.dev\agora_rtc_engine-$agoraVersion\windows"
    if (-not (Test-Path $plugin)) {
        throw "agora_rtc_engine $agoraVersion was not found at '$plugin'. Run flutter pub get and check that PUB_CACHE is right."
    }
    $irisDir = Join-Path $plugin 'third_party\iris'
    $nativeDir = Join-Path $plugin 'third_party\native'
    $devFile = Join-Path $plugin '.plugin_dev'

    function Test-IrisLib([string]$lib) {
        if (-not (Test-Path $lib)) { return $false }
        $include = Get-ChildItem $lib -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like '*\x64\include' } | Select-Object -First 1
        $dll = Get-ChildItem $lib -Recurse -File -Filter AgoraRtcWrapper.dll -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like '*\x64\Release\*' } | Select-Object -First 1
        return [bool]($include -and $dll)
    }

    function Test-NativeLib([string]$lib) {
        if (-not (Test-Path $lib)) { return $false }
        foreach ($sdk in (Get-ChildItem $lib -Recurse -Directory -Filter sdk -ErrorAction SilentlyContinue)) {
            if ((Test-Path (Join-Path $sdk.FullName 'high_level_api\include')) -and (Get-ChildItem (Join-Path $sdk.FullName 'x86_64') -Filter *.dll -ErrorAction SilentlyContinue)) { return $true }
        }
        return $false
    }

    function Get-AgoraZip([string]$url, [string]$zip) {
        # Download to a .part file so a failed or partial download never looks like a finished zip.
        # The native SDK is large, so this can take a while on a slow connection.
        $part = "$zip.part"
        if (Test-Path $part) { [System.IO.File]::Delete($part) }
        $escaped = $url.Replace('+', '%2B')
        $ok = $false
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & curl.exe -L --fail --retry 3 --silent --show-error -o $part $escaped
        if ($LASTEXITCODE -eq 0 -and (Test-Path $part)) { $ok = $true }
        $ErrorActionPreference = $old
        if (-not $ok) {
            try {
                $oldProgress = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
                Invoke-WebRequest -Uri $escaped -OutFile $part -UseBasicParsing
                $ok = Test-Path $part
            } catch {
                $ok = $false
            } finally {
                $ProgressPreference = $oldProgress
            }
        }
        if (-not $ok) {
            if (Test-Path $part) { [System.IO.File]::Delete($part) }
            throw "Could not download $url. Check your network (download.agora.io must be reachable) and run this script again."
        }
        Move-Item -LiteralPath $part -Destination $zip -Force
    }

    function Expand-AgoraZip([string]$zip, [string]$dest) {
        # Returns $true when the archive extracted. tar.exe first, Expand-Archive as a fallback.
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & tar.exe -xf $zip -C $dest 2>&1 | Out-Null
        $ok = ($LASTEXITCODE -eq 0)
        $ErrorActionPreference = $old
        if (-not $ok) {
            try {
                Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
                $ok = $true
            } catch {
                $ok = $false
            }
        }
        return $ok
    }

    function Install-AgoraSdk([string]$name, [string]$url, [string]$dir, [scriptblock]$validate) {
        # Redo one SDK from scratch: clear its lib folder, make sure the zip is there, extract,
        # validate. A zip that fails to extract or validate is treated as corrupt, deleted and
        # downloaded again, once.
        $zip = Join-Path $dir ([System.IO.Path]::GetFileName(([uri]$url).AbsolutePath))
        $lib = Join-Path $dir 'lib'
        for ($attempt = 1; $attempt -le 2; $attempt++) {
            if (-not (Test-Path $zip)) { Get-AgoraZip $url $zip }
            if (Test-Path $lib) { [System.IO.Directory]::Delete($lib, $true) }
            New-Item -ItemType Directory -Force $lib | Out-Null
            if ((Expand-AgoraZip $zip $lib) -and (& $validate $lib)) { return }
            [System.IO.File]::Delete($zip)
        }
        throw "The Agora $name SDK still looks wrong after downloading it twice (expected content missing in '$lib'). Check your network and disk space, then run this script again."
    }

    $irisOk = Test-IrisLib (Join-Path $irisDir 'lib')
    $nativeOk = Test-NativeLib (Join-Path $nativeDir 'lib')
    $pluginDevCreated = $false
    if ($irisOk -and $nativeOk) {
        if (Test-Path $devFile) {
            Write-Step 6 'Agora SDK' 'skipped (already OK)'
        } else {
            New-Item -ItemType File $devFile -Force | Out-Null
            $pluginDevCreated = $true
            Write-Step 6 'Agora SDK' 'repaired (SDKs were fine, created the missing .plugin_dev)'
        }
    } else {
        if (Test-Path $devFile) { [System.IO.File]::Delete($devFile) }
        $cmake = Join-Path $plugin 'cmake\DownloadSDK.cmake'
        if (-not (Test-Path $cmake)) { throw "'$cmake' was not found, so the Agora SDK download URLs are unknown." }
        $cmakeText = Get-Content $cmake -Raw
        $redone = @()
        foreach ($sdk in @(
            @{ Name = 'iris'; Var = 'IRIS_SDK_DOWNLOAD_URL'; Dir = $irisDir; Ok = $irisOk; Test = ${function:Test-IrisLib} },
            @{ Name = 'native'; Var = 'NATIVE_SDK_DOWNLOAD_URL'; Dir = $nativeDir; Ok = $nativeOk; Test = ${function:Test-NativeLib} }
        )) {
            if ($sdk.Ok) { continue }
            if ($cmakeText -notmatch "set\($($sdk.Var)\s+`"([^`"]+)`"\)") { throw "$($sdk.Var) was not found in '$cmake'." }
            Write-Host "Agora $($sdk.Name) SDK is missing or incomplete; downloading and extracting it (the native SDK is large, this can take a while)..." -ForegroundColor Yellow
            Install-AgoraSdk $sdk.Name $Matches[1] $sdk.Dir $sdk.Test
            $redone += $sdk.Name
        }
        New-Item -ItemType File $devFile -Force | Out-Null
        $pluginDevCreated = $true
        Write-Step 6 'Agora SDK' "repaired (redid the $($redone -join ' and ') SDK, created .plugin_dev)"
    }

    # 7. Newer MSVC toolsets (VS 2022 17.x+/2026) reject <experimental/coroutine>, which
    #    audioplayers_windows still includes (error STL1011). Append to CL instead of overwriting
    #    it, and never add the flag twice, even across several runs in one PowerShell window.
    $coroutineFlag = '/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS'
    if ($env:CL -like "*$coroutineFlag*") {
        Write-Step 7 'MSVC coroutine flag' 'skipped (already OK)'
    } else {
        $env:CL = "$env:CL $coroutineFlag".Trim()
        Write-Step 7 'MSVC coroutine flag'
    }

    # 8. A stale CMakeCache.txt makes CMake fail in confusing ways, so delete just that file (never
    #    the whole build folder) when it cannot be trusted: its install prefix is under Program
    #    Files (needs admin), it was configured from another directory (CMake refuses to reuse it),
    #    the last configure failed, or Agora was just fixed and a stale failed Agora build exists.
    $cache = 'build\windows\x64\CMakeCache.txt'
    if (-not (Test-Path $cache)) {
        Write-Step 8 'CMake cache' 'skipped (no cache yet)'
    } else {
        $why = @()
        $programFiles = $env:ProgramFiles -replace '\\', '/'
        $shortPrefix = ($short.TrimEnd('\') -replace '\\', '/') + '/'
        if (-not (Select-String -Path $cache -Pattern 'CMAKE_INSTALL_PREFIX:PATH=' -SimpleMatch -Quiet)) {
            $why += 'no install prefix, so the last configure failed'
        } elseif (Select-String -Path $cache -Pattern "CMAKE_INSTALL_PREFIX:PATH=$programFiles" -SimpleMatch -Quiet) {
            $why += 'install prefix under Program Files'
        }
        $dirLine = Select-String -Path $cache -Pattern 'CMAKE_CACHEFILE_DIR:INTERNAL=' -SimpleMatch | Select-Object -First 1
        if ($dirLine -and -not (Select-String -InputObject $dirLine.Line -Pattern "CMAKE_CACHEFILE_DIR:INTERNAL=$shortPrefix" -SimpleMatch -Quiet)) {
            $why += 'configured from another directory'
        }
        $errorLog = 'build\windows\x64\CMakeFiles\CMakeError.log'
        if ((Test-Path $errorLog) -and ((Get-Item $errorLog).LastWriteTime -gt (Get-Item $cache).LastWriteTime)) {
            $why += 'the last configure failed'
        }
        if ($pluginDevCreated -and (Test-Path 'build\windows\x64\plugins\agora_rtc_engine')) {
            $why += 'stale Agora build from before the SDK fix'
        }
        if ($why.Count -gt 0) {
            Remove-Item $cache -Force
            Write-Step 8 'CMake cache' "repaired (deleted CMakeCache.txt: $($why -join '; '))"
        } else {
            Write-Step 8 'CMake cache' 'skipped (already OK)'
        }
    }

    # 9. audioplayers_windows downloads the Windows Implementation Library (WIL) NuGet package
    #    at configure time, which fails when api.nuget.org is unreachable (flaky DNS or a
    #    restricted network). If the package is in your global NuGet cache, seed it into the build
    #    folder so no download is needed. The version is read from the plugin's own CMakeLists.txt
    #    so it follows audioplayers upgrades; if that cannot be read, fall back to the version
    #    audioplayers_windows 4.3.0 asks for (1.0.210803.1).
    $wil = '1.0.210803.1'
    $audioCmake = 'windows\flutter\ephemeral\.plugin_symlinks\audioplayers_windows\windows\CMakeLists.txt'
    $wilMatch = if (Test-Path $audioCmake) { Select-String -Path $audioCmake -Pattern 'set\(WIL_VERSION "([^"]+)"\)' | Select-Object -First 1 }
    if ($wilMatch) { $wil = $wilMatch.Matches[0].Groups[1].Value }
    $nugetRoot = if ($env:NUGET_PACKAGES) { $env:NUGET_PACKAGES } else { Join-Path $env:USERPROFILE '.nuget\packages' }
    $nugetCache = Join-Path $nugetRoot "microsoft.windows.implementationlibrary\$wil"
    $pkg = 'build\windows\x64\packages\Microsoft.Windows.ImplementationLibrary'
    if (Test-Path $pkg) {
        Write-Step 9 'NuGet package' 'skipped (already in the build folder)'
    } elseif (Test-Path $nugetCache) {
        New-Item -ItemType Directory -Force $pkg | Out-Null
        Copy-Item "$nugetCache\*" $pkg -Recurse -Force
        Copy-Item "$nugetCache\microsoft.windows.implementationlibrary.$wil.nupkg" "$pkg\Microsoft.Windows.ImplementationLibrary.$wil.nupkg" -Force
        Copy-Item "$nugetCache\microsoft.windows.implementationlibrary.nuspec" "$pkg\Microsoft.Windows.ImplementationLibrary.nuspec" -Force
        Write-Step 9 'NuGet package' "repaired (seeded WIL $wil from your NuGet cache)"
    } else {
        Write-Step 9 'NuGet package' 'skipped (not in your NuGet cache; the build will download it)'
    }

    # 10. Run or build. The first build after a build from a long path can fail because Flutter
    #     itself empties cpp_client_wrapper during that run. If that is why it failed, refill it
    #     and retry once. A failure with the sources intact (a real compile error) is not retried.
    Write-Host "[10/$totalSteps] $(if ($mode -eq 'build') { 'Build' } else { 'Run' }): flutter $($flutterArgs -join ' ')"
    flutter @flutterArgs
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and (Restore-CppClientWrapper)) {
        Write-Step 10 'Retry' 'repaired (Flutter emptied cpp_client_wrapper during the build; refilled it and retrying once)'
        flutter @flutterArgs
        $exitCode = $LASTEXITCODE
    }
    Write-Step 10 $(if ($mode -eq 'build') { 'Build' } else { 'Run' }) $(if ($exitCode -eq 0) { 'done' } else { "failed (exit code $exitCode)" })

    # 11. Running Flutter regenerates the plugin registrant files, and with Windows line endings
    #     Git then lists them as modified. Tell the user instead of restoring them behind their back.
    $changed = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        try { $changed = git -C $repo status --porcelain -- linux macos windows/flutter 2>$null } catch { }
    }
    if ($changed) {
        Write-Host 'Generated files changed. Run `git restore linux macos windows/flutter` before committing.' -ForegroundColor Yellow
    }
    Write-Step 11 'Generated files check' $(if ($changed) { 'done (changed, see above)' } else { 'skipped (no changes)' })
} finally {
    Pop-Location
}
# Exit after the finally block, with flutter's code saved above, so the caller still sees it.
exit $exitCode
