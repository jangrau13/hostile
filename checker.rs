//! Deciding whether a replica is healthy from the last few probe results.
//!
//! The probing is settled: something else calls `record` with each result and
//! `healthy` when it needs an answer. The decision is what those two do.

pub struct Checker {
    pub window: usize,
    pub failures_allowed: usize,
    results: Vec<bool>,
}

impl Checker {
    pub fn new(window: usize, failures_allowed: usize) -> Self {
        Checker { window, failures_allowed, results: Vec::new() }
    }

    /// Record the outcome of one probe.
    pub fn record(&mut self, _ok: bool) {
        unimplemented!()
    }

    /// True if the replica should still be taking traffic.
    pub fn healthy(&self) -> bool {
        unimplemented!()
    }
}
