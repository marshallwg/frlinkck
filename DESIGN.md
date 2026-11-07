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
  question about verification.
- **The capture frames are named `nomatchmaster()` and `nomatchusing()`, not
  `master()` and `using()`.** `using` is a reserved word in Stata's `syntax`
  parsing, so an option literally named `using()` invites trouble. The longer
  names also read better at a call site, where the reader needs to know which
  side the frame came from.
- **Capture frames hold full records, not just keys.** Copied with the match
  variables ordered first. On the master side the link variable is dropped,
  since a link variable outside its master frame addresses nothing. This
  resolves the question of what the capture frames should hold.
- **No `gen()` option writing a `_merge`-style variable.** Resolved as "no". The using-only rows have no home in the current frame, so
  such a variable could only ever hold 1 and 3 — the same partial picture
  `frlink` already gives. Reconsider only if someone wants it for `tabulate`.
- **The table prints and `r()` is stored before `assert()` fires**, so a
  failure arrives with the numbers that explain it and a caller using `capture`
  can still read the counts. Verified by test: the returns are discarded if
  they are set after the `exit`.
- **`assert()` abbreviations are enumerated, not computed.** `merge` accepts
  `mat`, `mas` and `us` and rejects `ma` as ambiguous between `match` and
  `master`. An earlier draft computed a two-character minimum, which accepted
  `ma` and set the match *and* master flags from one ambiguous word — silently
  permitting a disposition the user had not asked for.
- **Matched is reported twice**, once per side, because the counts differ under
  `m:1`.
- **`assert()` means "assert the match", not "assert that records were
  removed".** Confirmed with the author on 2026-11-05; an earlier phrasing of
  the requirement said "removed" and was ambiguous.
- **No bounds check in the Mata helper.** One was written and then removed.
  Verification of the linkage already guarantees that every link value
  addresses a row inside the linked frame, so the check was a branch no test
  could exercise and therefore a branch nothing could trust.
- **The linked frame's match variables are read from `frlink_vl2p`, not
  `frlink_vl2`.** `frlink` writes `frlink_vl2` only when the user restates the
  match variables inside `frame()` — `frame(txcounty countyid)`. Written the
  shorter and more common way, `frame(txcounty)`, `frlink_vl2` is empty and
  only `frlink_vl2p` carries the resolved names; `framerge` writes `vl2p` and
  never `vl2`. Reading `vl2` left the varlist empty, so `order` ran with no
  arguments and every call with `nomatchmaster()` or `nomatchusing()` failed
  with `r(100) varlist required` — on a link written exactly as the help file's
  own example writes it. `r(matchvars_using)` was returning empty for the same
  reason. Found 2026-11-06. No fallback to `vl2` is kept: a test showed
  `frlink describe` itself fails when `vl2p` is empty, so verification refuses
  before the varlist is ever used, and the fallback would have been a branch
  nothing could reach. Tests 15-17 and 28.

- **Distributed by `net install` from the GitHub repository**, with
  `frlinkck.pkg` and `stata.toc` at the repository root, following the layout
  of the author's other ado packages. Verified by installing from a local clone
  into a scratch ado directory and running the installed copy with the source
  tree off the path.

## Open

1. **`framerge 1:m` and `m:m` links.** Untestable rather than untested: both
   paths fail inside `framerge` itself with "command confirm_var_cnt is
   unrecognized". That helper ships in neither the Stata Journal distribution
   (sj25-2/dm0115) nor the GitHub repository. Revisit if it is ever fixed.
2. **Stata 16 compatibility.** The ado declares `version 16` and uses only
   features of that release as far as I can tell, but it has been run on 19.5
   only. Unverified.
3. **Command name.** `frlinkck` stands. `frlinkchk` and `frlinkreport` were the
   alternatives; `frlink2` is rejected for the reasons in the README.

## Verified against framerge

`framerge m:1` and `framerge 1:1` write link variables carrying the same
`frlink_*` characteristics as `frlink`, and `frlinkck` reports on them with no
change. Measured on the same fixture, `framerge m:1` gave the identical
3 / 5 / 27 / 15 split. Confirmed with framerge installed from
sj25-2/dm0115 into a scratch ado directory on 2026-11-05, and re-confirmed in
the certification script on 2026-11-06.

The 2026-11-05 check exercised only the counts. Because `framerge` writes
`frlink_vl2p` and never `frlink_vl2`, the capture frames were in fact broken on
every `framerge` link at that date, and the check did not reach them. Test 28
now covers them. Note that `framerge`'s option is `linkvar()`, not
`generate()`.

## Measured performance

One pass over the master frame's link variable plus one allocation the size of
the linked frame. Master-to-using ratio 5:1, 10% of master rows matching
nothing, on this machine:

| master rows | using rows | `frlink` | `frlinkck` |
| ----------- | ---------- | -------- | ---------- |
| 100,000     | 20,000     | 0.08s    | 0.01s      |
| 1,000,000   | 200,000    | 0.54s    | 0.02s      |
| 5,000,000   | 1,000,000  | 3.47s    | 0.11s      |

Linear in the master frame, and 2-3% of the cost of creating the linkage in the
first place. There is no performance reason to make the check optional.

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
