@echo off
echo ===================================================
echo   TokoKu App — Git Upload Setup
echo ===================================================
echo.

:: Check if repository URL is provided
if "%1"=="" (
    echo [ERROR] Anda harus memasukkan URL repository GitHub Anda!
    echo Contoh: setup_git.bat https://github.com/anton1990-90/tokoku.git
    echo.
    pause
    exit /b 1
)

set REPO_URL=%1

:: Initialize Git if not already done
if not exist .git (
    echo [1/4] Inisialisasi Git repository...
    git init -b main
) else (
    echo [1/4] Git repository sudah diinisialisasi.
)

:: Configure local git name/email if needed
git config user.name >nul 2>&1
if errorlevel 1 (
    git config user.name "Hariyanto"
    git config user.email "user@example.com"
)

:: Add all files
echo [2/4] Menambahkan file ke Git index...
git add .

:: Commit files
echo [3/4] Membuat commit pertama...
git commit -m "Inisialisasi TokoKu: offline-first, thermal printing, barcode scanning, CI/CD"

:: Setup remote and push
echo [4/4] Mengatur remote repository & pushing ke GitHub...
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%

echo.
echo Menjalankan 'git push -u origin main'...
git push -u origin main

if errorlevel 1 (
    echo.
    echo [ERROR] Gagal melakukan push ke GitHub!
    echo Pastikan Anda sudah membuat repository di GitHub dan memiliki izin akses.
    echo.
) else (
    echo.
    echo [SUKSES] Kode berhasil di-upload ke GitHub!
    echo Silakan buka repository Anda di browser, klik tab 'Actions',
    echo dan lihat proses build APK Anda sedang berjalan otomatis!
    echo.
)

pause
