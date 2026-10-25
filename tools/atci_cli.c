/*
 * atci_cli — send one AT command through MTK's atcid Unix socket and print the reply.
 * Build:  aarch64-linux-gnu-gcc -O2 -static -o atci_cli atci_cli.c
 * Usage:  atci_cli 'AT+EGMR=0,7'
 */
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

#define SOCK_PATH "/dev/socket/adb_atci_socket"

int main(int argc, char **argv)
{
    const char *cmd;
    char line[512];
    char buf[8192];
    int fd, n;
    struct sockaddr_un sa;
    struct timeval tv = { .tv_sec = 5, .tv_usec = 0 };

    if (argc < 2) {
        fprintf(stderr, "usage: %s 'AT+...'\n", argv[0]);
        return 2;
    }
    cmd = argv[1];

    fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) { perror("socket"); return 1; }

    memset(&sa, 0, sizeof(sa));
    sa.sun_family = AF_UNIX;
    strncpy(sa.sun_path, SOCK_PATH, sizeof(sa.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&sa, sizeof(sa)) < 0) {
        perror("connect " SOCK_PATH);
        return 1;
    }
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    snprintf(line, sizeof(line), "%s\r", cmd);
    if (write(fd, line, strlen(line)) < 0) { perror("write"); return 1; }

    /* read whatever comes back until timeout */
    for (;;) {
        n = read(fd, buf, sizeof(buf) - 1);
        if (n <= 0)
            break;
        buf[n] = 0;
        fputs(buf, stdout);
    }
    fputc('\n', stdout);
    close(fd);
    return 0;
}
