$ErrorActionPreference = 'Stop'
$root = 'D:\githab\PhotoPDF'
New-Item -ItemType Directory -Force -Path $root | Out-Null
Set-Location $root
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-File([string]$path,[string]$content) {
  $full = Join-Path $root $path
  New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
  [System.IO.File]::WriteAllText($full,$content,$utf8)
}
Write-File 'settings.gradle' @'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = 'PhotoPDF'
include ':app'
'@
Write-File 'build.gradle' @'
plugins {
    id 'com.android.application' version '8.7.3' apply false
}
'@
Write-File 'gradle.properties' @'
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
'@
Write-File 'app/build.gradle' @'
plugins { id 'com.android.application' }

android {
    namespace 'com.photopdf.app'
    compileSdk 35
    defaultConfig {
        applicationId 'com.photopdf.app'
        minSdk 26
        targetSdk 35
        versionCode 1
        versionName '1.0.0'
    }
    buildTypes {
        release { minifyEnabled false }
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
'@
Write-File 'app/src/main/AndroidManifest.xml' @'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="false" android:label="PhotoPDF" android:theme="@android:style/Theme.Material.Light.NoActionBar" android:usesCleartextTraffic="false">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
'@
Write-File 'app/src/main/java/com/photopdf/app/MainActivity.java' @'
package com.photopdf.app;

import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.net.Uri;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.pdf.PdfDocument;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;

public class MainActivity extends Activity {
    private static final int PICK = 101, SAVE = 102;
    private final ArrayList<Uri> images = new ArrayList<>();
    private TextView status;
    private Button create;
    private boolean busy = false;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(28, 56, 28, 24);
        layout.setBackgroundColor(Color.rgb(248, 250, 252));
        TextView title = new TextView(this);
        title.setText("PhotoPDF"); title.setTextSize(30); title.setTextColor(Color.rgb(25, 35, 55));
        layout.addView(title);
        TextView hint = new TextView(this);
        hint.setText("Создавайте PDF из фотографий без интернета"); hint.setTextSize(16);
        layout.addView(hint);
        status = new TextView(this);
        status.setText("Фотографии не выбраны"); status.setPadding(0, 35, 0, 20);
        layout.addView(status);
        Button select = new Button(this);
        select.setText("Выбрать фотографии"); layout.addView(select);
        create = new Button(this);
        create.setText("Создать PDF"); create.setEnabled(false); layout.addView(create);
        setContentView(layout);
        select.setOnClickListener(v -> choose());
        create.setOnClickListener(v -> save());
    }
    private void choose() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.setType("image/*"); intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
        startActivityForResult(intent, PICK);
    }
    private void save() {
        if (images.isEmpty() || busy) return;
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.setType("application/pdf"); intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.putExtra(Intent.EXTRA_TITLE, "PhotoPDF.pdf");
        startActivityForResult(intent, SAVE);
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (result != RESULT_OK || data == null) return;
        if (request == PICK) {
            images.clear();
            if (data.getClipData() != null) {
                for (int i = 0; i < data.getClipData().getItemCount(); i++)
                    images.add(data.getClipData().getItemAt(i).getUri());
            } else if (data.getData() != null) images.add(data.getData());
            status.setText("Выбрано фото: " + images.size());
            create.setEnabled(!images.isEmpty());
        } else if (request == SAVE && data.getData() != null) {
            Uri target = data.getData();
            busy = true; create.setEnabled(false); status.setText("Создание PDF...");
            new Thread(() -> {
                String error = null;
                try { makePdf(target); } catch (Exception ex) { error = ex.getMessage(); }
                final String resultMessage = error;
                runOnUiThread(() -> {
                    busy = false; create.setEnabled(!images.isEmpty());
                    status.setText(resultMessage == null ? "PDF сохранён" : "Ошибка: " + resultMessage);
                    Toast.makeText(this, resultMessage == null ? "PDF готов" : "Не удалось создать PDF", Toast.LENGTH_LONG).show();
                });
            }).start();
        }
    }
    private void makePdf(Uri target) throws Exception {
        PdfDocument document = new PdfDocument();
        try {
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG);
            int pageNumber = 0;
            for (Uri image : images) {
                BitmapFactory.Options opts = new BitmapFactory.Options();
                opts.inJustDecodeBounds = true;
                try (InputStream in = getContentResolver().openInputStream(image)) {
                    if (in == null) throw new Exception("Не удалось открыть фото");
                    BitmapFactory.decodeStream(in, null, opts);
                }
                if (opts.outWidth <= 0 || opts.outHeight <= 0) throw new Exception("Неподдерживаемое изображение");
                opts.inJustDecodeBounds = false;
                opts.inSampleSize = 1;
                while (Math.max(opts.outWidth / opts.inSampleSize, opts.outHeight / opts.inSampleSize) > 2200)
                    opts.inSampleSize *= 2;
                Bitmap bitmap;
                try (InputStream in = getContentResolver().openInputStream(image)) {
                    if (in == null) throw new Exception("Не удалось открыть фото");
                    bitmap = BitmapFactory.decodeStream(in, null, opts);
                }
                if (bitmap == null) throw new Exception("Не удалось прочитать фото");
                try {
                    PdfDocument.PageInfo info = new PdfDocument.PageInfo.Builder(595, 842, ++pageNumber).create();
                    PdfDocument.Page page = document.startPage(info);
                    Canvas canvas = page.getCanvas();
                    canvas.drawColor(Color.WHITE);
                    float scale = Math.min(555f / bitmap.getWidth(), 802f / bitmap.getHeight());
                    float width = bitmap.getWidth() * scale, height = bitmap.getHeight() * scale;
                    android.graphics.RectF dest = new android.graphics.RectF((595 - width) / 2, (842 - height) / 2, (595 + width) / 2, (842 + height) / 2);
                    canvas.drawBitmap(bitmap, null, dest, paint);
                    document.finishPage(page);
                } finally { bitmap.recycle(); }
            }
            try (OutputStream out = getContentResolver().openOutputStream(target, "wt")) {
                if (out == null) throw new Exception("Не удалось открыть PDF для записи");
                document.writeTo(out);
            }
        } finally { document.close(); }
    }
}
'@
Write-File '.gitignore' @'
.gradle/
.idea/
local.properties
/build/
/app/build/
*.jks
*.keystore
'@
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" }
Write-File 'local.properties' ('sdk.dir=' + ($sdk -replace '\\','/'))
Write-Host 'Project created at:' $root -ForegroundColor Green
$studio = Join-Path $env:ProgramFiles 'Android\Android Studio\bin\studio64.exe'
if (Test-Path $studio) { Start-Process $studio -ArgumentList ('"' + $root + '"') }
Write-Host 'In Android Studio: Sync Project, then Build > Build APK(s).' -ForegroundColor Cyan
