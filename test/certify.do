* =============================================================================
* frlinkck certification
* Run from the package root:  stata-mp -b do test/certify.do
* Every expected count below is derived by construction, not from a prior run.
* =============================================================================
clear all
set more off
adopath ++ "`c(pwd)'"
set seed 20261105

capture program drop setup
program define setup
    * Using frame: keys 100..119, shuffled so physical order != key order.
    * Master frame: 27 rows over keys 100..114 (m:1), plus 3 rows with keys
    * 900..902 that exist nowhere in the using frame.
    * Truth: master only = 3, using only = 5 (keys 115..119),
    *        matched master rows = 27, matched using rows = 15.
    frames reset
    frame create using_f
    frame using_f {
        set obs 20
        generate long ukey = 99 + _n
        generate double payload = ukey * 1000
        generate double u = runiform()
        sort u
        drop u
    }
    set obs 30
    generate long mkey = .
    replace mkey = 100 + mod(_n - 1, 15) in 1/27
    replace mkey = 900 + (_n - 28) in 28/30
    quietly frlink m:1 mkey, frame(using_f ukey) generate(lnk)
end

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 1: counts on a freshly created m:1 link"
* -----------------------------------------------------------------------------
setup
frlinkck lnk
assert r(N_master)       == 3
assert r(N_using)        == 5
assert r(N_match)        == 27
assert r(N_match_using)  == 15
assert r(N_total_master) == 30
assert r(N_total_using)  == 20
assert "`r(match_type)'"  == "m:1"
assert "`r(frame_using)'" == "using_f"
display "PASS 1"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 2: the rows identified are the right rows"
* -----------------------------------------------------------------------------
setup
frlinkck lnk, nomatchmaster(mo) nomatchusing(uo) nosummary
frame uo: levelsof ukey, local(got_u)
assert "`got_u'" == "115 116 117 118 119"
frame mo: levelsof mkey, local(got_m)
assert "`got_m'" == "900 901 902"
* Capture frames carry the payload, not just keys, and no leftover markers.
frame uo: confirm variable payload
frame uo: capture confirm variable lnk
assert _rc != 0
frame uo: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 2"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 3: hostile sort of the using frame"
* This is the case that defeats a naive implementation: the link values still
* exist but address the wrong physical rows.  An unguarded version reports the
* right COUNT and the wrong ROWS.
* -----------------------------------------------------------------------------
setup
frame using_f: gsort -ukey
frlinkck lnk, nomatchusing(uo2) nosummary
assert r(N_using) == 5
frame uo2: levelsof ukey, local(got2)
assert "`got2'" == "115 116 117 118 119"
display "PASS 3"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 4: no leftover variable in the using frame"
* -----------------------------------------------------------------------------
setup
frame using_f: describe, varlist
local before "`r(varlist)'"
frlinkck lnk, nosummary
frame using_f: describe, varlist
assert "`r(varlist)'" == "`before'"
display "PASS 4"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 5: assert() behaviour"
* -----------------------------------------------------------------------------
setup
* Unmatched on both sides, so a bare assert(match) must fail.
capture frlinkck lnk, assert(match) nosummary
assert _rc == 9
* Allowing both unmatched sides must succeed.
capture frlinkck lnk, assert(match master using) nosummary
assert _rc == 0
* Allowing only the master side must still fail on the using side.
capture frlinkck lnk, assert(match master) nosummary
assert _rc == 9
* A bad keyword is caught before any work happens.
capture frlinkck lnk, assert(matched) nosummary
assert _rc == 198
capture frlinkck lnk, assert(m) nosummary
assert _rc == 198
display "PASS 5"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 6: a perfect 1:1 link reports zero on both sides"
* -----------------------------------------------------------------------------
frames reset
frame create using_f
frame using_f {
    set obs 10
    generate long ukey = _n * 7
    generate double u = runiform()
    sort u
    drop u
}
set obs 10
generate long mkey = _n * 7
quietly frlink 1:1 mkey, frame(using_f ukey) generate(lnk)
frlinkck lnk, assert(match)
assert r(N_master) == 0 & r(N_using) == 0 & r(N_match) == 10
assert r(N_match_using) == 10
display "PASS 6"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 7: nothing matches at all"
* -----------------------------------------------------------------------------
frames reset
frame create using_f
frame using_f {
    set obs 6
    generate long ukey = _n
}
set obs 4
generate long mkey = 1000 + _n
quietly frlink m:1 mkey, frame(using_f ukey) generate(lnk)
frlinkck lnk, nosummary
assert r(N_master) == 4 & r(N_using) == 6
assert r(N_match) == 0 & r(N_match_using) == 0
display "PASS 7"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 8: multiple match variables"
* -----------------------------------------------------------------------------
frames reset
frame create using_f
frame using_f {
    set obs 9
    generate long k1 = ceil(_n/3)
    bysort k1: generate long k2 = _n
    generate double u = runiform()
    sort u
    drop u
}
set obs 9
generate long k1 = ceil(_n/3)
bysort k1: generate long k2 = _n
replace k1 = 99 in 9
quietly frlink m:1 k1 k2, frame(using_f) generate(lnk)
frlinkck lnk, nosummary
assert r(N_master) == 1
assert r(N_using)  == 1
assert r(N_match)  == 8
assert "`r(matchvars_master)'" == "k1 k2"
display "PASS 8"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 9: refuses a variable that is not a link"
* -----------------------------------------------------------------------------
frames reset
set obs 5
generate long notalink = _n
capture frlinkck notalink
assert _rc == 198
display "PASS 9"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 10: refuses to overwrite an existing frame"
* -----------------------------------------------------------------------------
setup
frame create mo
capture frlinkck lnk, nomatchmaster(mo) nosummary
assert _rc == 110
* and leaves no marker behind after the refusal
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 10"

display _n "{hline 70}"
display "ALL TESTS PASSED"
display "{hline 70}"
