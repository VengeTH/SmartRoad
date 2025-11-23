@echo off
REM SmartRoad Flutter Run Script for Windows
REM Usage: run.bat [android|ios]

REM Load environment variables from .env file if it exists
if exist .env (
    for /f "tokens=1,2 delims==" %%a in (.env) do (
        if not "%%a"=="" (
            if not "%%a"=="#" (
                set "%%a=%%b"
            )
        )
    )
)

REM Check if required environment variables are set
if "%SUPABASE_URL%"=="" (
    echo Error: SUPABASE_URL must be set
    echo Either create a .env file or set it as an environment variable
    exit /b 1
)

if "%SUPABASE_ANON_KEY%"=="" (
    echo Error: SUPABASE_ANON_KEY must be set
    echo Either create a .env file or set it as an environment variable
    exit /b 1
)

REM Run Flutter
if "%1"=="ios" (
    flutter run --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% -d ios
) else if "%1"=="android" (
    flutter run --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY% -d android
) else (
    flutter run --dart-define=SUPABASE_URL=%SUPABASE_URL% --dart-define=SUPABASE_ANON_KEY=%SUPABASE_ANON_KEY%
)

