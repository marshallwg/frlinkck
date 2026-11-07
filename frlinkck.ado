*! version 0.1.1  06nov2026  Marshall Garland
*! frlinkck: merge-style match dispositions after frlink

* =============================================================================
* frlinkck reports, for an existing frlink linkage, the three dispositions that
* -merge- reports and -frlink- does not: master only, using only, and matched.
* It can halt the do-file when the dispositions are not the ones claimed, and
* it can put the unmatched records from either side into a new frame.
*
* HOW IT WORKS.  frlink sorts the using frame by the match variables and stores,
* in the link variable, the resulting physical observation number of the matched
* row -- missing where no row matched.  So the master side is a counting problem
* (missing link variable means master only), and the using side is an indexing
* problem: the set of using rows that some master row points at is exactly the
* set of non-missing link-variable values.
*
* THE TRAP.  That correspondence holds only while the using frame remains in
* match-variable order.  Re-sort the using frame and the link variable still
* contains the same numbers, but they now address the wrong rows -- yielding the
* right COUNT of unmatched rows and the wrong rows, silently.  Every path
* through this command therefore verifies the linkage first, which restores the
* sort order, before touching the using frame.
* =============================================================================

program define frlinkck, rclass
    version 16

    syntax varname(numeric) [, ///
        ASSERT(string)         ///
        NOMATCHMaster(name)    ///
        NOMATCHUsing(name)     ///
        NOSUMmary              ///
        ]

    local lnk `varlist'

    * -------------------------------------------------------------------------
    * 1. Confirm the variable is an frlink link variable, and read the linkage
    *    description out of its characteristics.  frlink records the frames, the
    *    match variables and the match type there, so the user need not repeat
    *    any of it.
    * -------------------------------------------------------------------------
    local ver : char `lnk'[frlink_ver]
    if "`ver'" == "" {
        display as error ///
            "{bf:`lnk'} is not a link variable created by {bf:frlink}"
        exit 198
    }
    if real("`ver'") > 1 {
        display as error ///
            "{bf:`lnk'} uses link format version `ver', which this version of " ///
            "{bf:frlinkck} does not understand; update {bf:frlinkck}"
        exit 198
    }

    local frame2 : char `lnk'[frlink_fname2]
    local mtype  : char `lnk'[frlink_mtyp]
    local mvars1 : char `lnk'[frlink_vl1]
    local frame1 = c(frame)

    * frlink records the linked frame's match variables in TWO characteristics,
    * and the obvious one is not the reliable one.  frlink_vl2 holds them only
    * when the user restated them inside frame() -- "frame(txcounty countyid)".
    * Written the shorter and more common way, "frame(txcounty)", frlink_vl2 is
    * EMPTY and only frlink_vl2p holds the names frlink resolved.  framerge
    * writes vl2p and never vl2.  So vl2p is the one to read, with no fallback:
    * -frlink describe- in step 3 itself fails when vl2p is empty, so no linkage
    * that survives verification can reach this point without it.
    local mvars2 : char `lnk'[frlink_vl2p]

    * -------------------------------------------------------------------------
    * 2. Validate assert() before doing any work, so a typo costs nothing.
    *    The keywords are -merge-'s, deliberately: the point of this command is
    *    that frame linkage should behave like the merge users already know.
    * -------------------------------------------------------------------------
    local a_master 0
    local a_using  0
    local a_match  0
    if "`assert'" != "" {
        foreach kw of local assert {
            * The permitted abbreviations are merge's own, enumerated rather
            * than computed.  Note that "ma" is NOT permitted: it is ambiguous
            * between match and master, and merge rejects it for that reason.
            * Computing minimum lengths instead of listing them would silently
            * set both flags on an ambiguous word.
            local ok 0
            if inlist("`kw'", "mat", "matc", "match") {
                local a_match 1
                local ok 1
            }
            if inlist("`kw'", "mas", "mast", "maste", "master") {
                local a_master 1
                local ok 1
            }
            if inlist("`kw'", "us", "usi", "usin", "using") {
                local a_using 1
                local ok 1
            }
            if !`ok' {
                if inlist("`kw'", "m", "ma") {
                    display as error ///
                        "assert(): {bf:`kw'} is ambiguous between " ///
                        "{bf:match} and {bf:master}; use {bf:mat} or {bf:mas}"
                }
                else {
                    display as error ///
                        "assert(): {bf:`kw'} not allowed; expected " ///
                        "{bf:match}, {bf:master} or {bf:using} " ///
                        "(abbreviable to {bf:mat}, {bf:mas}, {bf:us})"
                }
                exit 198
            }
        }
    }

    * -------------------------------------------------------------------------
    * 3. Refuse to proceed on an unverified linkage.  -frlink describe- performs
    *    the verification and, as a side effect, restores the using frame to
    *    match-variable order.  Both matter: see THE TRAP above.
    * -------------------------------------------------------------------------
    capture quietly frlink describe `lnk'
    if _rc {
        display as error ///
            "the linkage for {bf:`lnk'} is not valid; run " ///
            "{bf:frlink rebuild `lnk'} and try again"
        exit 459
    }

    * -------------------------------------------------------------------------
    * 4. Master side.  A missing link variable means no using row matched.
    * -------------------------------------------------------------------------
    local n_total_master = _N
    quietly count if missing(`lnk')
    local n_master = r(N)
    local n_match  = `n_total_master' - `n_master'

    * -------------------------------------------------------------------------
    * 5. Using side.  Mark, in the using frame, every row that at least one
    *    master row points at.  One indexed assignment in Mata; duplicate
    *    indices under m:1 are harmless.
    * -------------------------------------------------------------------------
    tempvar hit
    capture noisily mata: frlinkck_mark("`lnk'", "`frame2'", "`hit'")
    if _rc {
        capture frame `frame2': drop `hit'
        exit _rc
    }

    frame `frame2' {
        local n_total_using = _N
        quietly count if `hit' == 0
        local n_using = r(N)
        local n_match_using = `n_total_using' - `n_using'
    }

    * -------------------------------------------------------------------------
    * 6. Capture frames, if asked.  The link variable is dropped from the
    *    master-side capture: a link variable in a frame that is not the master
    *    frame addresses nothing.
    * -------------------------------------------------------------------------
    if "`nomatchmaster'" != "" {
        capture confirm new frame `nomatchmaster'
        if _rc {
            capture frame `frame2': drop `hit'
            display as error "frame {bf:`nomatchmaster'} already exists"
            exit 110
        }
        frame put * if missing(`lnk'), into(`nomatchmaster')
        frame `nomatchmaster' {
            capture drop `lnk'
            order `mvars1'
        }
    }

    if "`nomatchusing'" != "" {
        capture confirm new frame `nomatchusing'
        if _rc {
            capture frame `frame2': drop `hit'
            display as error "frame {bf:`nomatchusing'} already exists"
            exit 110
        }
        frame `frame2' {
            frame put * if `hit' == 0, into(`nomatchusing')
        }
        frame `nomatchusing' {
            capture drop `hit'
            order `mvars2'
        }
    }

    * Clean up: the marker never outlives the command.
    capture frame `frame2': drop `hit'

    * -------------------------------------------------------------------------
    * 7. Report.
    * -------------------------------------------------------------------------
    if "`nosummary'" == "" {
        local w = max(length("`frame1'"), length("`frame2'"))
        display ""
        display as text "  Match dispositions for {bf:`lnk'} " ///
            "({bf:`mtype'}, {bf:`frame1'} {c -}> {bf:`frame2'})"
        display as text "  {hline 52}"
        display as text "  master only" _col(24) "`frame1'" ///
            _col(42) as result %10.0fc `n_master'
        display as text "  using only"  _col(24) "`frame2'" ///
            _col(42) as result %10.0fc `n_using'
        display as text "  matched"     _col(24) "`frame1' rows" ///
            _col(42) as result %10.0fc `n_match'
        display as text "   "           _col(24) "`frame2' rows" ///
            _col(42) as result %10.0fc `n_match_using'
        display as text "  {hline 52}"
        display as text "  total"       _col(24) "`frame1'" ///
            _col(42) as result %10.0fc `n_total_master'
        display as text "   "           _col(24) "`frame2'" ///
            _col(42) as result %10.0fc `n_total_using'
        display ""
    }

    * -------------------------------------------------------------------------
    * 8. Returned results.  Stored BEFORE assert() fires, so that a caller using
    *    -capture- can read the counts and compose its own message.
    * -------------------------------------------------------------------------
    return scalar N_master        = `n_master'
    return scalar N_using         = `n_using'
    return scalar N_match         = `n_match'
    return scalar N_match_using   = `n_match_using'
    return scalar N_total_master  = `n_total_master'
    return scalar N_total_using   = `n_total_using'
    return local  match_type      "`mtype'"
    return local  frame_master    "`frame1'"
    return local  frame_using     "`frame2'"
    return local  matchvars_master "`mvars1'"
    return local  matchvars_using  "`mvars2'"
    * -------------------------------------------------------------------------
    * 9. Assert last, so the user sees the table and the stored results that
    *    explain the failure.
    * -------------------------------------------------------------------------
    if "`assert'" != "" {
        local bad 0
        if !`a_master' & `n_master' > 0 {
            display as error ///
                "`n_master' observation(s) in frame {bf:`frame1'} matched nothing"
            local bad 1
        }
        if !`a_using' & `n_using' > 0 {
            display as error ///
                "`n_using' observation(s) in frame {bf:`frame2'} matched nothing"
            local bad 1
        }
        if !`a_match' & `n_match' > 0 {
            display as error ///
                "`n_match' observation(s) matched, which assert() did not allow"
            local bad 1
        }
        if `bad' {
            exit 9
        }
    }

end

* =============================================================================
* Mata helper.  Writes a 0/1 marker into the using frame: 1 where some master
* row points at the observation.
* =============================================================================
version 16
mata:
mata set matastrict on

void frlinkck_mark(string scalar lnkvar,
                   string scalar f2,
                   string scalar hitvar)
{
    real colvector idx, hit
    real scalar    n2
    string scalar  f1

    f1  = st_framecurrent()
    idx = st_data(., lnkvar)
    idx = select(idx, idx :< .)

    st_framecurrent(f2)
    n2  = st_nobs()

    // No bounds check on idx.  frlinkck verifies the linkage before calling
    // this helper, and no linkage that survives verification can hold a link
    // value outside the frame.  A hand-written guard here would be a branch
    // nothing can reach and no test can exercise.
    hit = J(n2, 1, 0)
    if (rows(idx) > 0) hit[idx, 1] = J(rows(idx), 1, 1)
    st_store(., st_addvar("byte", hitvar), hit)

    st_framecurrent(f1)
}
end
