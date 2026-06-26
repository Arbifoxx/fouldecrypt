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
#import "GCDWebServer/GCDWebServer/Requests/GCDWebServerURLEncodedFormRequest.h"
#include <CommonCrypto/CommonDigest.h>
#import "system.m"


#define RED     "\x1b[31m"
#define GREEN   "\x1b[32m"
#define RESET   "\x1b[0m"

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
    [fm createDirectoryAtPath:@"/tmp/fouldecrypt" withIntermediateDirectories:false attributes:nil error:nil];
    NSString* path = @"/var/root/Documents/.ipatool/";
    NSError* error = nil;
    [fm removeItemAtPath:[path stringByAppendingString:@".DS_Store"] error:nil];
    NSString* account = [NSString stringWithContentsOfFile:[[path stringByAppendingString:[[fm contentsOfDirectoryAtPath:path error:nil] firstObject]] stringByAppendingString:@"/account.json"] encoding:NSUTF8StringEncoding error:nil];
    NSString* email = [account substringWithRange:NSMakeRange([account rangeOfString:@"\"email\" : \"" ].location + 11, [[account substringFromIndex:[account rangeOfString:@"\"email\" : \"" ].location + 11] rangeOfString:@"\""].location)];
    NSString* command = [NSString stringWithFormat:@"/var/jb/usr/bin/ApplePackageTool download '%@' '%@' --output '%@' --guid A1B2C3D4E5F6", email, bundleID, [@"/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]]];
    if (![version isEqualToString:@"nil"]) {
        command = [command stringByAppendingString:[NSString stringWithFormat:@" --version-id %@", version]];
    }
    if (![platform isEqualToString:@"nil"]) {
        command = [command stringByAppendingString:[NSString stringWithFormat:@" --platform %@", platform]];
    } else {
        command = [command stringByAppendingString:@" --platform iPhone"];
    }
    my_system([command UTF8String], false);
    
    if ([fm fileExistsAtPath:[@"/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]]]) {
        return [@"/tmp/fouldecrypt/" stringByAppendingString:[bundleID stringByAppendingString:@".ipa"]];
    }
    return @"nil";
    
}

NSString* webserver(void) {
    
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
      __block NSString* bundleID;
      __block NSString* version;
      __block NSString* platform;

      [webServer addHandlerForMethod:@"POST"
                                path:@"/"
                        requestClass:[GCDWebServerURLEncodedFormRequest class]
                        processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
        
          bundleID = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"bundleid"];
          if (bundleID == nil) {
              printf(RED "[-] Error: No bundle ID was provided" RESET);
              exit(1);
          }
          version = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"version"];
          if (version == nil) {
              version = @"nil";
          }
          platform = [[(GCDWebServerURLEncodedFormRequest*)request arguments] objectForKey:@"platform"];
          if (platform == nil) {
              platform = @"nil";
          }
          printf(GREEN "[*] Downloading %s...\n" RESET, [bundleID UTF8String]);
          return [GCDWebServerDataResponse responseWithHTML:[NSString stringWithFormat:@"Added %@ to queue...", bundleID]];
        
      }];
      [webServer startWithPort:8080 bonjourName:nil];
      while (bundleID == nil) {
          sleep(1);
      }
      [webServer stop];
      return downloadApp(bundleID, version, platform);
  }
}
