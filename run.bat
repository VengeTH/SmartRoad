@echo off
REM Load .env file and run Flutter with API key
REM Usage: run.bat

echo Loading .env file...

REM Check if .env exists
if not exist .env (
    echo ERROR: .env file not found!
    echo Please create .env file with OPENWEATHERMAP_API_KEY=your_key
    pause
    exit /b 1
)

REM Load OPENWEATHERMAP_API_KEY from .env
set OPENWEATHERMAP_API_KEY=
for /f "tokens=1,* delims==" %%a in ('findstr /b "OPENWEATHERMAP_API_KEY" .env') do (
    set OPENWEATHERMAP_API_KEY=%%b
)

REM Load WEATHER_PROXY_URL from .env (optional)
set WEATHER_PROXY_URL=
for /f "tokens=1,* delims==" %%a in ('findstr /b "WEATHER_PROXY_URL" .env') do (
    set WEATHER_PROXY_URL=%%b
)

REM Load TOMTOM_API_KEY from .env (optional)
set TOMTOM_API_KEY=
for /f "tokens=1,* delims==" %%a in ('findstr /b "TOMTOM_API_KEY" .env') do (
    set TOMTOM_API_KEY=%%b
)

REM Check if API key is set
if "%OPENWEATHERMAP_API_KEY%"=="" (
    echo ERROR: OPENWEATHERMAP_API_KEY not found in .env file!
    echo Please add: OPENWEATHERMAP_API_KEY=your_api_key_here
    pause
    exit /b 1
)

REM Build dart-define arguments
set DART_DEFINES=--dart-define=OPENWEATHERMAP_API_KEY=%OPENWEATHERMAP_API_KEY%

if not "%WEATHER_PROXY_URL%"=="" (
    set DART_DEFINES=%DART_DEFINES% --dart-define=WEATHER_PROXY_URL=%WEATHER_PROXY_URL%
)

if not "%TOMTOM_API_KEY%"=="" (
    set DART_DEFINES=%DART_DEFINES% --dart-define=TOMTOM_API_KEY=%TOMTOM_API_KEY%
)

REM Show what we're doing
echo.
echo Running Flutter with API key from .env...
echo API Key: %OPENWEATHERMAP_API_KEY:~0,10%... (hidden)
if not "%WEATHER_PROXY_URL%"=="" (
    echo Proxy URL: %WEATHER_PROXY_URL%
)
if not "%TOMTOM_API_KEY%"=="" (
    echo TomTom API Key: %TOMTOM_API_KEY:~0,10%... (hidden)
)
echo.

REM Set Flutter path
set FLUTTER_EXE=flutter
if exist "D:\Tools\flutter\bin\flutter.bat" set FLUTTER_EXE="D:\Tools\flutter\bin\flutter.bat"

REM Run Flutter
%FLUTTER_EXE% run %DART_DEFINES% %*
