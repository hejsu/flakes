/*
 * ucasnet-watcher -- notify a script whenever en0's IPv4 setup changes.
 *
 * Watches State:/Network/Interface/en0/IPv4 in configd's dynamic store. That
 * key holds only Addresses/BroadcastAddresses/SubnetMasks, so it changes when
 * the interface really gets a different address (or loses it) -- DNS churn,
 * IPv6 router advertisements, Wi-Fi scans and roaming never touch it.
 *
 * Usage: ucasnet-watcher <script>
 *
 * Only forwards the event; deciding what changed and whether to act is left to
 * the script, which can read the interface itself. That keeps this file small.
 */
#include <SystemConfiguration/SystemConfiguration.h>
#include <dispatch/dispatch.h>
#include <spawn.h>
#include <stdio.h>
#include <sys/wait.h>

extern char **environ;

static void spawn(const char *path) {
    char *argv[] = { (char *)path, NULL };
    pid_t pid;
    if (posix_spawn(&pid, path, NULL, NULL, argv, environ) == 0) {
        waitpid(pid, NULL, 0);
    }
}

static void changed(SCDynamicStoreRef store, CFArrayRef keys, void *info) {
    (void)store;
    (void)keys;
    spawn(info);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s <script>\n", argv[0]);
        return 2;
    }

    SCDynamicStoreContext context = { 0, argv[1], NULL, NULL, NULL };
    SCDynamicStoreRef store =
        SCDynamicStoreCreate(NULL, CFSTR("org.nixos.ucasnet"), changed, &context);
    if (store == NULL) {
        fprintf(stderr, "ucasnet-watcher: SCDynamicStoreCreate failed\n");
        return 1;
    }

    CFStringRef pattern = CFSTR("State:/Network/Interface/en0/IPv4");
    CFArrayRef patterns =
        CFArrayCreate(NULL, (const void **)&pattern, 1, &kCFTypeArrayCallBacks);
    if (!SCDynamicStoreSetNotificationKeys(store, NULL, patterns)) {
        fprintf(stderr, "ucasnet-watcher: SCDynamicStoreSetNotificationKeys failed\n");
        return 1;
    }
    if (!SCDynamicStoreSetDispatchQueue(store, dispatch_get_main_queue())) {
        fprintf(stderr, "ucasnet-watcher: SCDynamicStoreSetDispatchQueue failed\n");
        return 1;
    }

    spawn(argv[1]); /* align with the current state, e.g. right after boot */
    dispatch_main();
}
