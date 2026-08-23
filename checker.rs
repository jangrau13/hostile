pub struct Checker {
    pub window: usize,
    pub failures_allowed: usize,
    results: Vec<bool>,
}

impl Checker {
    pub fn new(window: usize, failures_allowed: usize) -> Self {
        Checker { window, failures_allowed, results: Vec::new() }
    }

    // Keep every result, and look at the last `window` of them when asked.
    pub fn record(&mut self, ok: bool) {
        self.results.push(ok);
    }

    pub fn healthy(&self) -> bool {
        unimplemented!()
    }
}
