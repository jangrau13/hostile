# Is this replica healthy? (example assignment)

Something else probes each replica and hands you the results. You decide
whether the replica should still be taking traffic: **no more than
`failures_allowed` failures in the last `window` probes.**

Your problem is `checker.rs`, and two methods in it.

## What to do

1. **`record(ok)`** — take the outcome of one probe.
2. **`healthy()`** — true if the replica should still be taking traffic.

## What you are marked on

Whether you can explain it in a viva. The examiner can compile and run your
checker against cases you have not seen, so predictions get checked.
