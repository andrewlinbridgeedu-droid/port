# Effekseer 1.80.5 — iOS Simulator ARM64

`libEffekseerUnity.a` is the Apple Silicon Simulator build of the same
Effekseer 1.80.5 native plugin already present under `Assets/Effekseer`.

- EffekseerForUnity source commit: `c610bbdd22520a11670c68ab3b84b0e573771986`
- Effekseer core source commit: `332525b2086e4c97f0cdbdd6c2f2b07e26f754d2`
- Source: <https://github.com/effekseer/EffekseerForUnity>
- Target: `arm64-apple-ios14.0-simulator`
- SHA-256: `1098822e23b1d9bade7c65b88cb92133ca680983f029f332e7b465d212c1d076`

The upstream 1.80.5 packaging script removes the Simulator arm64 slice as an
old Xcode 12 workaround. This archive was built from the tagged source with
`BUILD_FOR_IOS_SIM=ON`, `CMAKE_OSX_SYSROOT=iphonesimulator`, and
`CMAKE_OSX_ARCHITECTURES=arm64`, then combined from the Effekseer core,
renderer-common, and Unity bridge static libraries. Its 71 exported Effekseer
C API symbols match the packaged x86_64 Simulator reference slice.

`ExportIOSLibrary` copies this archive only into Simulator exports. Physical
iOS exports continue to use the packaged arm64 device archive unchanged.
