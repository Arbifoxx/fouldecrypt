/*
 
 6) Restore old info.plist
 7) Execute foulwrapper, with /tmp/ipa as the temp dir and the bundle id at the bundle id
 8) Uninstall the patched ipa (https://github.com/shepgoba/AppUninstall)
 9) Remove temp files
*/

#import <stdio.h>
#import <spawn.h>
#import <objc/runtime.h>
#import "system.m"

#import <Foundation/Foundation.h>

#import <MobileContainerManager/MCMContainer.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import "ZipArchive/SSZipArchive/SSZipArchive.h"
#import "applepackagetool.m"

static int VERBOSE = 0;

#define MH_MAGIC_64   0xfeedfacf  /* the 64-bit mach magic number */
#define MH_CIGAM_64   0xcffaedfe  /* NXSwapInt(MH_MAGIC_64) */

#define FAT_MAGIC_64  0xcafebabf
#define FAT_CIGAM_64  0xbfbafeca  /* NXSwapLong(FAT_MAGIC_64) */

#define RED     "\x1b[31m"
#define GREEN   "\x1b[32m"
#define RESET   "\x1b[0m"

extern int VERBOSE;
int decrypt_macho(const char *inputFile, const char *outputFile);

@interface LSApplicationProxy ()
- (NSString *)shortVersionString;
@end

@interface LSApplicationWorkspace ()
+ (id)defaultWorkspace;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
@end

void printUsage(char *s) {
    printf("USAGE:\nfoulwrapper -i (ipa file) -o (output directory)\nfoulwrapper -b (bundle id or application name) -o (output directory)\nfoulwrapper --server\n");
}

int main(int argc, char *argv[])
{
    BOOL hasBundle = false;
    BOOL hasIPA = false;
    BOOL hasOutput = false;
    BOOL serverMode = (strcmp(argv[1],"--server") == 0);
    NSError *error = nil;
    NSString *targetId = nil;
    NSString *targetIdOrName;
    NSString *ipaPath;
    NSString *outputFolder;
    NSString *targetPath;
    NSString *tempPath;
    NSURL *tempURL;
    NSString *appName;
    NSDictionary *infoBackup;
    NSString *appPath;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    do {
        if (argc != 5 && !serverMode) {
            printUsage(argv[0]);
            return 1;
        } else if (serverMode) {
            [fm removeItemAtPath:@"/tmp/fouldecrypt" error:nil]; // just to be safe ;)
            [fm createDirectoryAtPath:@"/var/mobile/Documents/Decrypted" withIntermediateDirectories:false attributes:nil error:nil];
            ipaPath = webserver();
            if ([ipaPath isEqualToString:@"nil"]) {
                printf(RED "[-] ERROR: The download failed or the bundle ID was invalid\n" RESET);
                return 1;
            }
            outputFolder = @"/var/mobile/Documents/Decrypted";
            hasIPA = true;
            hasOutput = true;
        } else {
            for (int i = 0; i < argc; i++) {
                if (strcmp(argv[i],"-b") == 0) {
                    hasBundle = true;
                } else if (strcmp(argv[i],"-i") == 0) {
                    hasIPA = true;
                } else if (strcmp(argv[i],"-o") == 0) {
                    hasOutput = true;
                }
            }
            
            if ((!hasBundle && !hasIPA) || (hasBundle && hasIPA) || !hasOutput) {
                printUsage(argv[0]);
                return 1;
            }
            
            for (int i = 1; i < argc; i += 2) {
                if (strcmp(argv[i],"-b") == 0) {
                    targetIdOrName = [NSString stringWithUTF8String:argv[i + 1]];
                } else if (strcmp(argv [i],"-i") == 0) {
                    ipaPath = [NSString stringWithUTF8String:argv[i + 1]];
                } else if (strcmp(argv[i],"-o") == 0) {
                    outputFolder = [NSString stringWithUTF8String:argv[i + 1]];
                } else {
                    printUsage(argv[0]);
                    return 1;
                }
            }
        }
        
        if (hasIPA) {
            // I know this way seems very complicated for what it does, but I genuinely could not get it to work any other way. I originally tried to code it so that the program would extract the ipa and decrypt from there. Some apps would decrypt, but others would fail with operation not permitted or cannot allocate memory errors. At this point, I'm coming at it with a "if it isn't broken, don't fix it" mindset. This method is crude, but it works. ¯\_(ツ)_/¯
            //1) Extract ipa files to /tmp/ipa
            tempURL = [NSURL fileURLWithPath:@"/var/tmp/fd/ipa" isDirectory:true];
            tempPath = @"/var/tmp/fd/ipa/Payload";
            [fm removeItemAtPath:@"/var/tmp/fd" error:nil];
            [fm createDirectoryAtPath:@"/var/tmp/fd" withIntermediateDirectories:true attributes:[NSDictionary dictionaryWithObject:@0777 forKey:NSFilePosixPermissions] error:nil];
            printf(GREEN "[*] Extracting IPA..." RESET "\n");
            [SSZipArchive unzipFileAtPath:ipaPath toDestination:@"/var/tmp/fd/ipa"];
            NSArray *contents = [fm contentsOfDirectoryAtPath:@"/var/tmp/fd/ipa/Payload" error:nil];
            for (int i = 0; i < [contents count]; i++) {
                if ([contents[i] containsString:@".app"]) {
                    appPath = [@"/var/tmp/fd/ipa/Payload/" stringByAppendingString:contents[i]];
                }
            }
            printf(GREEN "[*] Patching temporary IPA..." RESET "\n");
            //2) Store backup of Info.plist
            infoBackup = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingString:@"/Info.plist"]];
            //3) Patch ipa minimum install version and bundle id
            NSMutableDictionary *infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingString:@"/Info.plist"]];
            [infoPlist setValue:@"10.0" forKey:@"MinimumOSVersion"]; // set minimum value
            [infoPlist setValue:@"com.auriot.tempApp" forKey:@"CFBundleIdentifier"];
            [infoPlist setValue:@"Decrypting..." forKey:@"CFBundleName"];
            [infoPlist setValue:@"Decrypting..." forKey:@"CFBundleDisplayName"];
            NSDirectoryEnumerator* plists = [fm enumeratorAtPath:appPath];
            // Remove all instances of original bundle ID (for things like appex extensions)
            for(NSString* plist = nil; plist = [plists nextObject];) {
                if ([plist containsString:@".plist"]) {
                    //  Get around binary plist format
                    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingString:[@"/" stringByAppendingString:plist]]];
                        NSEnumerator *temp = [dict keyEnumerator];
                    [dict writeToFile:@"/var/tmp/fd/temp.plist" atomically:false];
                    NSString* plistString = [NSString stringWithContentsOfFile:@"/var/tmp/fd/temp.plist" encoding:NSUTF8StringEncoding error:nil];
                    [fm removeItemAtPath:@"/var/tmp/fd/temp.plist" error:nil];
                    [[plistString stringByReplacingOccurrencesOfString:[infoBackup valueForKey:@"CFBundleIdentifier"] withString:@"com.auriot.tempApp"] writeToFile:[appPath stringByAppendingString:[@"/" stringByAppendingString:plist]] atomically:false encoding:NSUTF8StringEncoding error:nil];
                }
            }
            //4) Write patched NSDictionary to Info.plist
            [fm removeItemAtPath:[appPath stringByAppendingString:@"/Info.plist"] error:nil];
            [infoPlist writeToFile:[appPath stringByAppendingString:@"/Info.plist"] atomically:true];
            //4) Zip new patched ipa
            printf(GREEN "[*] Compressing patched IPA..." RESET "\n");
            [SSZipArchive createZipFileAtPath:@"/var/tmp/fd/temp.ipa" withContentsOfDirectory:@"/var/tmp/fd/ipa" keepParentDirectory:false compressionLevel:0 password:nil AES:false progressHandler:nil];
            //5) Install Patched ipa with appins
            printf(GREEN "[*] Installing temporary IPA..." RESET "\n");
            LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
            NSError *test = nil;
            [workspace installApplication:[NSURL fileURLWithPath:@"/var/tmp/fd/temp.ipa"] withOptions:[NSDictionary dictionaryWithObject:@"com.auriot.tempApp" forKey:@"CFBundleIdentifier"] error:&test];
            //[fm removeItemAtPath:@"/var/tmp/fd/temp.ipa" error:nil];
            targetIdOrName=@"com.auriot.tempApp";
        }
        /* Use APIs in `LSApplicationWorkspace`. */
        NSMutableDictionary *appMaps = [NSMutableDictionary dictionary];
        LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
        for (LSApplicationProxy *appProxy in [workspace allApplications]) {
            NSString *appId = [appProxy applicationIdentifier];
            NSString *appName = [appProxy localizedName];
            if (appId && appName) {
                appMaps[appId] = appName;
            }
        }
        
        
        for (NSString *appId in appMaps)
        {
            if ([appId isEqualToString:targetIdOrName] || [appMaps[appId] isEqualToString:targetIdOrName])
            {
                targetId = appId;
                break;
            }
        }
        
        if (!targetId)
        {
            fprintf(stderr, "application \"%s\" not found\n", argv[2]);
            return 1;
        }
        
        
        /* MobileContainerManager: locate app bundle container path */
        /* `LSApplicationProxy` cannot provide correct values of container URLs since iOS 12. */
        id aClass = objc_getClass("MCMAppContainer");
        assert([aClass respondsToSelector:@selector(containerWithIdentifier:error:)]);
        
        MCMContainer *container = [aClass containerWithIdentifier:targetId error:&error];
        targetPath = [[container url] path];
        if (!targetPath)
        {
            fprintf(stderr,
                    "application \"%s\" does not have a bundle container: %s\n",
                    argv[2],
                    [[error localizedDescription] UTF8String]);
            return 1;
        }
        printf(GREEN "Bundle path: %s" RESET "\n", [targetPath UTF8String]);
        if (hasBundle) {
            /* Make a copy of app bundle. */
            printf(GREEN "[*] Copying app bundle..." RESET "\n");
            tempURL = [fm URLForDirectory:NSItemReplacementDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:[NSURL fileURLWithPath:[fm currentDirectoryPath]]
                                                               create:YES error:&error];
            if (!tempURL)
            {
                fprintf(stderr,
                        "cannot create appropriate item replacement directory: %s\n",
                        [[error localizedDescription] UTF8String]);
                return 1;
            }
            tempPath = [[tempURL path] stringByAppendingPathComponent:@"Payload"];
            BOOL didCopy = [fm copyItemAtPath:targetPath toPath:tempPath error:&error];
            if (!didCopy)
            {
                fprintf(stderr, "cannot copy app bundle: %s\n", [[error localizedDescription] UTF8String]);
                return 1;
            }
        }
        printf(GREEN "[*] Decrypting..." RESET "\n");
        /* Enumerate entire app bundle to find all Mach-Os. */
        NSEnumerator *enumerator = [fm enumeratorAtPath:tempPath];
        NSString *objectPath = nil;
        while (objectPath = [enumerator nextObject])
        {
            NSString *objectFullPath = [tempPath stringByAppendingPathComponent:objectPath];
            FILE *fp = fopen(objectFullPath.UTF8String, "rb");
            if (!fp)
            {
                perror("fopen");
                continue;
            }
            
            int num = getw(fp);
            if (num == EOF)
            {
                fclose(fp);
                continue;
            }
            if (num == MH_MAGIC_64 || num == FAT_MAGIC_64)
            {
                NSString *objectRawPath = [targetPath stringByAppendingPathComponent:objectPath];
                int decryptStatus =
                my_system([[NSString stringWithFormat:@"fouldecrypt -v '%@' '%@'", escape_arg(objectRawPath), escape_arg(
                                                                                                                         objectFullPath)] UTF8String], false);
                if (decryptStatus != 0) {
                    break;
                }
            }
            
            fclose(fp);
        }
        
        
        /* LSApplicationProxy: get app info */
        LSApplicationProxy *appProxy = [LSApplicationProxy applicationProxyForIdentifier:targetId];
        assert(appProxy);
        
        /* zip: archive */
        NSString* localizedName;
        NSString* shortVersionString;
        if (hasBundle) {
            localizedName = [appProxy localizedName];
            shortVersionString = [appProxy shortVersionString];
        } else if (hasIPA) {
            [infoBackup writeToFile:[appPath stringByAppendingString:@"/Info.plist"] atomically:true];
            localizedName = [infoBackup valueForKey:@"CFBundleDisplayName"];
            shortVersionString = [infoBackup valueForKey:@"CFBundleShortVersionString"];
            NSDirectoryEnumerator* plists = [fm enumeratorAtPath:appPath];
            // Restore all instances of original bundle ID (for things like appex extensions))
            for(NSString* plist = nil; plist = [plists nextObject];) {
                if ([plist containsString:@".plist"]) {
                    //  Get around binary plist format
                    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingString:[@"/" stringByAppendingString:plist]]];
                        NSEnumerator *temp = [dict keyEnumerator];
                    [dict writeToFile:@"/var/tmp/fd/temp.plist" atomically:false];
                    NSString* plistString = [NSString stringWithContentsOfFile:@"/var/tmp/fd/temp.plist" encoding:NSUTF8StringEncoding error:nil];
                    [fm removeItemAtPath:@"/var/tmp/fd/temp.plist" error:nil];
                    [[plistString stringByReplacingOccurrencesOfString:@"com.auriot.tempApp" withString:[infoBackup valueForKey:@"CFBundleIdentifier"]] writeToFile:[appPath stringByAppendingString:[@"/" stringByAppendingString:plist]] atomically:false encoding:NSUTF8StringEncoding error:nil];
                }
            }
        }
        NSString *archiveName = [NSString stringWithFormat:@"%@_%@_dumped.ipa", localizedName, shortVersionString];
        NSURL *archivePath = [NSURL fileURLWithPath:[outputFolder stringByAppendingPathComponent:archiveName]];
        [fm removeItemAtPath:[archivePath path] error:nil];
        printf(GREEN "[*] Compressing decrypted IPA..." RESET "\n");
        [SSZipArchive createZipFileAtPath:[archivePath path] withContentsOfDirectory:[tempURL path] keepParentDirectory:false compressionLevel:0 password:nil AES:false progressHandler:nil];
        // Cleanup temp files
        printf(GREEN "[*] Cleaning up..." RESET "\n");
        [fm removeItemAtPath:@"/var/tmp/fd" error:nil];
        [fm removeItemAtPath:@"/var/fouldecrypt.log" error:nil];
        [fm removeItemAtPath:@"/tmp/fouldecrypt" error:nil];
        if (hasIPA) {
            LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
            [workspace uninstallApplication:@"com.auriot.tempApp" withOptions:[NSDictionary dictionaryWithObject:@"com.auriot.tempApp" forKey:@"CFBundleIdentifier"]];
        }
        printf(GREEN "[*] Done!" RESET "\n");
    } while (serverMode);
    return 0;
}
