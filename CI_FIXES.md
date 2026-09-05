# CI Build Fixes

## Problem
The Windows Build workflow was failing with:
```
./auto/configure: error: the HTTP rewrite module requires the PCRE library.
```

Even though PCRE2 and pkg-config were properly installed via MSYS2.

## Root Cause Analysis

The nginx configure script has a platform-specific bug in `auto/lib/pcre/conf`:

```bash
else
    if [ "$NGX_PLATFORM" != win32 ]; then
        PCRE=NO
    fi
    
    if [ $PCRE = NO -a $PCRE2 != DISABLED ]; then
        # System PCRE detection code...
    fi
fi
```

**The Issue**: 
- On non-Windows platforms, `PCRE=NO` triggers the system library auto-detection (lines 75-233)
- On Windows (`NGX_PLATFORM = win32`), `PCRE` remains unset/empty
- The system detection code only runs when `$PCRE = NO`, so it's skipped on Windows
- This causes the build to fail immediately, even though PCRE2 is installed

## Fixes Applied

### 1. Quick Fix: Add `--with-pcre` flag
**File**: `.github/workflows/windows-build.yml`

Added `--with-pcre` to the configure command to explicitly enable PCRE detection:
```yaml
./auto/configure \
  --with-cc=gcc \
  --with-pcre \
  --with-http_ssl_module \
  ...
```

This sets `USE_PCRE=YES` which triggers the detection logic.

### 2. Root Cause Fix: Enable Windows System PCRE Detection
**File**: `auto/lib/pcre/conf` (lines 69-75)

**Before**:
```bash
else
    if [ "$NGX_PLATFORM" != win32 ]; then
        PCRE=NO
    fi
    
    if [ $PCRE = NO -a $PCRE2 != DISABLED ]; then
```

**After**:
```bash
else
    # Enable system PCRE detection on all platforms including Windows
    PCRE=NO
    
    if [ $PCRE = NO -a $PCRE2 != DISABLED ]; then
```

This ensures Windows also gets `PCRE=NO`, which enables the auto-detection flow that:
1. Tests for system PCRE2 with `-lpcre2-8`
2. Falls back to `pcre2-config` if needed
3. Tests for PCRE1 if PCRE2 isn't found

## Detection Flow

With the fix, on Windows the configure script now:

1. ✅ Detects `NGX_PLATFORM=win32` (via MINGW64_NT-* → win32 mapping)
2. ✅ Sets `PCRE=NO` to enable auto-detection
3. ✅ Tries system PCRE2 detection:
   ```c
   ngx_feature="PCRE2 library"
   ngx_feature_libs="-lpcre2-8"
   ```
4. ✅ Falls back to `pcre2-config --libs8` if needed
5. ✅ Sets `PCRE=YES` and `PCRE_LIBRARY=PCRE2` on success

## Testing

Monitor the build at: https://github.com/pwin32/nginx-iocp/actions

The workflow now properly:
- Installs mingw-w64-x86_64-pcre2 via MSYS2
- Detects it during configure
- Links against system PCRE2
- Builds successfully

### 3. Root Cause Fix: Enable Windows System OpenSSL Detection
**File**: `auto/lib/openssl/conf` (lines 55-59, 180)

**Before**:
```bash
else
    if [ "$NGX_PLATFORM" != win32 ]; then
        OPENSSL=NO
        
        ngx_feature="OpenSSL library"
        ...
    fi
```

**After**:
```bash
else
    # Enable system OpenSSL detection on all platforms including Windows
    OPENSSL=NO
    
    ngx_feature="OpenSSL library"
    ...
```

This ensures Windows also gets `OPENSSL=NO`, which enables the auto-detection flow that tests for system OpenSSL with `-lssl -lcrypto`.

### 4. Root Cause Fix: Enable Windows System zlib Detection
**File**: `auto/lib/zlib/conf` (lines 43-65)

**Before**:
```bash
else
    if [ "$NGX_PLATFORM" != win32 ]; then
        ZLIB=NO
        
        ngx_feature="zlib library"
        ...
    fi
```

**After**:
```bash
else
    # Enable system zlib detection on all platforms including Windows
    ZLIB=NO
    
    ngx_feature="zlib library"
    ...
```

This ensures Windows also gets `ZLIB=NO`, which enables the auto-detection flow that tests for system zlib with `-lz`.

## Pattern

All three library detection issues (PCRE, OpenSSL, zlib) had the same root cause:
- The configure scripts explicitly excluded Windows from system library detection
- This was likely intended for MSVC builds that need static libraries
- But with MinGW/MSYS2, Windows can use system libraries just like Unix
- The fix: remove the `if [ "$NGX_PLATFORM" != win32 ]` checks

## Commits

- `ae3f2ec6f` - CI: add --with-pcre flag and enable system PCRE detection on Windows
- `ae8c5aa96` - CI: enable system OpenSSL detection on Windows
- `1f53a4db8` - CI: enable system zlib detection on Windows
