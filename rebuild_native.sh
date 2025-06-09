#!/bin/bash

# A script to rebuild J2V8 native libraries for Android

set -e

echo "J2V8 Native Library Rebuild Script"
echo "=================================="
echo "✅ Builds 16KB-aligned .so libraries for Google Play compliance"

# Check if Android NDK is available
if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "ERROR: ANDROID_NDK_HOME environment variable not set"
    echo "Please install Android NDK and set ANDROID_NDK_HOME"
    exit 1
fi

# Create output directories (replace existing libraries in src/main/jniLibs)
mkdir -p src/main/jniLibs/arm64-v8a
mkdir -p src/main/jniLibs/armeabi-v7a  
mkdir -p src/main/jniLibs/x86
mkdir -p src/main/jniLibs/x86_64
mkdir -p build_native/android

if [ -d "v8.out" ]; then
    echo "✅ V8 libraries found:"
    find v8.out -name "*.a" | sort
else
    curl -L https://download.eclipsesource.com/j2v8/v8/libv8_9.3.345.11_monolith.zip -o libv8.zip && unzip libv8.zip -d v8.out
fi

# API level
API_LEVEL=21

# Function to build for a specific architecture
build_arch() {
    local android_abi=$1
    local v8_arch=$2
    local ndk_arch=$3
    
    echo ""
    echo "Building for $android_abi ($v8_arch)..."
    
    # Check if V8 library exists
    local v8_lib="v8.out/$v8_arch/libv8_monolith.a"
    if [ ! -f "$v8_lib" ]; then
        echo "ERROR: V8 library not found: $v8_lib"
        echo "Please ensure V8 libraries are extracted to v8.out/"
        return 1
    fi
    
    # Set up compiler paths
    local TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64"
    if [ ! -d "$TOOLCHAIN" ]; then
        # Try linux toolchain
        TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
    fi
    
    if [ ! -d "$TOOLCHAIN" ]; then
        echo "ERROR: Could not find Android NDK toolchain"
        return 1
    fi
    
    local CC="$TOOLCHAIN/bin/${ndk_arch}${API_LEVEL}-clang"
    local CXX="$TOOLCHAIN/bin/${ndk_arch}${API_LEVEL}-clang++"
    
    if [ ! -f "$CC" ]; then
        echo "ERROR: Compiler not found: $CC"
        return 1
    fi
    
    echo "Using compiler: $CC"
    
    # Generate JNI header if needed
    if [ ! -f "jni/com_eclipsesource_v8_V8Impl.h" ]; then
        echo "Generating JNI headers..."
        if [ -d "build/intermediates/javac/debug/classes" ]; then
            javah -cp build/intermediates/javac/debug/classes -o jni com.eclipsesource.v8.V8Impl || echo "Warning: Could not generate JNI headers"
        else
            echo "Warning: Java classes not found, using existing JNI headers"
        fi
    fi
    
    # Compile flags
    local CPPFLAGS="-I$ANDROID_NDK_HOME/sysroot/usr/include"
    CPPFLAGS="$CPPFLAGS -I$ANDROID_NDK_HOME/sysroot/usr/include/$ndk_arch"
    CPPFLAGS="$CPPFLAGS -Iv8.out/include"
    CPPFLAGS="$CPPFLAGS -Ijni"
    CPPFLAGS="$CPPFLAGS -fPIC -std=c++17"
    
    # Link flags with 16KB alignment for Google Play compliance
    local LDFLAGS="-shared -llog"
    LDFLAGS="$LDFLAGS -Wl,-z,max-page-size=16384"
    LDFLAGS="$LDFLAGS -Wl,-z,common-page-size=16384"
    
    # Output directly to src/main/jniLibs (replace existing files under version control)
    local OUTPUT="src/main/jniLibs/$android_abi/libj2v8.so"
    
    echo "Compiling libj2v8 for $android_abi..."
    
    # Compile the JNI implementation
    if ! $CXX $CPPFLAGS -c jni/com_eclipsesource_v8_V8Impl.cpp -o "build_native/android/v8impl_$android_abi.o"; then
        echo "ERROR: Compilation failed for $android_abi"
        return 1
    fi
    
    echo "Linking libj2v8 for $android_abi..."
    
    # Link with V8 and output directly to jniLibs
    if ! $CXX $LDFLAGS -o "$OUTPUT" "build_native/android/v8impl_$android_abi.o" "$v8_lib"; then
        echo "ERROR: Linking failed for $android_abi"
        return 1
    fi
    
    echo "✅ Built: $OUTPUT"
    ls -lh "$OUTPUT"
}

# Build for each architecture
echo "Building for all Android architectures..."

build_arch "arm64-v8a" "android.arm64" "aarch64-linux-android"
build_arch "armeabi-v7a" "android.arm" "armv7a-linux-androideabi" 
build_arch "x86" "android.x86" "i686-linux-android"
build_arch "x86_64" "android.x64" "x86_64-linux-android"

echo ""
echo "Native library rebuild complete!"
echo "Libraries compiled and replaced in src/main/jniLibs:"
ls -la src/main/jniLibs/*/libj2v8.so 2>/dev/null || echo "No libraries found in src/main/jniLibs/"
echo ""
./check_elf_alignment.sh src/main/jniLibs
echo "Running './gradlew assembleRelease' to build the AAR with the new native libraries"
./gradlew assembleRelease
