# Design

Open questions first, settled decisions after. Nothing here is implemented.

## Proposed syntax

```
frlinkck linkvar [, assert(keywords) master(newframe) using(newframe)
                    nosummary nolabel ]
```

The command takes the name of a link variable that `frlink` already created.
It does not take match variables or a frame name, because the link variable
already carries both.

| Option            | Behavior                                                           |
| ----------------- | ------------------------------------------------------------------ |
| `assert()`        | Error and exit if observed dispositions are not those claimed      |
| `master(name)`    | Create frame `name` holding current-frame rows that did not match  |
| `using(name)`     | Create frame `name` holding linked-frame rows that did not match   |
| `nosummary`       | Suppress the table; still store `r()` results and still assert     |

`assert()` takes `merge`'s keywords, not new ones: `match`, `master`,
`using`, and the combinations `match master`, `match using`. The semantics are
`merge`'s — the specified keywords are the only dispositions permitted, and any
observation falling outside them is an error.

Returned in `r()`: `r(N_master)`, `r(N_using)`, `r(N_match)`,
`r(N_match_using)` (matched rows counted on the using side, which differs from
`r(N_match)` under `m:1`), `r(N_total_master)`, `r(N_total_using)`.

## Open questions

1. **Command name.** `frlinkck` is current. `frlink2` is rejected: it was
   `framerge`'s development name, it survives in that package's help file
   section markers, and it implies a replacement for `frlink` rather than a
   check on one. Alternatives if `frlinkck` reads poorly: `frlinkchk`,
   `frlinkreport`.
2. **Does it write a variable?** `merge` leaves `_merge` behind. Should
   `frlinkck` offer `gen(newvar)` writing 1/2/3 into the current frame? The
   using-only rows have no home in the current frame, so a current-frame
   variable can only ever hold 1 and 3 — which is the same partial picture
   `frlink` already gives, and arguably not worth the name collision risk.
   Leaning no.
3. **Capture frames: rows or keys?** Should `master()` and `using()` hold the
   full unmatched records, or only the match variables plus a row number? Full
   records are more useful for inspection and cost memory. Leaning full
   records, with the match variables ordered first.
4. **`m:m` and `1:m` links.** `framerge` supports these; `frlink` does not.
   Whether `frlinkck` handles a `framerge`-created `1:m` link depends on
   whether that link variable has the same structure. Not investigated.
5. **Behavior on a stale link.** `frlink` links can go out of date when either
   frame changes, which is what `frlink rebuild` is for. Should `frlinkck`
   refuse to report on a link it believes is stale, or report and warn?
   Leaning refuse, since a disposition table from a stale link is worse than
   no table.

## Settled

- The command reports on an existing link. It does not create one. A single
  command that both links and checks would duplicate `frlink` and would make
  the check impossible to run on a link created some other way.
- Option and keyword vocabulary follows `merge` wherever `merge` has a
  precedent. The point of the package is to make frame linkage behave like the
  merge users already know.
