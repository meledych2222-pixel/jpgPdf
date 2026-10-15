$ErrorActionPreference = 'Stop'
$project = 'D:\githab\PhotoPDF'
$res = Join-Path $project 'app\src\main\res'
if (!(Test-Path (Join-Path $project 'app\src\main\AndroidManifest.xml'))) { throw "PhotoPDF project not found: $project" }
$backup = Join-Path $project ('icon-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($folder in @('drawable','mipmap-anydpi','mipmap-anydpi-v26')) {
  $p = Join-Path $res $folder
  if (Test-Path $p) { Copy-Item $p (Join-Path $backup $folder) -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $p | Out-Null
}
$vector = @'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#101721" android:pathData="M54,4 A50,50 0,1 1,54 104 A50,50 0,1 1,54 4 Z"/>
    <path android:fillColor="#D7AD70" android:pathData="M54,7 A47,47 0,1 1,54 101 A47,47 0,1 1,54 7 Z"/>
    <path android:fillColor="#101721" android:pathData="M54,10 A44,44 0,1 1,54 98 A44,44 0,1 1,54 10 Z"/>
    <path android:fillColor="#8A9BA8" android:pathData="M21,35 L53,29 L58,66 L27,72 Z"/>
    <path android:fillColor="#E7E4DD" android:pathData="M27,30 L61,30 L61,69 L27,69 Z"/>
    <path android:fillColor="#304D63" android:pathData="M30,33 L58,33 L58,62 L30,62 Z"/>
    <path android:fillColor="#D7AD70" android:pathData="M30,59 L40,47 L47,53 L53,43 L58,50 L58,62 L30,62 Z"/>
    <path android:fillColor="#FFF1CD" android:pathData="M49,39 A4,4 0,1 1,49 47 A4,4 0,1 1,49 39 Z"/>
    <path android:fillColor="#F4F0E8" android:pathData="M56,25 L77,25 L86,34 L86,80 Q86,83 83,83 L56,83 Q53,83 53,80 L53,28 Q53,25 56,25 Z"/>
    <path android:fillColor="#C7B9A4" android:pathData="M77,25 L77,34 L86,34 Z"/>
    <path android:fillColor="#BD3335" android:pathData="M58,46 L81,46 Q83,46 83,48 L83,61 Q83,63 81,63 L58,63 Q56,63 56,61 L56,48 Q56,46 58,46 Z"/>
    <path android:fillColor="#D7AD70" android:pathData="M36,75 L44,75 L44,72 L51,79 L44,86 L44,83 L36,83 Z"/>
</vector>
'@
$adaptive = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/transparent" />
    <foreground android:drawable="@drawable/ic_launcher" />
</adaptive-icon>
'@
$legacy = @'
<?xml version="1.0" encoding="utf-8"?>
<bitmap xmlns:android="http://schemas.android.com/apk/res/android"
    android:src="@drawable/ic_launcher" android:gravity="center" />
'@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $res 'drawable\ic_launcher.xml'),$vector,$utf8)
[IO.File]::WriteAllText((Join-Path $res 'mipmap-anydpi-v26\ic_launcher.xml'),$adaptive,$utf8)
# Legacy resource alias uses a drawable XML reference rather than a bitmap tag.
$legacy = @'
<?xml version="1.0" encoding="utf-8"?>
<inset xmlns:android="http://schemas.android.com/apk/res/android"
    android:drawable="@drawable/ic_launcher" android:inset="0dp" />
'@
[IO.File]::WriteAllText((Join-Path $res 'mipmap-anydpi\ic_launcher.xml'),$legacy,$utf8)
Write-Host "Icon updated. Backup: $backup" -ForegroundColor Green
Write-Host 'Now run: .\gradlew.bat assembleDebug' -ForegroundColor Cyan
