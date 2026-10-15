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
    <application android:allowBackup="false" android:label="PhotoPDF" android:icon="@mipmap/ic_launcher" android:theme="@android:style/Theme.Material.Light.NoActionBar" android:usesCleartextTraffic="false">
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
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.graphics.pdf.PdfDocument;
import android.view.*;
import android.widget.*;
import java.io.*;
import java.util.*;

public class MainActivity extends Activity {
    private static final int PICK=101, SAVE=102;
    private final ArrayList<Uri> images=new ArrayList<>();
    private final int BG=Color.rgb(11,16,24), PANEL=Color.rgb(24,31,41), GOLD=Color.rgb(215,173,112), WHITE=Color.rgb(245,240,232);
    private TextView status; private Button create; private LinearLayout list;
    private boolean busy=false;
    private int dp(float n){return (int)(getResources().getDisplayMetrics().density*n+.5f);}
    private GradientDrawable surface(int color,int stroke){ GradientDrawable d=new GradientDrawable(); d.setColor(color);d.setCornerRadius(dp(19));d.setStroke(dp(1),stroke);return d; }
    private TextView text(String s,int size,int color){TextView t=new TextView(this);t.setText(s);t.setTextSize(size);t.setTextColor(color);return t;}
    private void space(LinearLayout p,int h){View v=new View(this);p.addView(v,new LinearLayout.LayoutParams(1,dp(h)));}
    private Button button(String label,boolean primary){Button b=new Button(this);b.setAllCaps(false);b.setText(label);b.setTextSize(16);b.setTextColor(primary?BG:WHITE);GradientDrawable d=new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,primary?new int[]{0xFFFFE0A5,0xFFD7AD70,0xFF9E6A37}:new int[]{0xFF303743,0xFF161D27});d.setCornerRadius(dp(20));d.setStroke(dp(1),primary?0xFFEED3A4:0xFF7C6040);b.setBackground(d);b.setElevation(dp(5));b.setMinimumHeight(dp(58));return b;}
    @Override public void onCreate(Bundle state){super.onCreate(state);getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);
        ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);scroll.setBackgroundColor(BG);
        LinearLayout root=new LinearLayout(this);root.setOrientation(1);root.setPadding(dp(22),dp(25),dp(22),dp(28));scroll.addView(root);
        TextView brand=text("◆  PhotoPDF",30,GOLD);brand.setTypeface(null,1);root.addView(brand);space(root,7);
        root.addView(text("ФОТО В PDF  •  PREMIUM",12,0xFFAFB7C4));space(root,24);
        LinearLayout hero=new LinearLayout(this);hero.setOrientation(1);hero.setPadding(dp(22),dp(26),dp(22),dp(26));hero.setBackground(surface(PANEL,0xFF60492F));root.addView(hero);
        TextView icon=text("▧   →   PDF",33,GOLD);icon.setGravity(Gravity.CENTER);hero.addView(icon);space(hero,15);
        TextView title=text("Ваши фото. Один PDF.",23,WHITE);title.setTypeface(null,1);title.setGravity(Gravity.CENTER);hero.addView(title);space(hero,8);
        TextView subtitle=text("Быстро • Без интернета • Без регистрации",13,0xFFB9C0C9);subtitle.setGravity(Gravity.CENTER);hero.addView(subtitle);
        space(root,20);Button pick=button("＋  Выбрать фотографии",true);root.addView(pick,new LinearLayout.LayoutParams(-1,dp(60)));pick.setOnClickListener(v->choose());space(root,15);
        status=text("Фотографии пока не выбраны",14,0xFFB9C0C9);root.addView(status);space(root,12);
        list=new LinearLayout(this);list.setOrientation(1);root.addView(list);space(root,10);
        create=button("Создать PDF  →",true);create.setEnabled(false);root.addView(create,new LinearLayout.LayoutParams(-1,dp(60)));create.setOnClickListener(v->save());space(root,24);
        TextView foot=text("A4  •  Несколько страниц  •  Локальная обработка",12,0xFF929AA6);foot.setGravity(Gravity.CENTER);root.addView(foot);
        setContentView(scroll);
    }
    private void refresh(){status.setText(images.isEmpty()?"Фотографии пока не выбраны":"Выбрано фотографий: "+images.size()+"  •  Порядок страниц ниже");create.setEnabled(!busy&&!images.isEmpty());list.removeAllViews();
        for(int i=0;i<images.size();i++){final int index=i;LinearLayout row=new LinearLayout(this);row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(dp(12),dp(5),dp(8),dp(5));row.setBackground(surface(PANEL,0xFF384250));LinearLayout.LayoutParams rp=new LinearLayout.LayoutParams(-1,dp(64));rp.bottomMargin=dp(8);list.addView(row,rp);
            TextView name=text(String.format(java.util.Locale.getDefault(),"%02d   Фото %d",i+1,i+1),15,WHITE);row.addView(name,new LinearLayout.LayoutParams(0,-2,1));
            Button up=button("↑",false),down=button("↓",false),remove=button("×",false);for(Button b:new Button[]{up,down,remove}){b.setTextSize(18);b.setMinWidth(0);b.setMinimumWidth(0);row.addView(b,new LinearLayout.LayoutParams(dp(44),dp(46)));}
            up.setOnClickListener(v->{if(index>0){Collections.swap(images,index,index-1);refresh();}});down.setOnClickListener(v->{if(index<images.size()-1){Collections.swap(images,index,index+1);refresh();}});remove.setOnClickListener(v->{images.remove(index);refresh();});
        }
    }
    private void choose(){Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);i.setType("image/*");i.addCategory(Intent.CATEGORY_OPENABLE);i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE,true);startActivityForResult(i,PICK);}
    private void save(){if(images.isEmpty()||busy)return;Intent i=new Intent(Intent.ACTION_CREATE_DOCUMENT);i.setType("application/pdf");i.addCategory(Intent.CATEGORY_OPENABLE);i.putExtra(Intent.EXTRA_TITLE,"PhotoPDF.pdf");startActivityForResult(i,SAVE);}
    @Override protected void onActivityResult(int request,int result,Intent data){super.onActivityResult(request,result,data);if(result!=RESULT_OK||data==null)return;
        if(request==PICK){images.clear();if(data.getClipData()!=null){for(int j=0;j<data.getClipData().getItemCount();j++)images.add(data.getClipData().getItemAt(j).getUri());}else if(data.getData()!=null)images.add(data.getData());refresh();}
        else if(request==SAVE&&data.getData()!=null){Uri target=data.getData();ArrayList<Uri> snapshot=new ArrayList<>(images);busy=true;create.setEnabled(false);status.setText("Создание PDF…");new Thread(()->{String error=null;try{makePdf(target,snapshot);}catch(Exception e){error=e.getMessage();}final String result=error;runOnUiThread(()->{busy=false;refresh();status.setText(result==null?"✓ PDF сохранён успешно":"Ошибка: "+result);Toast.makeText(this,result==null?"PDF готов":"Не удалось создать PDF",Toast.LENGTH_LONG).show();});}).start();}
    }
    private void makePdf(Uri target,ArrayList<Uri> selected)throws Exception{PdfDocument doc=new PdfDocument();try{Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);int pageNo=0;
        for(Uri uri:selected){BitmapFactory.Options opt=new BitmapFactory.Options();opt.inJustDecodeBounds=true;try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException("Фото недоступно");BitmapFactory.decodeStream(in,null,opt);}if(opt.outWidth<=0||opt.outHeight<=0)throw new IOException("Неподдерживаемый формат фото");opt.inJustDecodeBounds=false;opt.inSampleSize=1;while(Math.max(opt.outWidth/opt.inSampleSize,opt.outHeight/opt.inSampleSize)>2200)opt.inSampleSize*=2;
            Bitmap bitmap;try(InputStream in=getContentResolver().openInputStream(uri)){if(in==null)throw new IOException("Фото недоступно");bitmap=BitmapFactory.decodeStream(in,null,opt);}if(bitmap==null)throw new IOException("Не удалось прочитать фото");
            try{PdfDocument.PageInfo info=new PdfDocument.PageInfo.Builder(595,842,++pageNo).create();PdfDocument.Page page=doc.startPage(info);Canvas c=page.getCanvas();c.drawColor(Color.WHITE);float scale=Math.min(555f/bitmap.getWidth(),802f/bitmap.getHeight());float w=bitmap.getWidth()*scale,h=bitmap.getHeight()*scale;c.drawBitmap(bitmap,null,new RectF((595-w)/2,(842-h)/2,(595+w)/2,(842+h)/2),paint);doc.finishPage(page);}finally{bitmap.recycle();}}
        try(OutputStream out=getContentResolver().openOutputStream(target,"wt")){if(out==null)throw new IOException("Невозможно записать PDF");doc.writeTo(out);}
    }finally{doc.close();}}
}
'@
Write-File 'app/src/main/res/drawable/ic_launcher.xml' @'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
<path android:fillColor="#0B1018" android:pathData="M0,0h108v108h-108z"/>
<path android:fillColor="#D7AD70" android:pathData="M20,15h68a9,9 0,0 1,9 9v60a9,9 0,0 1,-9 9h-68a9,9 0,0 1,-9 -9v-60a9,9 0,0 1,9 -9z"/>
<path android:fillColor="#18202B" android:pathData="M22,19h64a7,7 0,0 1,7 7v56a7,7 0,0 1,-7 7h-64a7,7 0,0 1,-7 -7v-56a7,7 0,0 1,7 -7z"/>
<path android:fillColor="#D7AD70" android:pathData="M27,32h44v39h-44z"/>
<path android:fillColor="#F5F0E8" android:pathData="M37,26h35l12,12v45h-47z"/>
<path android:fillColor="#C5C5C5" android:pathData="M72,26v12h12z"/>
<path android:fillColor="#C62828" android:pathData="M29,56h58v19h-58z"/>
<path android:fillColor="#FFFFFF" android:pathData="M36,62h44v2h-44zM36,67h36v2h-36z"/>
</vector>
'@
Write-File 'app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml' @'
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android"><background android:drawable="@android:color/black"/><foreground android:drawable="@drawable/ic_launcher"/></adaptive-icon>
'@
Write-File 'app/src/main/res/mipmap-anydpi/ic_launcher.xml' @'
<bitmap xmlns:android="http://schemas.android.com/apk/res/android" android:src="@drawable/ic_launcher"/>
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
