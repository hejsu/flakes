/*
 * ucasnet-watcher -- notify a script when en0 enters or leaves the dorm subnet.
 *
 * Watches State:/Network/Interface/en0/IPv4 in configd's dynamic store. That
 * key holds only Addresses/BroadcastAddresses/SubnetMasks, so it changes when
 * the interface really gets a different address (or loses it) -- DNS churn,
 * IPv6 router advertisements, Wi-Fi scans and roaming never touch it.
 *
 * The notification only means "the key was written", and configd rewrites it
 * on every DHCP renewal, so the value is compared here and identical updates
 * are dropped without spawning anything. The comparison key is the address
 * while it is inside DORM_CIDR, and a single constant outside: moving between
 * foreign networks spawns nothing. Inside the dorm the address stays part of
 * the key, because a new lease there can invalidate the portal session.
 *
 * Usage: ucasnet-watcher <script>
 *
 * The script is spawned with the current mode and address as argv[1] and
 * argv[2], and runs once at startup so a reboot always re-applies the state.
 */
#include <SystemConfiguration/SystemConfiguration.h>
#include <arpa/inet.h>
#include <dispatch/dispatch.h>
#include <errno.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>

#ifndef DORM_CIDR
#error "build with -DDORM_CIDR set to the dorm subnet in CIDR form"
#endif

extern char **environ;

static char last[80];
static int seen;
static int booting = 1;

/* True when address falls inside DORM_CIDR, e.g. "10.211.192.0/21". */
static int in_dorm(const char *address) {
    char cidr[sizeof DORM_CIDR];
    char *slash;
    unsigned long bits;
    uint32_t mask;
    struct in_addr addr, net;

    if (address == NULL || *address == '\0') {
        return 0;
    }

    memcpy(cidr, DORM_CIDR, sizeof cidr);
    slash = strchr(cidr, '/');
    if (slash == NULL) {
        return 0;
    }
    *slash = '\0';

    bits = strtoul(slash + 1, NULL, 10);
    if (bits > 32) {
        return 0;
    }
    if (inet_pton(AF_INET, address, &addr) != 1 ||
        inet_pton(AF_INET, cidr, &net) != 1) {
        return 0;
    }

    mask = bits == 0 ? 0 : 0xFFFFFFFFu << (32 - bits);
    return (ntohl(addr.s_addr) & mask) == (ntohl(net.s_addr) & mask);
}

static CFStringRef copy_address(SCDynamicStoreRef store) {
    CFStringRef key = CFSTR("State:/Network/Interface/en0/IPv4");
    CFPropertyListRef value = SCDynamicStoreCopyValue(store, key);
    if (value == NULL) {
        return NULL;
    }
    if (CFGetTypeID(value) != CFDictionaryGetTypeID()) {
        CFRelease(value);
        return NULL;
    }

    CFStringRef address = NULL;
    CFArrayRef addrs = CFDictionaryGetValue(value, CFSTR("Addresses"));
    if (addrs != NULL && CFGetTypeID(addrs) == CFArrayGetTypeID() &&
        CFArrayGetCount(addrs) > 0) {
        CFStringRef first = CFArrayGetValueAtIndex(addrs, 0);
        if (first != NULL && CFGetTypeID(first) == CFStringGetTypeID()) {
            address = CFStringCreateCopy(NULL, first);
        }
    }

    CFRelease(value);
    return address;
}

static void spawn(const char *script, const char *mode, const char *address) {
    char *argv[] = { (char *)script, (char *)mode, (char *)address, NULL };
    const char *tag = booting ? "boot" : "event";
    pid_t pid;
    int status = 0;
    int rc;

    /* A boot line on stdout keeps the decision visible even if the script dies
     * before it can log anything; per-event output is the script's own. */
    if (booting) {
        char stamp[32];
        time_t now = time(NULL);
        struct tm tm;

        localtime_r(&now, &tm);
        strftime(stamp, sizeof stamp, "%H:%M:%S", &tm);
        printf("ucasnet-watcher: %s boot %s %s\n", stamp, mode,
               address[0] != '\0' ? address : "(no address)");
        fflush(stdout);
    }

    rc = posix_spawn(&pid, script, NULL, NULL, argv, environ);
    if (rc != 0) {
        fprintf(stderr, "ucasnet-watcher: spawn %s: %s\n", script, strerror(rc));
        return;
    }
    while (waitpid(pid, &status, 0) == -1 && errno == EINTR) {
    }
    if (WIFSIGNALED(status)) {
        fprintf(stderr, "ucasnet-watcher: %s script killed by signal %d\n", tag,
                WTERMSIG(status));
    } else if (WIFEXITED(status) && WEXITSTATUS(status) != 0) {
        fprintf(stderr, "ucasnet-watcher: %s script exited %d\n", tag,
                WEXITSTATUS(status));
    }
}

static void changed(SCDynamicStoreRef store, CFArrayRef keys, void *info) {
    char address[64] = "";
    char key[80];
    int dorm;

    (void)keys;

    CFStringRef value = copy_address(store);
    if (value != NULL) {
        if (!CFStringGetCString(value, address, sizeof address, kCFStringEncodingUTF8)) {
            address[0] = '\0';
        }
        CFRelease(value);
    }

    dorm = in_dorm(address);
    snprintf(key, sizeof key, "%s", dorm ? address : "-");

    /* A lease renewal rewrites the same value; only real moves matter. */
    if (seen && strcmp(key, last) == 0) {
        return;
    }
    seen = 1;
    snprintf(last, sizeof last, "%s", key);

    spawn(info, dorm ? "dorm" : "other", address);
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

    /* Apply the current state once: after a reboot nothing is armed yet. */
    changed(store, NULL, argv[1]);
    booting = 0;
    dispatch_main();
}
