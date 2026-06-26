TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e
export ADDITIONAL_CFLAGS = -DTHEOS_LEAN_AND_MEAN -fobjc-arc -IZipArchive/SSZipArchive/minizip/ -IZipArchive/SSZipArchive -IZipArchive -IGCDWebServer/GCDWebServer/Core -IGCDWebServer/GCDWebServer/Requests -IGCDWebServer/GCDWebServer/Responses
THEOS_PLATFORM_DEB_COMPRESSION_TYPE = gzip

include $(THEOS)/makefiles/common.mk

# Uncomment me for rootful jailbreaks
# export THEOS_PACKAGE_SCHEME

# Uncomment me for rootless jailbreaks
export THEOS_PACKAGE_SCHEME = rootless

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)  
    export THEOS_PACKAGE_ARCH = iphoneos-arm64
else
    export THEOS_PACKAGE_ARCH = iphoneos-arm
endif

TOOL_NAME = fouldecrypt flexdecrypt2 foulwrapper

# export USE_TFP0 = 1
export USE_LIBKRW = 1
# export USE_LIBKERNRW = 1

fouldecrypt_FILES = main.cpp foulmain.cpp
fouldecrypt_CFLAGS = -fobjc-arc -Wno-unused-variable # -Ipriv_include
fouldecrypt_CCFLAGS = $(fouldecrypt_CFLAGS)
fouldecrypt_CODESIGN_FLAGS = -Sentitlements.plist
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)  
    fouldecrypt_INSTALL_PATH = /var/jb/usr/bin  
else
    fouldecrypt_LDFLAGS += -Wl,-rpath "/usr/lib"
    fouldecrypt_INSTALL_PATH = /usr/bin
endif
fouldecrypt_SUBPROJECTS = kerninfra
fouldecrypt_LDFLAGS += -Lkerninfra/libs
fouldecrypt_CCFLAGS += -std=c++2a

flexdecrypt2_FILES = main.cpp flexwrapper.cpp
flexdecrypt2_CFLAGS = -fobjc-arc -Wno-unused-variable # -Ipriv_include
flexdecrypt2_CCFLAGS = $(flexdecrypt2_CFLAGS)
flexdecrypt2_CODESIGN_FLAGS = -Sentitlements.plist
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)  
    flexdecrypt2_INSTALL_PATH = /var/jb/usr/bin  
else
    flexdecrypt2_INSTALL_PATH = /usr/bin
    flexdecrypt2_LDFLAGS += -Wl,-rpath "/usr/lib"
endif
flexdecrypt2_SUBPROJECTS = kerninfra
flexdecrypt2_LDFLAGS += -Lkerninfra/libs
flexdecrypt2_CCFLAGS += -std=c++2a

foulwrapper_FILES = foulwrapper.m
foulwrapper_FILES += ZipArchive/SSZipArchive/minizip/crypt.c ZipArchive/SSZipArchive/minizip/unzip.c ZipArchive/SSZipArchive/minizip/zip.c ZipArchive/SSZipArchive/minizip/ioapi.c ZipArchive/SSZipArchive/minizip/ioapi_buf.c ZipArchive/SSZipArchive/minizip/ioapi_mem.c ZipArchive/SSZipArchive/minizip/minishared.c ZipArchive/SSZipArchive/minizip/aes/aeskey.c ZipArchive/SSZipArchive/minizip/aes/hmac.c ZipArchive/SSZipArchive/minizip/aes/aescrypt.c ZipArchive/SSZipArchive/minizip/aes/fileenc.c ZipArchive/SSZipArchive/minizip/aes/sha1.c ZipArchive/SSZipArchive/minizip/aes/aes_ni.c ZipArchive/SSZipArchive/minizip/aes/prng.c ZipArchive/SSZipArchive/minizip/aes/pwd2key.c ZipArchive/SSZipArchive/minizip/aes/aestab.c ZipArchive/SSZipArchive/SSZipArchive.m GCDWebServer/GCDWebServer/Core/GCDWebServerResponse.m GCDWebServer/GCDWebServer/Core/GCDWebServerRequest.m GCDWebServer/GCDWebServer/Core/GCDWebServerFunctions.m GCDWebServer/GCDWebServer/Core/GCDWebServer.m GCDWebServer/GCDWebServer/Core/GCDWebServerConnection.m GCDWebServer/GCDWebServer/Responses/GCDWebServerErrorResponse.m GCDWebServer/GCDWebServer/Responses/GCDWebServerFileResponse.m GCDWebServer/GCDWebServer/Responses/GCDWebServerDataResponse.m GCDWebServer/GCDWebServer/Responses/GCDWebServerStreamedResponse.m GCDWebServer/GCDWebServer/Requests/GCDWebServerURLEncodedFormRequest.m GCDWebServer/GCDWebServer/Requests/GCDWebServerMultiPartFormRequest.m GCDWebServer/GCDWebServer/Requests/GCDWebServerDataRequest.m GCDWebServer/GCDWebServer/Requests/GCDWebServerFileRequest.m
foulwrapper_CFLAGS = -fobjc-arc -Wno-unused-variable -Iinclude -IAppSync/appinst
foulwrapper_CCFLAGS = $(foulwrapper_CFLAGS)
foulwrapper_CODESIGN_FLAGS = -Sentitlements.plist
ifeq ($(THEOS_PACKAGE_SCHEME),rootless)  
    foulwrapper_INSTALL_PATH = /var/jb/usr/bin  
else
    foulwrapper_INSTALL_PATH = /usr/bin
    foulwrapper_LDFLAGS += -Wl,-rpath "/usr/lib"
endif
foulwrapper_FRAMEWORKS = Foundation MobileCoreServices
foulwrapper_PRIVATE_FRAMEWORKS = MobileContainerManager
foulwrapper_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
