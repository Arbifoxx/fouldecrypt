# FoulDecrypt

NOTE: This project is still a work in progress! Support for decryption on iOS 15 has been added (at least for 15.3.1, adjacent versions might work. I'd expect 15.0-15.3.1 to work but I have no devices to test it with. Also, the top portion of this README is outdated; I plan on updating it when I finish my foulwrapper server modifications. The part that is up-to-date is the compiling section.

---

It's also available in my Cydia repo: http://repo.misty.moe. FoulDecrypt supports iOS 13.5 and later, and has been tested on iOS 14.2, 14.3 and 13.5 (both arm64 and arm64e).

Note: for unsupported versions, it has chances to panic the device, beware ;)

## Why FoulDecrypt

### 1. Fully static

Thanks to FlexDecrypt and FoulPlay we know there's a mremap_encrypted syscall, although AAPL already released full source code for this syscall now.

However, neither of them can actually get mremap_encrypted to work. That's because mremap_encrypted cannot accept non-aligned address, making it useless for most iOS 14 apps.

I managed to fix with kernel read/writing, so now we can achieve clutch's armv7+arm64 multi-arch decryption again in 2021!

### 2. Simplicity

FlexDecrypt's source code is pretty FAT, bundling the whole swift runtime to just achieve a simple mremap_encrypted.

And at the same time, foulplay independently found the same approach, and implemented it in a much more simple way.

I recompiled the foulplay for iOS, and a wrapper `flexdecrypt2` for flexdecrypt.

## How to use

Install the correct version:
- `fouldecrypt-TFP0` for < iOS 14
- `fouldecrypt-LIBKRW` if you are running Unc0ver
- `fouldecrypt-LIBKERNRW` if you are running Taurine

Run `fouldecrypt` on an encrypted binary.

## About `foulwrapper`

`foulwrapper` will find all Mach-Os in a specific application and decrypt them using `fouldecrypt`:

`usage: foulwrapper (application name or bundle identifier)`

## Compiling
Fouldecrypt is very simple to compile, and can be done in two different ways: with the command line, or with Xcode
### Do this before compiling!
Regardless of whether or not one decides to compile with make or Xcode, a few things are required:
1) An older version of Xcode
    * The SDK embedded in an older version is required to compile this project. For some reason, the latest [Xcode's SDK](https://developer.apple.com/services-account/download?path=/Developer_Tools/Xcode_14.3.1/Xcode_14.3.1.xip) (at the time of writing this, 26) produces errors while compiling. Xcode 14 works just fine. After the older version of Xcode is downloaded, put the path of the application into xcodePath.txt. Please note that the project can still be opened in Xcode 26.
2) [Theos](https://theos.dev/docs/installation)
    * The iPhoneOS16.5 SDK is needed as well. However, I am unsure if this is automatically installed. If not, it can be found [here](https://github.com/theos/sdks/releases/download/master-146e41f/iPhoneOS15.6.sdk.tar.xz). Extract "iPhoneOS16.5.sdk" into your Theos SDK directory (for me it was ~/theos/sdks).
3) I don't think there are any other requirements. If there are, please let me know via a github issue
### Configuration
Before compiling, configuration must be done in the Makefile. Open it with your preferred text editor.
1) For a rootful jailbreak, uncomment "export THEOS_PACKAGE_SCHEME" and comment "export THEOS_PACKAGE_SCHEME = rootless"
2) For a rootless jailbreak, uncomment "export THEOS_PACKAGE_SCHEME = rootless" and comment "export THEOS_PACKAGE_SCHEME"
3) If you're planning on running fouldecrypt on an iOS version that is < iOS 14, uncomment "export USE_TFP0 = 1" and comment the other two options
4) If you're planning on running fouldecrypt on an iOS device that is jailbroken with Unc0ver, uncomment "export USE_LIBKRW = 1" and comment the other two options
5) If you're planning on running fouldecrypt on an iOS device that is jailbroken with Taurine, uncomment "export USE_LIBKERNRW = 1" and comment the other two options
6) If you're planning on running fouldecrypt on an iOS 15, uncomment "export USE_LIBKRW = 1" and comment the other two options

Please make sure that you have libkrw or libkernrw installed on your iOS device depending on your iOS version/jailbreak!
### Compiling with Xcode
1) Open the .xcodeproj in Xcode
2) Select the target you'd like to compile
    * Fouldecrypt for the whole project
    * Foulwrapper for just foulwrapper
    * Deb for a debian package
3) Go to Product -> Build
- NOTE: Don't build the dontbuildme target, that exists only to have Xcode's method autofill work properly. When editing any code in Xcode, select that target for the target to run. Syntax highlighting should appear.
### Compiling with make
1) cd into the project directory
1) run export DEVELOPER_DIR="$(cat xcodePath.txt)"
1) run make
    * make for the whole project
    * make package for a debian package
## Notes
Please note that some parts of my modifications are not the most efficient and/or clean. Prior to starting work on this fork, I had only extensive bash knowledge and basic java knowledge. I knew nothing of Objective-C and creating iOS tweaks as a whole. While working on this project, I have also committed myself to not using any AI, so all of my messy code is my own hah. Please excuse and let me know of anything that could be done better, is redundant, or doesn't work. I'll try my best to fix it! Feedback is welcome!
## Credits
@meme: foulplay
@JohnCoates: flexdecrypt
@NyaMisty: Original fouldecrypt project
@swisspol: GCDWebServer
@ZipArchive: ZipArchive
