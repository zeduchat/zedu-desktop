# Running Zedu Desktop on Windows(locally)

Run the app on Windows with one command, [`run_windows.ps1`](run_windows.ps1). It works on a fresh machine with a fresh clone, on a machine that is already set up, on a half set-up machine, and on one broken by an earlier failed run. Every step looks at the current state first and then skips, repairs or redoes its work, so you can run it as often as you like. It was written with Flutter 3.47.7 and Visual Studio 2026 Community with the **Desktop development with C++** workload.

Before you start:

- Run every command in **PowerShell**.
- Do not run Flutter as administrator. The script warns you if you do.
- Never commit or share your `.env` file or paste its contents anywhere.

Back to the [main README](README.md).

## Requirements

| Requirement | How to check | Notes |
| --- | --- | --- |
| Flutter on `PATH` | `flutter doctor` | Flutter and Visual Studio with the C++ desktop tools must be green. The Android SDK warning can be ignored for a Windows build. |
| Visual Studio with **Desktop development with C++** | `flutter doctor` | Visual Studio 2022 17.x or 2026. To add the workload, open the Visual Studio Installer and choose **Modify**. |
| Windows **Developer Mode** on | `start ms-settings:developers` | Flutter needs it to create plugin symlinks. The script checks it and stops if it is off. It never changes it for you. |
| Internet access | | The first run downloads packages and the Agora SDKs. |

## Run the app

Clone the repository anywhere you like. A short path is not required any more, because the script builds through a short junction. Then, from the repository folder:

```powershell
.\run_windows.ps1
```

If PowerShell blocks scripts (`running scripts is disabled on this system`), run it like this instead. It changes no machine or user setting:

```powershell
powershell -ExecutionPolicy Bypass -File .\run_windows.ps1
```

Other ways to call it:

```powershell
.\run_windows.ps1 build              # debug build only (flutter build windows --debug)
.\run_windows.ps1 --release          # run in release mode (flutter run -d windows --release)
.\run_windows.ps1 -ShortPath D:\zd   # choose where the short junction goes
```

Every argument except `-ShortPath` goes to Flutter. A leading `run` or `build` only picks the mode. The script exits with Flutter's exit code.

The **first run takes a while**: it downloads the large Agora SDKs (the native SDK is over 100 MB) and then builds the whole app. A successful build ends with `Built build\windows\x64\runner\Debug\zedu.exe`, and the app window opens. Later runs are much faster.

Each step prints one line, so you can see what it did:

```txt
[2/11] Short-path junction: skipped (already OK)
[6/11] Agora SDK: repaired (redid the iris and native SDK, created .plugin_dev)
```

The status is `done`, `skipped (already OK)` or `repaired (<what>)`.

**The short junction.** The script builds through a junction named `C:\zd-<6 characters>`, made from a hash of your clone's path, so every clone gets its own and several clones can coexist. Use `-ShortPath <folder>` or the `ZEDU_SHORT_PATH` environment variable to choose another folder. Creating a folder directly under `C:\` may need admin rights on some machines. If it fails, pick a folder you can write to, such as `D:\zd`. If the junction points somewhere else, or its target is gone, the script replaces it. It stops if the path is a real folder.

**The `.env` file.** If `.env` is missing, the script creates it from `.env.example` and prints a yellow warning. It never overwrites an existing `.env`. Edit it and set real values, especially the backend URL (`API_BASE_URL`).

**Close the app before the next run.** If the app from an earlier run is still open, the script stops with `Close the running Zedu app first`. Without that check, the link step fails with `LINK : fatal error LNK1168: cannot open ...\zedu.exe for writing`.

## What the script fixes

Each row is an error you would otherwise hit, why it happens, and which script step handles it. The steps are numbered as they appear in the output.

| Symptom or error message | Cause | Script step |
| --- | --- | --- |
| `Cannot extract through symlink ... .plugin_symlinks\agora_rtc_engine` | The `agora_rtc_engine` CMake script deletes and re-extracts its SDK zips on every build, through a symlink that CMake refuses to write through. Developer Mode and a shorter path do not fix it. | **6. Agora SDK.** Reads the plugin version from `pubspec.lock` and checks the SDK folders in your Pub cache. It downloads and extracts the SDKs if they are missing or incomplete, then creates the `.plugin_dev` file so the plugin skips its own extraction. A fix done by hand with the old manual steps is recognised and kept. A new plugin version gets its own fix automatically. |
| `No file or variants found for asset: .env` | A fresh clone has no `.env` file because Git ignores it, and the build needs it as an asset. | **3. `.env`.** Creates it from `.env.example` and warns you to set real values. |
| `error STL1011: The /await compiler option, <experimental/coroutine> ... are deprecated` in `audioplayers_windows` | Newer MSVC toolsets (VS 2022 17.x and 2026) treat an old coroutine header as an error. The plugin has not been updated for it. | **7. MSVC coroutine flag.** Appends `/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` to `$env:CL` for that run, once, and keeps flags you already set. It changes no files. |
| `file cannot create directory: C:/Program Files/zedu. Maybe need administrative privileges.` | A failed or earlier configure left a `CMakeCache.txt` whose install prefix is under Program Files. A cache created from another folder fails the same way, with `CMakeCache.txt directory is different than where it was created`. | **8. CMake cache.** Deletes `CMakeCache.txt` (never the whole build folder) when its install prefix is under Program Files, it was configured from another folder, the last configure failed, or Agora was just fixed and a stale failed Agora build exists. |
| `error C1083: Cannot open include file: 'AgoraMediaBase.h': No such file or directory` | The Visual Studio compiler stops at 260 characters in a path. The longest Agora header path is your clone path plus about 182 characters, so a long clone path breaks the build even though the file exists. | **2. Short-path junction.** Builds through the short junction described above. |
| `error C1083: Cannot open source file: '...\windows\flutter\ephemeral\cpp_client_wrapper\core_implementations.cc'` | Flutter leaves its `cpp_client_wrapper` sources empty (for example after a build from another path), and its build cache does not always unpack them again. | **4. Flutter engine files** refills the folder from Flutter's engine cache, and runs `flutter precache --windows` first if that cache is missing. It also works when `flutter` is a shim (fvm, puro, scoop). **10. Build** refills it and retries once if Flutter empties it during the build. |
| `Unable to load the service index for source https://api.nuget.org/v3/index.json` or `Failed to install nuget package Microsoft.Windows.ImplementationLibrary` | `audioplayers_windows` downloads this package when CMake configures the build. `api.nuget.org` cannot be reached, for example because of flaky DNS or a restricted network. | **9. NuGet package.** Copies the package from your global NuGet cache (`%USERPROFILE%\.nuget\packages`) into the build folder. The version is read from the plugin. If the package was never downloaded on this machine, there is nothing to copy and the build downloads it. |

The script also does these checks and clean-ups:

| Step | What it does |
| --- | --- |
| **1. Preflight** | Stops with the exact fix if `flutter` is not on `PATH`, Developer Mode is off, or the Visual Studio C++ workload is missing. Warns if you run as administrator. Stops if the app from this clone is still running. |
| **5. `flutter pub get`** | Gets the packages, and stops if that fails. It also creates the plugin links that steps 6 and 9 read. |
| **11. Generated files check** | Running Flutter rewrites the generated plugin registrant files, and Git then lists them as modified. The script prints `Generated files changed. Run git restore linux macos windows/flutter before committing.` It never restores them for you. |

## Manual fallback

Use this only if you cannot run the script. It is the manual procedure the script automates. Run every command in PowerShell, do the steps in order, and note that step 5 is expected to fail and step 6 fixes it.

### Step 1. Check your tools

```powershell
flutter doctor
```

Flutter and Visual Studio with the C++ desktop tools must be green. The Android SDK warning can be ignored for a Windows build.

### Step 2. Clone into a short path

Use a short path with no spaces.

```powershell
cd C:\
mkdir dev
cd dev
git clone https://github.com/hngprojects/zedu-desktop.git
cd zedu-desktop
git checkout <your-branch>
```

### Step 3. Create the `.env` file

Copy the template, or ask your team lead for the dev values. Then confirm Git ignores the file.

```powershell
Copy-Item .env.example .env
git check-ignore -v .env
```

The last command must print a rule from `.gitignore`. If it prints nothing, do not add the file to Git.

### Step 4. Get the packages

```powershell
flutter pub get
```

### Step 5. Run once (expected to fail)

```powershell
flutter run -d windows
```

This run fails with `Cannot extract through symlink`. That is expected. It still downloads the Iris zip that step 6 needs.

### Step 6. Fix the Agora SDK

Put both Agora SDKs in the plugin's `lib` folders yourself, then create an empty `.plugin_dev` file so the plugin skips its own extraction. This changes the Pub cache on your machine, not the repo.

Run these in one PowerShell window.

```powershell
$plugin = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\agora_rtc_engine-6.5.4\windows"

# Iris SDK: extract the downloaded zip, then move the folder into lib
$iris = "$plugin\third_party\iris"
$irisZip = "$iris\iris_4.5.3-build.1_DCG_Windows_Video_Standalone_20260428_1050_31959.zip"
Expand-Archive $irisZip -DestinationPath $iris -Force
New-Item -ItemType Directory "$iris\lib" -Force | Out-Null
Move-Item "$iris\iris_4.5.3-build.1_DCG_Windows" "$iris\lib\"

# Native SDK: download (large, can take a few minutes) and extract into lib
$native = "$plugin\third_party\native"
New-Item -ItemType Directory "$native\lib" -Force | Out-Null
$name = "Agora_Native_SDK_for_Windows_rel.v4.5.3.70_32091_FULL_20260416_1933_1076734.zip"
Invoke-WebRequest "https://download.agora.io/sdk/release/$name" -OutFile "$native\$name"
Expand-Archive "$native\$name" -DestinationPath "$native\lib" -Force

# Tell the plugin to skip its own extraction
New-Item -ItemType File "$plugin\.plugin_dev" -Force
```

Folder and file names are for `agora_rtc_engine` 6.5.4. For another version, copy the names from the plugin's `windows\cmake\DownloadSDK.cmake`.

### Step 7. Clean and run

```powershell
cd C:\dev\zedu-desktop
flutter clean
flutter pub get
$env:CL = "/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
flutter run -d windows
```

- `flutter clean` removes stale build files left by the failed run in step 5. It does not touch the Pub cache, so the Agora fix stays. Do not run Flutter as administrator to get around an install error.
- `$env:CL` fixes the `audioplayers_windows` compiler error. It lasts only for this PowerShell window, so run `flutter run` in the same window.

A successful build ends with `Built build\windows\x64\runner\Debug\zedu.exe` and the app window opens. The first build took about 2.5 minutes. For later runs, you only need the last two lines of step 7 (set `$env:CL`, then `flutter run -d windows`) in a fresh PowerShell window.

### Manual fixes for the other errors

These three are not covered by steps 1 to 7 above.

- **`Cannot open include file: 'AgoraMediaBase.h'`:** your clone path is too long. Clone into a short path (step 2), or create a junction and build from it:

  ```powershell
  New-Item -ItemType Junction -Path C:\zd -Target "<full path to your clone>"
  cd C:\zd
  ```

- **`Cannot open source file ... cpp_client_wrapper\core_implementations.cc`:** copy the contents of `<flutter>\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper` into `windows\flutter\ephemeral\cpp_client_wrapper` and build again. Run `flutter precache --windows` first if that folder is missing.
- **`Failed to install nuget package Microsoft.Windows.ImplementationLibrary`:** `api.nuget.org` is unreachable. Fix the network or DNS, or switch networks, and build again.

## Finding a hidden build error

When a build fails with a long, unclear log, save the whole log and search it. Set `$env:CL` as in step 7 of the manual fallback first, and run it from the folder the script builds in (the `C:\zd-...` junction it prints, or your clone).

```powershell
$log = "$env:TEMP\zedu-build.log"
flutter build windows --debug -v *> $log
Select-String -Path $log -Pattern "error|FAILED|CMake Error" | Select-Object -First 30
```

If a step only says it exited with code 1 (like the install step), run that step by hand to see the real message.

```powershell
$vs = "C:\Program Files\Microsoft Visual Studio\18\Community"
$cmake = "$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
cd <your clone or junction>\build\windows\x64
& $cmake -DBUILD_TYPE=Debug -P cmake_install.cmake 2>&1 | Select-Object -Last 25
```

## Messages safe to ignore

- Git line endings: `LF will be replaced by CRLF` is a reminder on generated Flutter files.
- `super_native_extensions`: `Get-Item : Could not find item ...\AppData` appeared in every run, including the one that worked.
- Rust: `rustc` and `cargo` not recognized did not stop the build, so Rust was not needed.
- `warning MSB8028: The intermediate directory ... contains files shared from another project` appeared in every build through the script.
- `[10/11] Retry: repaired (Flutter emptied cpp_client_wrapper during the build; refilled it and retrying once)` is the script repairing the empty `cpp_client_wrapper`. It is not a new failure.

## Keeping generated files out of Git

Running the app rewrites generated files (`pubspec.lock` and the plugin registrant files). They show up in `git status` but are not part of your work. The script tells you when they changed and never restores them for you.

```powershell
git status
git restore pubspec.lock linux macos windows/flutter
```

## Not verified

This guide and the script were tested on one machine.

- Other Flutter and Visual Studio versions were not tested. The `Visual Studio\18\Community` path is only used for the manual install check.
- The script was run for real under PowerShell 7 and Windows PowerShell 5.1 on one Windows 11 machine, with Developer Mode on. The preflight failure messages for a missing Flutter, Developer Mode off and a missing Visual Studio workload were not triggered, because that machine has all three. The warning for running as administrator was not triggered either.
- A short-path junction whose target folder was deleted (as opposed to pointed at another folder) was not tested.
- Only `agora_rtc_engine` 6.5.4 was tested. For another version the script reads the download URLs from the plugin's `DownloadSDK.cmake`, but that was not exercised.
- The NuGet copy needs the package in your global NuGet cache from an earlier download. A machine that has never reached `api.nuget.org` has nothing to copy.
- Google sign-in did not work locally. Use email and password if the login screen offers it, otherwise ask your team lead how contributors sign in. Do not edit login code to skip authentication.
- After launch, runtime exceptions appeared (uninitialized provider, `TextEditingController` used after being disposed, render overflow, duplicate GlobalKeys). They come from app code, not setup, and were not investigated. Run the target branch the same way to check whether they appear there too before assuming your change caused them.
