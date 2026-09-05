# Measuring performance in punycoder

How to get a perf number for this package that is worth writing into `NEWS.md`
or an ADR. The wins chased here are usually **1.03–1.4x** — the same order as
the measurement noise if you do not control for it — and a perf claim that lands
in an ADR is permanent, so the protocol below is not optional ceremony.

This note is the method. The hard prerequisite is the clean-rebuild rule in
[AGENTS.md](../AGENTS.md#stale-objects-clean-rebuild-before-you-trust-a-build)
and [ADR-009](../DECISIONS.md): a batched, carefully paired measurement of an
`-O0` build is still meaningless.

## 1. Batch the timings

One `host_normalize()` pass over a 20k-host corpus is only **~16–24 ms** — at
the edge of `system.time()`'s resolution, which quantizes to ~10 ms and reports
a useless `0.0250 / 0.0260` staircase. Time a batch (40 passes) per sample and
divide the batch count back out. That turns ±40% quantization noise into ±1%.

`benchmark_seconds()` in `tests/testthat/test-performance.R` does the same thing
for the same reason: it grows the batch until it clears a 10 ms floor.

## 2. Install both builds side by side; never rebuild between samples

`R CMD INSTALL -l libold .` and `R CMD INSTALL -l libnew .` once each — clean,
identical flags — then alternate `PUNY_LIB=… Rscript bench.R` for as many rounds
as you like.

This supersedes the older "A/B/A in both build orders" routine and is strictly
better. Rebuild order alone moves the numbers: on PUNY-zgaqusnu the same
candidate build measured 18.00 ms then 16.07 ms on successive runs
(thermal / page-cache state), which is larger than some of the wins being
chased. Two library trees remove that confound entirely rather than averaging
over it.

It is not a stylistic preference. On PUNY-mbzhgbta the rebuild loop reported the
change as **flat at every mix** and a real win was nearly written off as noise;
the same two builds measured this way showed **28 of 32 paired comparisons**
favouring the candidate, at 1.03–1.05x.

## 3. Report the paired win count alongside the ratio

The win count is what distinguishes a small real effect from noise — a 1.04x
mean means nothing on its own, "28 of 32 paired comparisons favour the
candidate" means something. PUNY-wfzldcuo reports 16 of 16 the same way.

## 4. Report min, not mean

The minimum sample is the one least polluted by scheduler noise.

## 5. Sweep the input mix

Report the speedup as a curve over the ASCII fraction (0 / 20 / 50 / 100%
non-ASCII), not as one number. That is what proves no input class regressed, and
it localizes where the win actually comes from — on PUNY-mbzhgbta the three-way
sweep is what showed the trie carries the non-ASCII end while the inline bound
carries the ASCII end, so both halves earned their place.

## 6. Do not touch the machine while a benchmark runs

Running `lintr` in another shell during a sweep visibly corrupted one run's
numbers. Background the driver and wait for it.

## 7. Instrument the call mix before optimizing a hot function

**A profiler's self-time share is an upper bound, not a forecast.** On
PUNY-mbzhgbta `canonical_compose` profiled at 5.3% of self time, but a call
trace showed **87%** of its invocations returned at the first bound test — most
of that 5.3% was call overhead that no lookup structure could remove. Cutting
the function 6x end-to-end bought 5%.

A temporary counter plus a static destructor that prints to `stderr` is enough.
It tells you which path to attack, and it often finds a bigger fish elsewhere —
that 87% figure is what moved the bound to the caller in
[ADR-013](../DECISIONS.md#adr-013--composition-is-a-trie-on-the-first-element-and-its-bound-belongs-to-the-caller).

## 8. Mutation-test any test you add to guard an optimization

Break the optimization deliberately and confirm the new test fails.

On PUNY-wfzldcuo the test written to guard the NFC quick check's
combining-class **order** half passed the mutant that deleted that half: the
marks it used were `NFC_QC=Maybe`, so the property test fired first and the
order test was never reached. The test looked right and guarded nothing. See the
same warning in [AGENTS.md](../AGENTS.md) under the Unicode data tables section.

## 9. The correctness gate is separate from the timing

No perf change lands on the strength of its benchmark. The gate is the
element-wise `host_normalize` diff over `unique(c(source, to_ascii))` from every
vendored corpus, across all 8 flag combinations, each corpus normalized at its
own `unicode_version` — see AGENTS.md, "Unicode data tables".

## LTO is not configured on this machine — `--use-LTO` proves nothing here

The local R 4.6.0 framework build has `LTO_OPT =` (empty) in
`$(R RHOME)/etc/Makeconf`, and `R CMD config LTO_OPT` errors with
`no information for variable 'LTO_OPT'`. So `R CMD INSTALL . --use-LTO` passes
**no** `-flto` and silently produces an ordinary build: any "LTO vs non-LTO"
comparison run here is really comparing two identical builds.

`UseLTO: yes` / `--use-LTO` are conditional on R's own toolchain having been
configured with LTO support (Writing R Extensions, "The DESCRIPTION file"). On
this machine it was not.

Before attributing anything to LTO, check `R CMD config LTO_OPT` and grep the
install log for `-flto`. On 2026-07-24 an apparent "5x LTO speedup" was entirely
the `-O0` contamination described in AGENTS.md, measured against a baseline that
had leftover `devtools` objects in `src/`. Testing LTO for real needs a builder
whose R has it configured (e.g. a Linux/GCC CI runner), not this one.
