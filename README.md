# frlinkck

Report `merge`-style match dispositions after Stata's `frlink`, and act on them.

## The problem

`frlink` creates a persistent link between two frames rather than combining
them, so it never produces a `_merge` variable. What it reports is one line:

```
(3 observations in frame visits unmatched)
```

That count covers the current frame only. Nothing tells you how many
observations in the *linked* frame were never matched, and nothing lets you stop
a do-file when the match fails. Stata's own documentation concedes the point:
after `frlink` you can see which observations matched in the active frame, but
not which ones failed to match in the frame you linked to.[^rising]

`merge` has handled this since Stata 11. It writes `_merge` (1 = master only,
2 = using only, 3 = matched), prints the three-way table, and accepts
`assert(match)` to halt when the match is imperfect. `frlinkck` restores those
three facilities to frame linkage.

[^rising]: Rising, W. (2019). *Stata 16 frames*. Italian Stata Users Group
    meeting handout. The handout likens the situation to receiving only
    `_merge` values of 1 and 2.

## What it does

Run `frlinkck` on an existing link variable. It reports:

| Disposition      | `merge` equivalent | Definition                                             |
| ---------------- | ------------------ | ------------------------------------------------------ |
| master only      | `_merge == 1`      | Current-frame rows whose link variable is missing      |
| using only       | `_merge == 2`      | Linked-frame rows no current-frame row points to        |
| matched          | `_merge == 3`      | Current-frame rows with a non-missing link variable    |

Note that "matched" counts current-frame rows, not pairs: under `m:1` several
master rows can point at one using row, so the matched count and the number of
matched using rows differ. The report gives both.

Planned facilities beyond the report:

- **Assert.** Fail the do-file when the observed dispositions do not match what
  you claimed, following `merge`'s `assert()` rather than inventing a new
  vocabulary.
- **Capture.** Write the unmatched rows from either side into a new frame, so
  you can inspect the records that failed instead of only counting them.

Syntax and option names are not settled. See `DESIGN.md`.

## Approach

The link variable is the whole input. Nothing needs to be re-specified, because
`frlink` has already resolved the match and recorded the result.

The master side is a counting problem: missing link variable means master only.
The using side needs the set of linked-frame rows that were actually hit. Two
routes:

1. **Public API.** Put a row number in the linked frame (`gen long _row = _n`),
   `frget` it back through the link, and the non-missing values are exactly the
   using rows that matched. Link that set back to the using frame; whatever
   fails to link is using-only. Uses only documented commands.
2. **Direct read.** `frlink`'s link variable appears to hold the linked-frame
   observation number outright, which would let Mata mark the hit rows in one
   indexed assignment. Faster and shorter, but it depends on an internal
   representation Stata does not document and could change. **Unverified** —
   needs a test against several link types before anything relies on it.

Route 1 is the default. Route 2 is an optimization to be adopted only if a test
confirms the representation.

## Structure

Nothing is implemented yet. Intended layout:

```
frlinkck.ado      the command
frlinkck.sthlp    help file
test/             certification script, run before every release
DESIGN.md         open design questions and settled decisions
```

## Installing

TODO: not yet distributed. Add the `net install` line once there is a release.

## Testing

TODO: write `test/certify.do`, covering at minimum 1:1 and m:1 links, a link
with no unmatched rows on either side, a link with unmatched rows on both,
and an empty using frame.

## Prior art

- `frlink`, `frget` — official Stata, the commands this one reports on.
- [`framerge`](https://github.com/qiaowenchen/framerge) (Du & Chen) — adds `1:m`
  and `m:m` linkage plus a `get()` convenience layer, and is faster than `merge`
  on large data. It stores only `r(unmatched)`, the count of unmatched
  current-frame rows, and offers no using-frame count, no disposition table, and
  no assert. Complementary rather than overlapping; `frlinkck` should be made to
  work on links `framerge` creates, since `framerge 1:1` and `m:1` are aliases
  of `frlink`.
