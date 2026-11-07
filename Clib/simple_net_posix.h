/*
 * simple_net_posix.h - IPv4 TCP primitives for macOS and Linux.
 *
 * The same calls as the Windows externals in platform/windows, with the same
 * error numbers: errno and getaddrinfo results are translated to the Winsock
 * code for the same failure, so `last_error_code' means one thing everywhere.
 * (errno values differ between macOS and Linux; ECONNREFUSED is 61 and 111.)
 *
 * poll rather than select, so a descriptor above FD_SETSIZE still works.
 * Sockets never raise SIGPIPE: SO_NOSIGPIPE on macOS, MSG_NOSIGNAL on Linux.
 *
 * Copyright (c) 2026 Larry Rix - MIT License
 */

#ifndef SIMPLE_NET_POSIX_H
#define SIMPLE_NET_POSIX_H

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#ifndef MSG_NOSIGNAL
#define MSG_NOSIGNAL 0
#endif

#define SN_WSAEACCES 10013
#define SN_WSAEINVAL 10022
#define SN_WSAENOTSOCK 10038
#define SN_WSAEADDRINUSE 10048
#define SN_WSAEADDRNOTAVAIL 10049
#define SN_WSAENETDOWN 10050
#define SN_WSAENETUNREACH 10051
#define SN_WSAECONNABORTED 10053
#define SN_WSAECONNRESET 10054
#define SN_WSAENOTCONN 10057
#define SN_WSAETIMEDOUT 10060
#define SN_WSAECONNREFUSED 10061
#define SN_WSAEHOSTUNREACH 10065
#define SN_WSAHOST_NOT_FOUND 11001
#define SN_WSATRY_AGAIN 11002
#define SN_WSANO_RECOVERY 11003

/* The Winsock code for `a_errno'. An errno with no counterpart reads as
   10000 + errno, Winsock's own numbering rule, so it is never 0. */
static int sn_code(int a_errno)
{
    switch (a_errno) {
    case EACCES: case EPERM: return SN_WSAEACCES;
    case EINVAL: return SN_WSAEINVAL;
    case EBADF: case ENOTSOCK: return SN_WSAENOTSOCK;
    case EADDRINUSE: return SN_WSAEADDRINUSE;
    case EADDRNOTAVAIL: return SN_WSAEADDRNOTAVAIL;
    case ENETDOWN: return SN_WSAENETDOWN;
    case ENETUNREACH: return SN_WSAENETUNREACH;
    case ECONNABORTED: return SN_WSAECONNABORTED;
    case ECONNRESET: case EPIPE: return SN_WSAECONNRESET;
    case ENOTCONN: return SN_WSAENOTCONN;
    case ETIMEDOUT: return SN_WSAETIMEDOUT;
    case ECONNREFUSED: return SN_WSAECONNREFUSED;
    case EHOSTUNREACH: case EHOSTDOWN: return SN_WSAEHOSTUNREACH;
    default: return 10000 + a_errno;
    }
}

/* The Winsock code for getaddrinfo result `a_result'. */
static int sn_lookup_code(int a_result)
{
    switch (a_result) {
    case EAI_NONAME: return SN_WSAHOST_NOT_FOUND;
    case EAI_AGAIN: return SN_WSATRY_AGAIN;
    case EAI_SYSTEM: return sn_code(errno);
    default: return SN_WSANO_RECOVERY;
    }
}

static long long sn_now_ms(void)
{
    struct timespec l_now;
    clock_gettime(CLOCK_MONOTONIC, &l_now);
    return (long long) l_now.tv_sec * 1000 + l_now.tv_nsec / 1000000;
}

/* Wait up to `a_timeout_ms' for `a_events' on `a_fd'. 0 when ready, else the
   code. A signal does not shorten the wait. */
static int sn_wait(int a_fd, short a_events, int a_timeout_ms)
{
    struct pollfd l_wait;
    long long l_end = sn_now_ms() + a_timeout_ms;
    long long l_left = a_timeout_ms;
    int l_result;

    for (;;) {
        l_wait.fd = a_fd;
        l_wait.events = a_events;
        l_wait.revents = 0;
        l_result = poll(&l_wait, 1, (int) l_left);
        if (l_result > 0) return (l_wait.revents & POLLNVAL) ? SN_WSAENOTSOCK : 0;
        if (l_result == 0) return SN_WSAETIMEDOUT;
        if (errno != EINTR) return sn_code(errno);
        l_left = l_end - sn_now_ms();
        if (l_left < 0) l_left = 0;
    }
}

static void sn_no_sigpipe(int a_fd)
{
#ifdef SO_NOSIGPIPE
    int l_on = 1;
    setsockopt(a_fd, SOL_SOCKET, SO_NOSIGPIPE, &l_on, sizeof(l_on));
#else
    (void) a_fd;
#endif
}

static void sn_set_blocking(int a_fd, int a_blocking)
{
    int l_flags = fcntl(a_fd, F_GETFL, 0);
    if (l_flags >= 0) {
        fcntl(a_fd, F_SETFL, a_blocking ? (l_flags & ~O_NONBLOCK) : (l_flags | O_NONBLOCK));
    }
}

/* A socket that does not pass to child processes. */
static int sn_socket(int a_family, int a_type, int a_protocol)
{
    int l_fd = socket(a_family, a_type, a_protocol);
    if (l_fd >= 0) {
        fcntl(l_fd, F_SETFD, FD_CLOEXEC);
        sn_no_sigpipe(l_fd);
    }
    return l_fd;
}

static void sn_write_handle(void* a_out, int a_fd)
{
    *(void**) a_out = (void*) (intptr_t) a_fd;
}

/* Connect to `a_host':`a_port', waiting at most `a_timeout_ms' per address.
   On success write the handle and local endpoint into `a_out' and answer 0. */
static int sn_connect(const char* a_host, int a_port, int a_timeout_ms, void* a_out)
{
    struct addrinfo l_hints, *l_found = NULL, *l_address;
    struct sockaddr_in l_local;
    socklen_t l_length;
    char l_port[16];
    char* l_text = ((char*) a_out) + 16;
    int l_fd = -1;
    int l_error = SN_WSAEHOSTUNREACH;
    int l_result, l_so_error;

    memset(&l_hints, 0, sizeof(l_hints));
    l_hints.ai_family = AF_INET;
    l_hints.ai_socktype = SOCK_STREAM;
    l_hints.ai_protocol = IPPROTO_TCP;
    snprintf(l_port, sizeof(l_port), "%d", a_port);
    l_result = getaddrinfo(a_host, l_port, &l_hints, &l_found);
    if (l_result != 0) return sn_lookup_code(l_result);

    for (l_address = l_found; l_address != NULL; l_address = l_address->ai_next) {
        l_fd = sn_socket(l_address->ai_family, l_address->ai_socktype, l_address->ai_protocol);
        if (l_fd < 0) { l_error = sn_code(errno); continue; }
        sn_set_blocking(l_fd, 0);
        l_error = 0;
        if (connect(l_fd, l_address->ai_addr, l_address->ai_addrlen) != 0) {
            if (errno == EINPROGRESS || errno == EINTR) {
                l_error = sn_wait(l_fd, POLLOUT, a_timeout_ms);
                if (l_error == 0) {
                    l_so_error = 0;
                    l_length = sizeof(l_so_error);
                    getsockopt(l_fd, SOL_SOCKET, SO_ERROR, &l_so_error, &l_length);
                    if (l_so_error != 0) l_error = sn_code(l_so_error);
                }
            } else {
                l_error = sn_code(errno);
            }
        }
        if (l_error == 0) {
            sn_set_blocking(l_fd, 1);
            break;
        }
        close(l_fd);
        l_fd = -1;
    }
    freeaddrinfo(l_found);
    if (l_fd < 0) return l_error;

    sn_write_handle(a_out, l_fd);
    l_text[0] = 0;
    *(int*) (((char*) a_out) + 8) = 0;
    l_length = sizeof(l_local);
    if (getsockname(l_fd, (struct sockaddr*) &l_local, &l_length) == 0) {
        inet_ntop(AF_INET, &l_local.sin_addr, l_text, 64);
        *(int*) (((char*) a_out) + 8) = (int) ntohs(l_local.sin_port);
    }
    return 0;
}

/* Bind and listen on `a_host':`a_port'. On success write the handle into
   `a_out' and answer 0. SO_REUSEADDR only lets a new listener past TIME_WAIT,
   which Windows allows anyway; a live listener still gives WSAEADDRINUSE. */
static int sn_listen(const char* a_host, int a_port, int a_backlog, void* a_out)
{
    struct addrinfo l_hints, *l_found = NULL;
    char l_port[16];
    int l_fd, l_result, l_error;
    int l_on = 1;

    memset(&l_hints, 0, sizeof(l_hints));
    l_hints.ai_family = AF_INET;
    l_hints.ai_socktype = SOCK_STREAM;
    l_hints.ai_protocol = IPPROTO_TCP;
    l_hints.ai_flags = AI_PASSIVE;
    snprintf(l_port, sizeof(l_port), "%d", a_port);
    l_result = getaddrinfo(a_host, l_port, &l_hints, &l_found);
    if (l_result != 0) return sn_lookup_code(l_result);

    l_fd = sn_socket(l_found->ai_family, l_found->ai_socktype, l_found->ai_protocol);
    if (l_fd < 0) {
        l_error = sn_code(errno);
        freeaddrinfo(l_found);
        return l_error;
    }
    setsockopt(l_fd, SOL_SOCKET, SO_REUSEADDR, &l_on, sizeof(l_on));
    if (bind(l_fd, l_found->ai_addr, l_found->ai_addrlen) != 0) {
        l_error = sn_code(errno);
        close(l_fd);
        freeaddrinfo(l_found);
        return l_error;
    }
    freeaddrinfo(l_found);
    if (listen(l_fd, a_backlog) != 0) {
        l_error = sn_code(errno);
        close(l_fd);
        return l_error;
    }
    sn_write_handle(a_out, l_fd);
    return 0;
}

/* Wait up to `a_timeout_ms' for a connection on `a_listener' and accept it.
   On success write the handle and peer endpoint into `a_out' and answer 0. */
static int sn_accept(void* a_listener, int a_timeout_ms, void* a_out)
{
    int l_listener = (int) (intptr_t) a_listener;
    struct sockaddr_in l_peer;
    socklen_t l_length = sizeof(l_peer);
    char* l_text = ((char*) a_out) + 16;
    int l_error = sn_wait(l_listener, POLLIN, a_timeout_ms);
    int l_fd;

    if (l_error != 0) return l_error;
    do {
        l_fd = accept(l_listener, (struct sockaddr*) &l_peer, &l_length);
    } while (l_fd < 0 && errno == EINTR);
    if (l_fd < 0) return sn_code(errno);
    fcntl(l_fd, F_SETFD, FD_CLOEXEC);
    sn_set_blocking(l_fd, 1);
    sn_no_sigpipe(l_fd);
    sn_write_handle(a_out, l_fd);
    l_text[0] = 0;
    inet_ntop(AF_INET, &l_peer.sin_addr, l_text, 64);
    *(int*) (((char*) a_out) + 8) = (int) ntohs(l_peer.sin_port);
    return 0;
}

/* Send `a_count' bytes. 0 on success, else the code. Each wait for buffer
   space is bounded by `a_timeout_ms'; MSG_DONTWAIT keeps `send' itself from
   waiting past that when the buffer has room for only part of a chunk. */
static int sn_send_all(void* a_socket, const void* a_buffer, int a_count, int a_timeout_ms)
{
    int l_fd = (int) (intptr_t) a_socket;
    const char* l_next = (const char*) a_buffer;
    int l_left = a_count;
    int l_error, l_chunk;
    ssize_t l_sent;

    while (l_left > 0) {
        l_error = sn_wait(l_fd, POLLOUT, a_timeout_ms);
        if (l_error != 0) return l_error;
        l_chunk = l_left < 65536 ? l_left : 65536;
        l_sent = send(l_fd, l_next, (size_t) l_chunk, MSG_NOSIGNAL | MSG_DONTWAIT);
        if (l_sent < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR) continue;
            return sn_code(errno);
        }
        l_next += l_sent;
        l_left -= (int) l_sent;
    }
    return 0;
}

/* Wait up to `a_timeout_ms' for data, then read up to `a_max' bytes. The count
   read (0: peer closed), or minus the code. */
static int sn_recv(void* a_socket, void* a_buffer, int a_max, int a_timeout_ms)
{
    int l_fd = (int) (intptr_t) a_socket;
    int l_error = sn_wait(l_fd, POLLIN, a_timeout_ms);
    ssize_t l_read;

    if (l_error != 0) return -l_error;
    do {
        l_read = recv(l_fd, a_buffer, (size_t) a_max, 0);
    } while (l_read < 0 && errno == EINTR);
    if (l_read < 0) return -sn_code(errno);
    return (int) l_read;
}

static void sn_shutdown_send(void* a_socket) { shutdown((int) (intptr_t) a_socket, SHUT_WR); }

static void sn_close(void* a_socket) { close((int) (intptr_t) a_socket); }

#endif /* SIMPLE_NET_POSIX_H */
