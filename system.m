//
//  system.m
//  fouldecrypt
//
//  Created by Brandon Lekai on 5/29/26.
//
#import <Foundation/Foundation.h>
#import <spawn.h>

extern char **environ;


NSString *escape_arg(NSString *arg) {
    return [arg stringByReplacingOccurrencesOfString:@"\'" withString:@"'\\\''"];
}

static NSString *shared_shell_path(void)
{
    static NSString *_sharedShellPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ @autoreleasepool {
        NSArray <NSString *> *possibleShells = @[
            @"/usr/bin/bash",
            @"/bin/bash",
            @"/usr/bin/sh",
            @"/bin/sh",
            @"/usr/bin/zsh",
            @"/bin/zsh",
            @"/var/jb/usr/bin/bash",
            @"/var/jb/bin/bash",
            @"/var/jb/usr/bin/sh",
            @"/var/jb/bin/sh",
            @"/var/jb/usr/bin/zsh",
            @"/var/jb/bin/zsh",
        ];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (NSString *shellPath in possibleShells) {
            // check if the shell exists and is regular file (not symbolic link) and executable
            NSDictionary <NSFileAttributeKey, id> *shellAttrs = [fileManager attributesOfItemAtPath:shellPath error:nil];
            if ([shellAttrs[NSFileType] isEqualToString:NSFileTypeSymbolicLink]) {
                continue;
            }
            if (![fileManager isExecutableFileAtPath:shellPath]) {
                continue;
            }
            _sharedShellPath = shellPath;
            break;
        }
    } });
    return _sharedShellPath;
}

int
my_system(const char *ctx, bool toFile)
{
    const char *shell_path = [shared_shell_path() UTF8String];
    const char *args[] = {
        shell_path,
        "-c",
        ctx,
        NULL
    };
    pid_t pid;
    int posix_status;// = posix_spawn(&pid, shell_path, NULL, NULL, (char **) args, environ);
    if (toFile) {
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/fouldecrypt.log" error:nil];
        posix_spawn_file_actions_t child_fd_actions;
        if ((posix_status = posix_spawn_file_actions_init (&child_fd_actions)))
            perror ("posix_spawn_file_actions_init"), exit(posix_status);
        if ((posix_status = posix_spawn_file_actions_addopen (&child_fd_actions, 1, "/tmp/fouldecrypt.log",
                                                              O_WRONLY | O_CREAT | O_TRUNC, 0644)))
            perror ("posix_spawn_file_actions_addopen"), exit(posix_status);
        if ((posix_status = posix_spawn_file_actions_adddup2 (&child_fd_actions, 1, 2)))
            perror ("posix_spawn_file_actions_adddup2"), exit(posix_status);
        
        if ((posix_status = posix_spawn (&pid, shell_path, &child_fd_actions, NULL, (char **) args, environ)))
            perror ("posix_spawn"), exit(posix_status);
    } else {
        posix_status = posix_spawn(&pid, shell_path, NULL, NULL, (char **) args, environ);
    }
    if (posix_status != 0)
    {
        errno = posix_status;
        fprintf(stderr, "posix_spawn, %s (%d)\n", strerror(errno), errno);
        return posix_status;
    }
    pid_t w;
    int status;
    do
    {
        while ((w = waitpid(pid, &status, WUNTRACED | WCONTINUED )) == -1) {
          if (errno != EINTR) break;
        }
        //w = waitpid(pid, &status, WUNTRACED | WCONTINUED );
        if (w == -1)
        {
            fprintf(stderr, "waitpid %d, %s (%d)\n", pid, strerror(errno), errno);
            return errno;
        }
        if (WIFEXITED(status))
        {
            fprintf(stderr, "pid %d exited, status=%d\n", pid, WEXITSTATUS(status));
        }
        else if (WIFSIGNALED(status))
        {
            fprintf(stderr, "pid %d killed by signal %d\n", pid, WTERMSIG(status));
        }
        else if (WIFSTOPPED(status))
        {
            fprintf(stderr, "pid %d stopped by signal %d\n", pid, WSTOPSIG(status));
        }
        else if (WIFCONTINUED(status))
        {
            fprintf(stderr, "pid %d continued\n", pid);
        }
    }
    while (!WIFEXITED(status) && !WIFSIGNALED(status));
    if (WIFSIGNALED(status))
    {
        return WTERMSIG(status);
    }
    return WEXITSTATUS(status);
}
