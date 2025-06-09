# Setup for J2V8 Native Library Building

## Install Android NDK

**Install NDK via SDK Manager**
- Open Android Studio
- Go to Tools > SDK Manager
- Click "SDK Tools" tab
- Check NDK and click apply

**Set environment variable**
```bash
# Add to ~/.zshrc or ~/.bash_profile
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/[version]
# Example: export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/25.2.9519653

# Reload shell
source ~/.zshrc
```

## Run the build script

```bash
./rebuild_native.sh
```
This will compile new .so libraries from V8 sources and place them in `src/main/jniLibs/` replacing the existing ones.
It will also run `./gradlew assembleRelease` and build the .aar artifact.