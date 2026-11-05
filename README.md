# frlinkck

Report `merge`-style match dispositions after Stata's `frlink`, and act on them.

```stata
. frlinkck cty

  Match dispositions for cty (m:1, default -> txcounty)
  ----------------------------------------------------
  master only          default                    3
  using only           txcounty                   5
  matched              default rows              27
                       txcounty rows             15
  ----------------------------------------------------
  total                default                   30
                       txcounty                  20

. frlinkck cty, assert(match) nomatchusing(unused_counties)
```

## The problem

`frlink` creates a persistent link between two frames rather than combining
them, so it never produces a `_merge` variable. What it reports is one line:

```
(3 observations in frame default unmatched)
```

That count covers the current frame only. Nothing reports how many observations
in the *linked* frame were never matched, and nothing stops a do-file when the
match fails. Stata's own documentation concedes the point: after `frlink` you
can see which observations matched in the active frame, but not which ones
failed to match in the frame you linked to.[^rising]

`merge` has handled this since Stata 11. It writes `_merge` (1 = master only,
2 = using only, 3 = matched), prints the three-way table, and accepts
`assert(match)` to halt when the match is imperfect. `frlinkck` restores those
three facilities to frame linkage.

[^rising]: Rising, W. (2019). *Stata 16 frames*. Italian Stata Users Group
    meeting handout. The handout likens the situation to receiving only
    `_merge` values of 1 and 2.

## Usage

```
frlinkck linkvar [, assert(keywords) nomatchmaster(newframe)
                    nomatchusing(newframe) nosummary ]
```

`linkvar` is a link variable `frlink` already created. Nothing else is
specified: the frames, the match variables and the match type are read from the
link variable's characteristics.

| Option                  | Behavior                                                   |
| ----------------------- | ---------------------------------------------------------- |
| `assert(keywords)`      | Exit with code 9 unless every observation falls in one of the dispositions listed. Keywords are `merge`'s: `master`, `using`, `match`. |
| `nomatchmaster(name)`   | New frame holding the current frame's unmatched records     |
| `nomatchusing(name)`    | New frame holding the linked frame's unmatched records       |
| `nosummary`             | Suppress the table; still assert, still store `r()`          |

`matched` is reported twice because under `m:1` the two counts differ: several
current-frame observations can match one linked-frame observation. See
`help frlinkck` for the full description and stored results.

## How it works, and the trap it avoids

`frlink` **sorts the linked frame by the match variables** and records, in the
link variable, the physical observation number of the matched row *in that
order*, missing where nothing matched. So the set of linked-frame rows that were
matched is exactly the set of non-missing link-variable values, and its
complement is the using-only group. One indexed assignment in Mata settles it,
with no helper frames and no second linkage.

The trap is that this correspondence holds only while the linked frame remains
in match-variable order. Re-sort the linked frame and the link variable still
holds the same numbers, but they now address different rows. An implementation
that indexes without checking then reports the **correct count of unmatched
observations and the wrong observations**, silently — on the package's own test
fixture, keys 100–104 instead of 115–119. `frlinkck` verifies the linkage before
reading the linked frame, which also restores the sort order, and refuses to
report if verification fails. `test/certify.do` covers this case directly.

This matters beyond the internals. The recipe circulating on Statalist stamps
`_n` into the linked frame and links it back, which is correct when run
immediately after `frlink` and wrong if anything has re-sorted the linked frame
in between, with no warning either way.

## Structure

```
frlinkck.ado      the command
frlinkck.sthlp    help file
test/certify.do   certification script
DESIGN.md         settled decisions and open questions
```

## Installing

Not yet distributed. For now, point Stata at a clone:

```stata
adopath ++ "/path/to/frlinkck"
```

TODO: add a `.pkg` and `stata.toc` for `net install` once the syntax is settled.

## Testing

```
/Applications/StataNow/StataMP.app/Contents/MacOS/stata-mp -b do test/certify.do
```

Ten tests, all passing as of 2026-11-05. Every expected count is derived by
construction rather than recorded from a previous run. Coverage: counts on a
fresh `m:1` link; that the rows identified are the right rows, not merely the
right number of them; the hostile-sort case above; that no variable is left
behind in either frame; `assert()` acceptance and rejection including bad
keywords; a perfect `1:1` link; a link where nothing matches at all; multiple
match variables; refusal on a variable that is not a link; refusal to overwrite
an existing frame.

Not covered: a linkage genuinely broken by adding or deleting observations in
the linked frame, where the command should refuse rather than report. The guard
is written but untested.

## Prior art

- `frlink`, `frget` — official Stata, the commands this one reports on.
- [`framerge`](https://github.com/qiaowenchen/framerge) (Du & Chen,
  *Stata Journal* 25(2)) — adds `1:m` and `m:m` linkage plus a `get()`
  convenience layer, and is faster than `merge` on large data. It stores only
  `r(unmatched)`, which is the count `frlink` itself already returns, and offers
  no using-frame count, no disposition table and no assert. Complementary rather
  than overlapping: `framerge 1:1` and `m:1` are aliases of `frlink`, so
  `frlinkck` should work on the links they create, though this is untested.

The name `frlink2` was considered and rejected: it was `framerge`'s development
name, it survives in that package's help file section markers, and it implies a
replacement for `frlink` rather than a check on one.
