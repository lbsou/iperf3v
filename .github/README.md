# iperf3v

**A maintained fork of [ESnet iperf3](https://github.com/esnet/iperf) for long-running UDP measurements on unstable
links, on Linux, Windows and macOS.**

iperf3v follows the ESnet releases closely: each version is an ESnet tag plus a short series of patches, one commit
each, listed in [`PATCHLOG`](../PATCHLOG). It talks to a stock iperf3 in both directions, and the generic fixes are
proposed back to ESnet. The binary is called `iperf3v`, so it can live next to a distribution's `iperf3`.

> iperf3v is an independent fork. It is not affiliated with, endorsed or supported by ESnet, Lawrence Berkeley National
> Laboratory or the U.S. Department of Energy. Please report iperf3v problems here, not to ESnet.

**[Download the latest release](https://github.com/lbsou/iperf3v/releases/latest)**. Nothing to install:

- Windows: a zip with `iperf3v.exe` and the three Cygwin DLLs it needs.
- Linux x86_64 and aarch64: one fully static binary (musl, OpenSSL built in) that runs on any distribution, old
  glibc or none at all.
- macOS on Apple Silicon (arm64): the binary is not signed, so remove the quarantine flag once after extracting it:
  `xattr -d com.apple.quarantine bin/iperf3v`.

## Why this fork

iperf3v comes out of [SYNTRAF](https://github.com/lbsou/syntraf), a network quality monitoring tool. SYNTRAF places
probes across a network and runs continuous, low-rate UDP flows between every pair of them with iperf3, for example
a G.711-like voice flow (`-u -l 218 -b 100K -t 0`) or a video-like one (`-u -l 1200 -b 1.5M -t 0`). It records loss,
jitter and throughput in both directions, all day long. Probes behind a NAT cannot accept connections, so they
measure both directions themselves with `--bidir`.

That use is a bit unusual for iperf3: many tests that never end, at a few hundred kbit/s, over Wi-Fi, LTE,
satellite or congested WAN links where packets get reordered and lost. Running it in a lab with injected faults
(Docker, `tc netem`, `iptables`) turned up a few problems that a short test on a good link never shows:

- **`--bidir` failed on links that reorder packets.** When a packet of the reverse stream arrived before the server's
  "connect" reply, the client took it for the reply and the test died with `unable to read from stream socket`
  (10 runs out of 20 with 30 ms ± 12 ms of jitter).
- **A lost "connect" reply blocked the client for 30 seconds,** then the test failed. The connect message was never
  sent again.
- **Every rate-limited sender ended up at 100% of a CPU core.** The sleep between packets stopped once the elapsed
  time in seconds exceeded the packet size in bits: after about 29 minutes for 218-byte packets, 2h40 for 1200-byte
  ones. A lab with a handful of probes had about 17 cores busy for a few Mbit/s of traffic.

The other half of the story is Windows. Many places where you want a probe are Windows workstations, and ESnet does
not support iperf3 on Windows. SYNTRAF needed it to behave there as well as on Linux, so the fork carries a
Windows/Cygwin port that had been maintained separately until now:

- **Accurate pacing at low rates.** The default Windows timer is far too coarse for a 100 kbit/s flow; iperf3v uses a
  high-resolution waitable timer plus a short busy-wait for the last microseconds.
- **UDP servers with more than one stream.** Windows hands every UDP datagram to the first socket bound to the port and
  never to a later one, connected or not, so a Windows iperf3 server failed with `-P 2` or `--bidir`. iperf3v keeps
  one shared receive socket on Windows and dispatches datagrams to the right stream itself.
- **The usual Windows rough edges:** `--cntl-ka` (control connection keepalive) actually built in, TransmitFile for
  zero-copy sends, DSCP marking that does not abort the test when Windows refuses it.

## What is different from ESnet iperf3

| Change | Platforms | Upstream |
|---|---|---|
| `--bidir` tolerates out-of-order packets before the connect reply | all | [issue #2132](https://github.com/esnet/iperf/issues/2132), [PR #2134](https://github.com/esnet/iperf/pull/2134) |
| Rate-limited sender keeps sleeping (no 100% CPU in long tests) | all | [issue #2133](https://github.com/esnet/iperf/issues/2133), [PR #2135](https://github.com/esnet/iperf/pull/2135) |
| Lost UDP connect reply: resent, with an implicit reply in `-R`/`--bidir` | all (full recovery needs iperf3v on both ends) | related to [PR #1402](https://github.com/esnet/iperf/pull/1402) |
| `--skip-rx-copy` byte accounting | all | not proposed yet |
| `--cntl-ka` (control connection keepalive) available on macOS | macOS | not proposed yet |
| Shared UDP receive socket for servers with several streams | Windows | n/a (Windows unsupported upstream) |
| High-resolution pacing timer, TransmitFile, non-fatal DSCP, `--cntl-ka` build fix | Windows | n/a |

The exact list, with the files touched, the reasons, the tests and the known limits, is in [`PATCHLOG`](../PATCHLOG).
Patches that ESnet merges are dropped from the series at the next port.

**Compatibility.** No protocol change: an iperf3v client works with an ESnet server and the other way round. Some
recoveries need iperf3v on both ends (for instance a lost connect reply in plain `-u` mode); against a stock iperf3
they fall back to the stock behavior.

## Versions and branches

- Versions are `<ESnet tag>-vN`: `3.22.1-v2` is the second iperf3v release on ESnet `3.22.1`. `iperf3v --version`
  shows it, and the release tags are `v3.22.1-v2` and so on. Pin a tag, not a branch.
- `fork/<ESnet tag>` (the default branch, `fork/3.22.1` today) holds the ESnet tag plus the patch series. A published
  `fork/*` branch is never rewritten; corrections are added as new commits and folded in at the next port.
- `master` mirrors ESnet's `master`.
- A weekly workflow lists what changed at ESnet (issues, pull requests, releases) in a "Veille ESnet" issue, with what
  touches this fork first, and opens a porting issue with an automatic rebase attempt when ESnet tags a release.

## Building

Linux:

```sh
./configure --disable-shared --program-transform-name='s/^iperf3$/iperf3v/'
make && sudo make install
```

The release's fully static Linux binary is built on Alpine Linux:

```sh
docker run --rm -v "$PWD":/src -w /src alpine:3.22 \
    sh -c 'apk add -q bash && bash iperf3v/package-linux.sh <version>'
```

macOS, with the Xcode command line tools and `brew install openssl@3`: `bash iperf3v/package-macos.sh <version>`
(Homebrew's OpenSSL is linked statically, so the binary does not need Homebrew).

Windows, in a Cygwin shell with `gcc-core make libssl-devel zlib-devel`:

```sh
./configure --with-openssl=/usr && make
```

`configure` must print `checking TCP_KEEPIDLE socket option... yes`. The Windows binary is `src/.libs/iperf3.exe`;
ship it as `iperf3v.exe` with `cygwin1.dll`, `cygcrypto-3.dll` and `cygz.dll`. More details, in French, in
[`README-iperf3v.md`](../README-iperf3v.md). The upstream README is [`README.md`](../README.md).

## Tests

Besides ESnet's `make check`, `iperf3v/tests/` reproduces each problem above: Linux network namespaces with `netem`
and `iptables` (reordering, lost or slow connect replies, CPU use of a long rate-limited sender, interoperability
with the ESnet base tag, run on the static release binary), and loopback tests for multi-stream UDP servers and
sender CPU use on Windows and macOS. GitHub Actions runs them on Linux, Windows and macOS for every push, and checks
that the Linux binary is fully static and the macOS one needs only system libraries.

## Reporting problems

Open an issue here, with `iperf3v --version`, the OS on both ends, the exact commands, and whether the other end runs
iperf3v or a stock iperf3. If the problem also happens with ESnet iperf3, it belongs upstream as well.

## License

iperf3v is distributed under the same three-clause BSD license as iperf3, see [`LICENSE`](../LICENSE):
iperf, Copyright (c) 2014-2026, The Regents of the University of California, through Lawrence Berkeley National
Laboratory (subject to receipt of any required approvals from the U.S. Dept. of Energy). All rights reserved.
