/*
 * ucasnet-watcher -- run a script whenever en0's IPv4 broadcast address changes.
 *
 * Watches State:/Network/Interface/en0/IPv4 in configd's dynamic store. That
 * key holds only Addresses/BroadcastAddresses/SubnetMasks, so it changes when
 * the interface really gets a different address (or loses it) -- DNS churn,
 * IPv6 router advertisements, Wi-Fi scans and roaming never touch it.
 *
 * The notification only means "the key was written", and configd rewrites it
 * on every DHCP renewal, so the value is compared here and identical updates
 * are dropped without spawning anything.
 *
 * Usage: ucasnet-watcher <script>
 *
 * The script receives the current broadcast address as argv[1], or an empty
 * string when en0 has no IPv4 address. It runs once at startup so a reboot
 * always re-applies the current state.
 */
#include <SystemConfiguration/SystemConfiguration.h>
#include <dispatch/dispatch.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;

static char last[64];
static int seen;

static CFStringRef copy_broadcast(SCDynamicStoreRef store) {
    CFStringRef key = CFSTR("State:/Network/Interface/en0/IPv4");
    CFPropertyListRef value = SCDynamicStoreCopyValue(store, key);
    if (value == NULL) {
        return NULL;
    }
    if (CFGetTypeID(value) != CFDictionaryGetTypeID()) {
        CFRelease(value);
        return NULL;
    }

    CFStringRef broadcast = NULL;
    CFArrayRef addrs = CFDictionaryGetValue(value, CFSTR("BroadcastAddresses"));
    if (addrs != NULL && CFGetTypeID(addrs) == CFArrayGetTypeID() &&
        CFArrayGetCount(addrs) > 0) {
        CFStringRef first = CFArrayGetValueAtIndex(addrs, 0);
        if (first != NULL && CFGetTypeID(first) == CFStringGetTypeID()) {
            broadcast = CFStringCreateCopy(NULL, first);
        }
    }

    CFRelease(value);
    return broadcast;
}

static void spawn(const char *script, const char *broadcast) {
    char *argv[] = { (char *)script, (char *)broadcast, NULL };
    pid_t pid;
    if (posix_spawn(&pid, script, NULL, NULL, argv, environ) == 0) {
        waitpid(pid, NULL, 0);
    }
}

static void changed(SCDynamicStoreRef store, CFArrayRef keys, void *info) {
    char broadcast[64] = "";

    (void)keys;

    CFStringRef value = copy_broadcast(store);
    if (value != NULL) {
        if (!CFStringGetCString(value, broadcast, sizeof broadcast, kCFStringEncodingUTF8)) {
            broadcast[0] = '\0';
        }
        CFRelease(value);
    }

    /* A lease renewal rewrites the same value; only real moves matter. */
    if (seen && strcmp(broadcast, last) == 0) {
        return;
    }
    seen = 1;
    snprintf(last, sizeof last, "%s", broadcast);

    spawn(info, broadcast);
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

    changed(store, NULL, argv[1]); /* align with the current state, e.g. after boot */
    dispatch_main();
}
