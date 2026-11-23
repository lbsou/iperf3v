/*
 * iperf, Copyright (c) 2014, The Regents of the University of
 * California, through Lawrence Berkeley National Laboratory (subject
 * to receipt of any required approvals from the U.S. Dept. of
 * Energy).  All rights reserved.
 *
 * If you have questions about your rights to use or distribute this
 * software, please contact Berkeley Lab's Technology Transfer
 * Department at TTD@lbl.gov.
 *
 * NOTICE.  This software is owned by the U.S. Department of Energy.
 * As such, the U.S. Government has been granted for itself and others
 * acting on its behalf a paid-up, nonexclusive, irrevocable,
 * worldwide license in the Software to reproduce, prepare derivative
 * works, and perform publicly and display publicly.  Beginning five
 * (5) years after the date permission to assert copyright is obtained
 * from the U.S. Department of Energy, and subject to any subsequent
 * five (5) year renewals, the U.S. Government is granted for itself
 * and others acting on its behalf a paid-up, nonexclusive,
 * irrevocable, worldwide license in the Software to reproduce,
 * prepare derivative works, distribute copies to the public, perform
 * publicly and display publicly, and to permit others to do so.
 *
 * This code is distributed under a BSD style license, see the LICENSE
 * file for complete information.
 */
#ifndef __IPERF_UDP_H
#define __IPERF_UDP_H


/**
 * iperf_udp_recv -- receives the client data for UDP
 *
 *returns state of packet received
 *
 */
int iperf_udp_recv(struct iperf_stream *);

/**
 * iperf_udp_send -- sends the client data for UDP
 *
 * returns: bytes sent
 *
 */
int iperf_udp_send(struct iperf_stream *) /* __attribute__((hot)) */;


/**
 * iperf_udp_accept -- accepts a new UDP connection
 * on udp_listener_socket
 *returns 0 on success
 *
 */
int iperf_udp_accept(struct iperf_test *);


int iperf_udp_listen(struct iperf_test *);

int iperf_udp_connect(struct iperf_test *);

int iperf_udp_init(struct iperf_test *);

/**
 * iperf_udp_handle_ctrl_dgram -- recognize a UDP connect message or reply
 * received on a stream socket (a repeated connect message, or a late reply).
 * On the server, a connect message is answered again on socket s.
 *
 * returns 1 if buf is such a control datagram, 0 if not, -1 on error
 */
int iperf_udp_handle_ctrl_dgram(struct iperf_test *test, int s, const void *buf, int len);

/**
 * iperf_udp_poll_accepted_streams -- while the server still creates streams,
 * read the streams already accepted that select() marked readable in read_set
 * and answer a connect message repeated by a client whose reply was lost.
 *
 * returns 0 on success, -1 on error
 */
int iperf_udp_poll_accepted_streams(struct iperf_test *test, fd_set *read_set);

/*
 * Windows/Cygwin server: Windows hands every UDP datagram to the first socket
 * bound to the port, so one shared socket receives the datagrams of every
 * stream and iperf3v dispatches them by sender address (see iperf_udp_accept).
 */
#if defined(__CYGWIN__) || defined(_WIN32)
#define IPERF_UDP_SHARED_RCV 1
#endif

/**
 * iperf_udp_listener_repeat -- with a shared receive socket, a connect message
 * repeated by a client already accepted reaches the listener: answer it on the
 * stream's socket instead of accepting a new stream.
 *
 * returns 1 if the pending datagram was such a message (consumed), 0 otherwise
 */
int iperf_udp_listener_repeat(struct iperf_test *test);


#endif
