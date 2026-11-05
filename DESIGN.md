# Design

## Settled

- **The command reports on an existing link; it does not create one.** A single
  command that both links and checks would duplicate `frlink` and could not be
  run on a link created some other way.
- **It takes only the link variable.** `frlink` stores the linkage description
  in the link variable's characteristics — `frlink_fname2` (linked frame),
  `frlink_vl1`/`frlink_vl2` (match variables), `frlink_mtyp`, `frlink_N2`,
  `frlink_sig2`. Nothing needs to be re-specified, and nothing can be
  re-specified inconsistently.
- **Option and keyword vocabulary follows `merge`.** `assert()` takes `master`,
  `using`, `match` with `merge`'s semantics. The point of the package is that
  frame linkage should behave like the merge users already know.
- **The linkage is verified before the linked frame is read.** Verified by test:
  an unguarded implementation reports the right count of unmatched rows and the
  wrong rows, silently. `frlink describe` performs the verification and restores
  match-variable sort order as a side effect. On failure the command refuses to
  report rather than reporting and warning. This resolves what was open
  question 5.
- **The capture frames are named `nomatchmaster()` and `nomatchusing()`, not
  `master()` and `using()`.** `using` is a reserved word in Stata's `syntax`
  parsing, so an option literally named `using()` invites trouble. The longer
  names also read better at a call site, where the reader needs to know which
  side the frame came from.
- **Capture frames hold full records, not just keys.** Copied with the match
  variables ordered first. On the master side the link variable is dropped,
  since a link variable outside its master frame addresses nothing. This
  resolves open question 3.
- **No `gen()` option writing a `_merge`-style variable.** Resolves open
  question 2 as "no". The using-only rows have no home in the current frame, so
  such a variable could only ever hold 1 and 3 — the same partial picture
  `frlink` already gives. Reconsider only if someone wants it for `tabulate`.
- **The table prints before `assert()` fires**, so a failure arrives with the
  numbers that explain it.
- **Matched is reported twice**, once per side, because the counts differ under
  `m:1`.

## Open

1. **`framerge`-created links.** `framerge 1:1` and `m:1` are documented
   aliases of `frlink`, so their link variables should carry the same
   characteristics and work unchanged. Its `1:m` and `m:m` links have no
   `frlink` equivalent and probably encode something different. Untested in
   both cases.
2. **Genuinely stale links.** The guard against a link variable addressing
   rows outside the linked frame is written (in the Mata helper) but not
   exercised by a test. Needs a fixture that adds and deletes observations in
   the linked frame after linking.
3. **Large-data behavior.** The approach is one pass over the master frame's
   link variable plus one allocation the size of the linked frame, so it should
   be linear and cheap. Unmeasured.
4. **Distribution.** No `.pkg` or `stata.toc` yet, deliberately: the syntax
   should settle before anything is installable by URL.
5. **Command name.** `frlinkck` stands. `frlinkchk` and `frlinkreport` were the
   alternatives; `frlink2` is rejected for the reasons in the README.

## Record of a disproved claim

An early draft of this design asserted that the link variable holds the linked
frame's observation number as the frame was ordered when the link was made.
That is wrong, and the first test written to check it was confounded: the test
used `webuse txcounty`, where the match variable happens to equal `_n`, so the
claim could not fail. On a fixture with the linked frame deliberately shuffled,
the claim failed on 27 of 30 observations.

What is true is narrower and more useful: `frlink` *re-sorts the linked frame*
by the match variables, and the link variable is the observation number in that
post-sort order. The distinction is the whole reason step 3 above exists.
