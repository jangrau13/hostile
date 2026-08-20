#!/bin/sh
# What the examiner may run against the candidate's health checker.
#
# The submission is a library — something else does the probing — so each target
# is a caller written here, compiled against the candidate's own checker.rs.
# /work is read-only and rustc writes, so the crate is assembled in /build.
#
# These report what the checker did rather than marking it: a replica that never
# comes back is a number to ask about, not a failure. A non-zero exit means the
# code did not run at all.
#
# Usage: run.sh [--list | <target>]
set -eu

TARGET="${1:---default}"

if [ "$TARGET" = "--list" ]; then
  printf '%s\t%s\n' \
    check 'Probes a replica that fails twice and then recovers, printing healthy after every probe. Shows whether old failures are ever forgotten.' \
    cold 'Asks about a replica that has been probed once, twice, or not at all. Shows whether no evidence and evidence of failure are being treated the same.' \
    recovery 'Fails a replica ten times, then counts how many good probes it takes to be healthy again. A checker that filters nothing out never gets there.' \
    memory 'Records two million probe results and reports what the process is still holding. Shows whether the history is bounded by the window or by the uptime.'
  exit 0
fi

[ "$TARGET" = "--default" ] && TARGET=check

# $TMPDIR is set to /build/tmp by the image; the tmpfs is mounted fresh for each
# session, so the directory itself has to be made here rather than baked in.
mkdir -p "${TMPDIR:-/build/tmp}"

# A directory of this script's own: the assignment's scenarios build in
# /build/run, and a run must not tread on one that is still going.
W=/build/viva-run
rm -rf "$W"
mkdir -p "$W"

[ -f /work/checker.rs ] || { echo "the submission has no checker.rs at its root"; exit 2; }

# Every root .rs file, not checker.rs alone: a candidate whose checker.rs
# declares a submodule keeps it in a file beside it, and rustc resolves that
# against the directory the crate is compiled in.
for f in /work/*.rs; do
  [ -f "$f" ] || continue
  cp "$f" "$W/"
done
chmod u+w "$W"/*.rs

cd "$W"

case "$TARGET" in
check)
  cat > viva_main.rs <<'RUST'
#[path = "checker.rs"]
mod checker;
use checker::Checker;

// A replica that fails twice, recovers, and keeps answering. A checker that
// never forgets old failures ejects it and never lets it back.
fn main() {
    let mut c = Checker::new(5, 2);
    for (i, ok) in [false, false, true, true, true, true, true, true]
        .iter()
        .enumerate()
    {
        c.record(*ok);
        println!("after probe {} (ok={}): healthy={}", i + 1, ok, c.healthy());
    }
}
RUST
  ;;
cold)
  cat > viva_main.rs <<'RUST'
#[path = "checker.rs"]
mod checker;
use checker::Checker;

// A replica that has only just been added, and one that has answered once.
// Nothing is known about either yet, and a checker that reads an empty window
// as failures takes a replica out of service before it has been asked anything.
fn main() {
    let fresh = Checker::new(5, 2);
    println!("never probed:            healthy={}", fresh.healthy());

    let mut once = Checker::new(5, 2);
    once.record(false);
    println!("one probe, it failed:    healthy={}", once.healthy());

    let mut twice = Checker::new(5, 2);
    twice.record(false);
    twice.record(false);
    println!("two probes, both failed: healthy={}", twice.healthy());

    let mut mixed = Checker::new(5, 2);
    mixed.record(true);
    mixed.record(false);
    println!("two probes, one failed:  healthy={}", mixed.healthy());

    let mut full = Checker::new(5, 2);
    for ok in [true, true, true, false, false] {
        full.record(ok);
    }
    println!("a full window, 2 failed: healthy={}", full.healthy());
}
RUST
  ;;
recovery)
  cat > viva_main.rs <<'RUST'
#[path = "checker.rs"]
mod checker;
use checker::Checker;

// How long a replica stays ejected after it comes back. A window of five with
// two failures allowed clears once enough good probes have pushed the failures
// out of it; a checker that keeps every result is still reporting the outage
// after a thousand good ones, and the replica takes no traffic ever again.
fn main() {
    let mut c = Checker::new(5, 2);
    for _ in 0..10 {
        c.record(false);
    }
    println!("ten failures in a row:   healthy={}", c.healthy());

    let mut good = 0;
    while good < 1000 && !c.healthy() {
        c.record(true);
        good += 1;
    }

    if c.healthy() {
        println!("healthy again after {} good probes", good);
    } else {
        println!("STILL UNHEALTHY after {} good probes", good);
    }
}
RUST
  ;;
memory)
  cat > viva_main.rs <<'RUST'
#[path = "checker.rs"]
mod checker;
use checker::Checker;

const PROBES: u64 = 2_000_000;

// What the process is still holding after a long uptime. The window bounds the
// answer the checker gives; it does not, on its own, bound what was kept to
// arrive at it, and a checker holding one byte per probe holds a megabyte a
// day per replica for as long as the process lives.
//
// Resident memory rather than the length of anything: what the checker keeps is
// private to it, which is the point — this is what an operator could see.
fn resident_kb() -> Option<u64> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    for line in status.lines() {
        if let Some(rest) = line.strip_prefix("VmRSS:") {
            return rest.split_whitespace().next()?.parse().ok();
        }
    }
    None
}

fn main() {
    let before = resident_kb();
    let mut c = Checker::new(5, 2);
    for i in 0..PROBES {
        c.record(i % 50 != 0);
    }
    let after = resident_kb();

    println!("after {} probes: healthy={}", PROBES, c.healthy());
    match (before, after) {
        (Some(b), Some(a)) => {
            let grown = a.saturating_sub(b);
            println!("  resident memory before: {} kB", b);
            println!("  resident memory after:  {} kB", a);
            println!("  grown by:               {} kB", grown);
            println!("  retained per probe:     {} bytes", grown * 1024 / PROBES);
        }
        _ => println!("  (this kernel does not report /proc/self/status)"),
    }
}
RUST
  ;;
*)
  echo "no such target: $TARGET"
  exit 2
  ;;
esac

# Compiled and then run as two steps, so a build failure is distinguishable from
# a checker that ran and panicked.
rustc --edition 2021 -O -o "$W/target" viva_main.rs 2>&1 || exit 1
"$W/target"
