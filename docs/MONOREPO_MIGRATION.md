# Monorepo Migration Guide

## Current Structure

The Flutter app currently resides at the root level of the repository.

## Target Structure

For proper monorepo organization, the Flutter app should be moved to:

```
smartroad/
├── mobile/
│   └── smartroad_flutter/  # Flutter app here
├── backend/
│   ├── graphhopper/
│   ├── api/
│   └── docker-compose.yml
└── docs/
```

## Migration Steps

### Option 1: Git Move (Recommended - Preserves History)

```bash
# Create mobile directory
mkdir -p mobile

# Move Flutter app (preserves git history)
git mv . mobile/smartroad_flutter/

# Move backend files to root
git mv mobile/smartroad_flutter/backend ./

# Update .gitignore paths if needed
# Update any hardcoded paths in scripts
```

### Option 2: Manual Move (Simpler but loses history)

```bash
# Create mobile directory
mkdir -p mobile/smartroad_flutter

# Copy all Flutter files
cp -r lib mobile/smartroad_flutter/
cp -r android mobile/smartroad_flutter/
cp -r ios mobile/smartroad_flutter/
cp -r web mobile/smartroad_flutter/
cp -r linux mobile/smartroad_flutter/
cp -r macos mobile/smartroad_flutter/
cp -r windows mobile/smartroad_flutter/
cp pubspec.yaml mobile/smartroad_flutter/
cp pubspec.lock mobile/smartroad_flutter/
cp analysis_options.yaml mobile/smartroad_flutter/
cp .metadata mobile/smartroad_flutter/
# ... copy all other Flutter-related files

# Remove old files from root
# (after verifying everything works)

# Update paths in:
# - run.sh / run.bat
# - Any CI/CD scripts
# - Documentation
```

## Post-Migration Checklist

After moving the Flutter app:

- [ ] Update `run.sh` and `run.bat` scripts with new paths
- [ ] Update CI/CD configuration (GitHub Actions, etc.)
- [ ] Update documentation paths
- [ ] Test Flutter build: `cd mobile/smartroad_flutter && flutter build apk`
- [ ] Verify Android/iOS builds still work
- [ ] Update any hardcoded paths in code
- [ ] Update IDE project settings if needed

## Important Notes

1. **Backend is already in correct location** - No changes needed
2. **GraphHopper setup is complete** - Located at `backend/graphhopper/`
3. **Migration is optional** - Current structure works, but monorepo is cleaner
4. **Test thoroughly** - Ensure all paths and builds work after migration

## Current Status

- ✅ Backend structure is properly organized
- ✅ GraphHopper is set up and ready
- ⏳ Flutter app migration is pending (optional)



