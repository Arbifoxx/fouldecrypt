//
//  applepackagetool.m
//  fouldecrypt
//
//  Created by Brandon Lekai on 5/29/26.
//

// TODO: upload completed IPA to oracle server files.arbifox.dev, queueing support

#import <Foundation/Foundation.h>
#import "GCDWebServer/GCDWebServer/Core/GCDWebServer.h"
#import "GCDWebServer/GCDWebServer/Responses/GCDWebServerDataResponse.h"
#import "GCDWebServer/GCDWebServer/Responses/GCDWebServerFileResponse.h"
#import "GCDWebServer/GCDWebServer/Requests/GCDWebServerURLEncodedFormRequest.h"
#include <CommonCrypto/CommonDigest.h>
#import "system.m"
#import "foulwrapper.m"


#define RED     "\x1b[31m"
#define GREEN   "\x1b[32m"
#define RESET   "\x1b[0m"

NSString* foulwrapper(int argc, char *argv[]); // foulwrapper.m
int my_system(const char *ctx, bool toFile); // system.m

const char* removeNewlines(char string[]) {
    return [[[NSString stringWithUTF8String:string] stringByReplacingOccurrencesOfString:@"\n" withString:@""] UTF8String];
}

void logIn(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:@"/var/root/Documents/.ipatool/"]) {
        char email[30];
        char password[30];
        char code[30];
        printf(GREEN "[*] Sign-in required! \n" RESET);
        printf(GREEN "[+] Email: \n" RESET);
        fgets(email, sizeof(email), stdin);
        printf(GREEN "[+] Password: \n" RESET);
        fgets(password, sizeof(password), stdin);
        my_system([[NSString stringWithFormat:@"/var/jb/usr/bin/ApplePackageTool login '%s' '%s' --guid A1B2C3D4E5F6", removeNewlines(email), removeNewlines(password)] UTF8String], true);
        if ([[NSString stringWithContentsOfFile:@"/tmp/fouldecrypt.log" encoding:NSUTF8StringEncoding error:nil] containsString:@"login successful"]) {
            printf(GREEN "[+] Successfully logged in!\n" RESET);
        } else if ([[NSString stringWithContentsOfFile:@"/tmp/fouldecrypt.log" encoding:NSUTF8StringEncoding error:nil] containsString:@"Authentication requires verification code"]) {
            printf(GREEN "[+] 2FA Code: \n" RESET);
            fgets(code, sizeof(code), stdin);
            my_system([[NSString stringWithFormat:@"/var/jb/usr/bin/ApplePackageTool login '%s' '%s' --code '%s' --guid A1B2C3D4E5F6", removeNewlines(email), removeNewlines(password), removeNewlines(code)] UTF8String], true);
            if ([[NSString stringWithContentsOfFile:@"/tmp/fouldecrypt.log" encoding:NSUTF8StringEncoding error:nil] containsString:@"login successful"]) {
                printf(GREEN "[+] Successfully logged in!\n" RESET);
            } else {
                printf(RED "[-] Failed to log in!\n" RESET);
                exit(1);
            }
        } else {
            printf(RED "[-] Failed to log in!\n" RESET);
            exit(1);
        }
        
    }
}
NSString *downloadApp(NSString *bundleID, NSString *version, NSString *platform) {
    logIn();
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:@"/var/tmp/fouldecrypt/" withIntermediateDirectories:true attributes:[NSDictionary dictionaryWithObject:@0777 forKey:NSFilePosixPermissions] error:nil];
    NSString* path = @"/var/root/Documents/.ipatool/";
    NSError* error = nil;
    [fm removeItemAtPath:[path stringByAppendingString:@".DS_Store"] error:nil];
    NSString* account = [NSString stringWithContentsOfFile:[[path stringByAppendingString:[[fm contentsOfDirectoryAtPath:path error:nil] firstObject]] stringByAppendingString:@"/account.json"] encoding:NSUTF8StringEncoding error:nil];
    NSString* email = [account substringWithRange:NSMakeRange([account rangeOfString:@"\"email\" : \"" ].location + 11, [[account substringFromIndex:[account rangeOfString:@"\"email\" : \"" ].location + 11] rangeOfString:@"\""].location)];
    NSString* command = [NSString stringWithFormat:@"/var/jb/usr/bin/ApplePackageTool download '%@' '%@' --output '%@' --guid A1B2C3D4E5F6", email, bundleID, [@"/var/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]]];
    if (![version isEqualToString:@"nil"]) {
        command = [command stringByAppendingString:[NSString stringWithFormat:@" --version-id %@", version]];
    }
    if (![platform isEqualToString:@"nil"]) {
        command = [command stringByAppendingString:[NSString stringWithFormat:@" --platform %@", platform]];
    } else {
        command = [command stringByAppendingString:@" --platform iPhone"];
    }
    my_system([command UTF8String], false);
    if ([fm fileExistsAtPath:[@"/var/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]]]) {
        return [@"/var/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]];
    }
    return @"nil";
    
}

int webserver(void) {
    
    [[NSFileManager defaultManager] removeItemAtPath:@"/var/tmp/fouldecrypt" error:nil];
    
    @autoreleasepool {
        
        GCDWebServer* webServer = [[GCDWebServer alloc] init];
        
        
        [webServer addHandlerForMethod:@"GET"
                                  path:@"/"
                          requestClass:[GCDWebServerRequest class]
                          processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            
            NSString* html = @" \
          <html><body> \
            <form name=\"input\" action=\"/\" method=\"post\" enctype=\"application/x-www-form-urlencoded\"> \
            Please enter a bundle ID: <input type=\"text\" name=\"value\"> \
            <input type=\"submit\" value=\"Submit\"> \
            </form> \
          </body></html> \
        ";
            return [GCDWebServerDataResponse responseWithHTML:html];
            
        }];
        
        [webServer addHandlerForMethod:@"POST"
                                  path:@"/"
                          requestClass:[GCDWebServerURLEncodedFormRequest class]
                          processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
            
            NSString* bundleID = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"bundleid"];
            if (bundleID == nil) {
                printf(RED "[-] Error: No bundle ID was provided" RESET);
                exit(1);
            }
            NSString* version = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"version"];
            if (version == nil) {
                version = @"nil";
            }
            NSString* platform = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"platform"];
            if (platform == nil) {
                platform = @"nil";
            }
            printf(GREEN "[*] Downloading %s...\n" RESET, [bundleID UTF8String]);
            char *args[5] = {"foulwrapper", "-i", (char*)[downloadApp(bundleID, version, platform) UTF8String], "-o", "/var/tmp/decrypted"}; // This is SO janky... ¯\_(ツ)_/¯
            if (strcmp(args[1], "nil") == 0) {
                printf(RED "[-] Error: IPA did not download successfully" RESET);
                exit(1);
            }
            return [GCDWebServerFileResponse responseWithFile:foulwrapper(5, args) isAttachment:true];
            
        }];
        [webServer startWithPort:8080 bonjourName:nil];
        while (true) {
            sleep(1);
        }
        return 0;
    }
}
