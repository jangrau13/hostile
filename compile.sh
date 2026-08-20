#!/bin/sh
# Does the submission build?
#
# This is the gate that decides whether the examiner may propose a patch at
# all, so the exit code has to be rustc's and nothing else's: a check stricter
# than the compiler refuses patches that are fine, and a looser one lets a
# patch through to fail inside a run, where the examiner cannot tell its own
# edit from the candidate's code.
#
# rustc and not cargo, for the reason the image ships neither crates nor a
# registry: there is no network at exam time and the assignment is standard
# library only.
set -eu

mkdir -p "${TMPDIR:-/build/tmp}"
W=/build/viva-compile
rm -rf "$W"
mkdir -p "$W"

[ -f /work/checker.rs ] || { echo "the submission has no checker.rs at its root"; exit 2; }

cd "$W"
# The submission is read where it lies and everything rustc emits lands in
# /build. Naming the crate root by its own path is also what lets a checker.rs
# that declares submodules find them: rustc resolves `mod` against the
# directory of the file that declares it.
#
# As a library, because that is what the submission is: there is no main here,
# and a crate type that demanded one would report the assignment's own shape as
# a compile error.
rustc --edition 2021 --crate-type lib --out-dir "$W" /work/checker.rs 2>&1
