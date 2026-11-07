* =============================================================================
* frlinkck certification
* Run from the package root:  stata-mp -b do test/certify.do
* Every expected count below is derived by construction, not from a prior run.
* Tests 1-14 cover the counts, the dispositions and the refusals; 15-29 sweep
* every option, every stored result, the printed table and the syntax errors.
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

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 11: r() survives a failed assert()"
* A caller that wraps frlinkck in -capture- must still be able to read the
* counts in order to compose its own message.
* -----------------------------------------------------------------------------
setup
capture frlinkck lnk, assert(match) nosummary
assert _rc == 9
assert r(N_master)      == 3
assert r(N_using)       == 5
assert r(N_match)       == 27
assert r(N_match_using) == 15
assert "`r(frame_using)'" == "using_f"
display "PASS 11"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 12: assert() abbreviations follow merge"
* merge accepts mat/mas/us and rejects the ambiguous ma (match vs master).
* Computing a minimum length instead of enumerating would accept ma and set
* both flags, silently permitting two dispositions from one ambiguous word.
* -----------------------------------------------------------------------------
setup
* Accepted abbreviations, spelled every permitted way.
foreach kw in mat matc match {
    capture frlinkck lnk, assert(`kw' master using) nosummary
    assert _rc == 0
}
foreach kw in mas mast maste master {
    capture frlinkck lnk, assert(match `kw' using) nosummary
    assert _rc == 0
}
foreach kw in us usi usin using {
    capture frlinkck lnk, assert(match master `kw') nosummary
    assert _rc == 0
}
* Rejected: ambiguous or too short.
foreach kw in m ma u mt mster {
    capture frlinkck lnk, assert(`kw') nosummary
    assert _rc == 198
}
* And the abbreviation must still bind to the right disposition: mas alone
* permits master-only but not using-only, so this must fail.
capture frlinkck lnk, assert(mat mas) nosummary
assert _rc == 9
display "PASS 12"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 13: refuses a linkage broken by changing the using frame"
* Dropping observations from the using frame leaves link values that address
* rows that no longer exist, or rows holding different records.  frlinkck must
* refuse rather than report.
* -----------------------------------------------------------------------------
setup
* Delete most of the using frame, invalidating the stored signature.
frame using_f: drop in 1/18
capture frlinkck lnk, nosummary
assert _rc != 0
display "   rc on a broken linkage = `=_rc'"
* No marker variable may be left behind by the refusal.
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 13"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 14: refuses after the using frame gains observations"
* -----------------------------------------------------------------------------
setup
frame using_f {
    set obs 40
    replace ukey = 500 + _n if missing(ukey)
}
capture frlinkck lnk, nosummary
assert _rc != 0
display "   rc after growth = `=_rc'"
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 14"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 15: link written as frame(name), match variable not restated"
* THE BUG THIS SECTION EXISTS FOR.  frlink records the linked frame's match
* variables in frlink_vl2 only when the user restates them inside frame().
* Written the shorter way -- frame(u) rather than frame(u k) -- frlink_vl2 is
* empty and only frlink_vl2p holds the names.  Reading vl2 therefore left the
* varlist empty, and -order- with no varlist is r(100): every call with a
* capture frame failed on a link written the way the help file's own example
* writes it.
* -----------------------------------------------------------------------------
capture program drop setup_implicit
program define setup_implicit
    * Same dispositions as -setup-, but one shared key name and frame(u).
    * Truth: master only = 3, using only = 5 (keys 115..119),
    *        matched master rows = 27, matched using rows = 15.
    frames reset
    frame create u
    frame u {
        set obs 20
        generate long k = 99 + _n
        generate double payload = k * 1000
        generate double shuffle = runiform()
        sort shuffle
        drop shuffle
    }
    set obs 30
    generate long k = .
    replace k = 100 + mod(_n - 1, 15) in 1/27
    replace k = 900 + (_n - 28) in 28/30
    quietly frlink m:1 k, frame(u) generate(lnk)
end

setup_implicit
* The characteristic the old code read is genuinely empty: this is the premise
* of the test, so assert it rather than trusting the description above.
local vl2  : char lnk[frlink_vl2]
local vl2p : char lnk[frlink_vl2p]
assert "`vl2'"  == ""
assert "`vl2p'" == "k"

frlinkck lnk, nomatchmaster(mo15) nomatchusing(uo15) nosummary
assert r(N_master) == 3 & r(N_using) == 5
assert r(N_match)  == 27 & r(N_match_using) == 15
* The name must be recovered, not left empty, in r() as well as internally.
assert "`r(matchvars_using)'"  == "k"
assert "`r(matchvars_master)'" == "k"
frame uo15: levelsof k, local(g15)
assert "`g15'" == "115 116 117 118 119"
frame mo15: levelsof k, local(gm15)
assert "`gm15'" == "900 901 902"
* order() ran, so the match variable is first in both capture frames.
frame uo15: describe, varlist
assert word("`r(varlist)'", 1) == "k"
frame mo15: describe, varlist
assert word("`r(varlist)'", 1) == "k"
display "PASS 15"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 16: same, with two match variables and frame(name)"
* -----------------------------------------------------------------------------
frames reset
frame create u
frame u {
    set obs 9
    generate long k1 = ceil(_n/3)
    bysort k1: generate long k2 = _n
    generate double shuffle = runiform()
    sort shuffle
    drop shuffle
}
set obs 9
generate long k1 = ceil(_n/3)
bysort k1: generate long k2 = _n
replace k1 = 99 in 9
quietly frlink m:1 k1 k2, frame(u) generate(lnk)
local vl2 : char lnk[frlink_vl2]
assert "`vl2'" == ""
frlinkck lnk, nomatchusing(uo16) nosummary
assert r(N_master) == 1 & r(N_using) == 1 & r(N_match) == 8
assert "`r(matchvars_using)'" == "k1 k2"
frame uo16: describe, varlist
assert word("`r(varlist)'", 1) == "k1"
assert word("`r(varlist)'", 2) == "k2"
display "PASS 16"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 17: an empty frlink_vl2p is refused, not worked around"
* The linked frame's match variables are read from frlink_vl2p alone, with no
* fallback to frlink_vl2.  This test records why a fallback would be dead code:
* -frlink describe- itself fails when vl2p is empty, so the command refuses at
* verification and never reaches the point where the varlist is used.
* -----------------------------------------------------------------------------
setup_implicit
char lnk[frlink_vl2p] ""
capture frlinkck lnk, nomatchusing(uo17) nosummary
assert _rc == 459
capture confirm frame uo17
assert _rc != 0
frame u: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 17"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 18: capture frames when a side has nothing unmatched"
* A perfect link asked for both capture frames must succeed and create two
* frames holding no observations, not fail and not skip the frame.
* -----------------------------------------------------------------------------
frames reset
frame create u
frame u {
    set obs 10
    generate long k = _n
}
set obs 10
generate long k = _n
quietly frlink 1:1 k, frame(u) generate(lnk)
frlinkck lnk, nomatchmaster(mo18) nomatchusing(uo18) nosummary
assert r(N_master) == 0 & r(N_using) == 0
confirm frame mo18
confirm frame uo18
frame mo18: assert _N == 0
frame uo18: assert _N == 0
* The marker must not survive into the using-side capture frame.
frame uo18: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 18"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 19: both capture frames in one call carry full records"
* -----------------------------------------------------------------------------
setup
frlinkck lnk, nomatchmaster(mo19) nomatchusing(uo19) nosummary
frame mo19: assert _N == 3
frame uo19: assert _N == 5
* Using side keeps its payload; master side keeps its variables but loses the
* link variable, which would address nothing outside the master frame.
frame uo19: confirm variable payload
frame mo19: capture confirm variable lnk
assert _rc != 0
frame uo19: capture confirm variable lnk
assert _rc != 0
display "PASS 19"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 20: refuses an unknown link format version"
* -----------------------------------------------------------------------------
setup
char lnk[frlink_ver] 2
capture frlinkck lnk, nosummary
assert _rc == 198
* and nothing was done to the using frame before the refusal
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 20"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 21: syntax rejections"
* -----------------------------------------------------------------------------
frames reset
set obs 5
generate long a = _n
generate str3 s = "x"
capture frlinkck
assert _rc == 100
capture frlinkck s
assert _rc == 109
capture frlinkck nosuchvar
assert _rc == 111
capture frlinkck a a
assert _rc == 103
* An invalid frame name is caught by syntax, before any work.
capture frlinkck a, nomatchusing(not a name)
assert _rc != 0
display "PASS 21"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 22: the master frame need not be called default"
* -----------------------------------------------------------------------------
frames reset
frame create master_f
frame create u
frame u {
    set obs 8
    generate long k = _n
}
frame change master_f
set obs 5
generate long k = _n
quietly frlink m:1 k, frame(u) generate(lnk)
frlinkck lnk, nosummary
assert "`r(frame_master)'" == "master_f"
assert "`r(frame_using)'"  == "u"
assert r(N_master) == 0 & r(N_using) == 3 & r(N_match) == 5
frame change default
display "PASS 22"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 23: string match variables"
* -----------------------------------------------------------------------------
frames reset
frame create u
frame u {
    set obs 4
    generate str5 sk = "a" + string(_n)
    generate double shuffle = runiform()
    sort shuffle
    drop shuffle
}
set obs 6
generate str5 sk = "a" + string(_n)
quietly frlink m:1 sk, frame(u) generate(lnk)
frlinkck lnk, nomatchmaster(mo23) nosummary
assert r(N_master) == 2 & r(N_using) == 0 & r(N_match) == 4
frame mo23 {
    assert _N == 2
    assert sk == "a5" | sk == "a6"
    quietly count if sk == "a5"
    assert r(N) == 1
}
display "PASS 23"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 24: every assert() subset, against known dispositions"
* The fixture has all three dispositions non-empty (3 / 5 / 27), so the only
* subset that may pass is the complete one.  Enumerated as a loop rather than
* written out seven times.
* -----------------------------------------------------------------------------
setup
foreach s in "match" "master" "using" "match master" "match using" ///
             "master using" "match master using" {
    capture frlinkck lnk, assert(`s') nosummary
    if "`s'" == "match master using" {
        assert _rc == 0
    }
    else {
        assert _rc == 9
    }
}
* assert(master using) is the subset that exercises the matched-not-allowed
* branch, which no other test reaches: 27 rows matched and match was omitted.
capture frlinkck lnk, assert(master using) nosummary
assert _rc == 9
* A repeated keyword is harmless, and an empty assert() is simply no assertion.
capture frlinkck lnk, assert(match match master using) nosummary
assert _rc == 0
capture frlinkck lnk, assert() nosummary
assert _rc == 0
display "PASS 24"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 25: the table is printed, suppressed, and correct"
* The displayed table is a feature and is checked like one: run with and
* without nosummary into a text log and read the result back.
* -----------------------------------------------------------------------------
setup
tempfile tbl
quietly log using "`tbl'", text replace name(tabletest)
frlinkck lnk
quietly log close tabletest

local header 0
local mo_ok  0
local uo_ok  0
local mm_ok  0
local mu_ok  0
file open fh using "`tbl'", read text
file read fh line
while r(eof) == 0 {
    if strpos(`"`line'"', "Match dispositions") local header 1
    if strpos(`"`line'"', "master only")  local mo_ok = regexm(`"`line'"', "3 *$")
    if strpos(`"`line'"', "using only")   local uo_ok = regexm(`"`line'"', "5 *$")
    if strpos(`"`line'"', "default rows") local mm_ok = regexm(`"`line'"', "27 *$")
    if strpos(`"`line'"', "using_f rows") local mu_ok = regexm(`"`line'"', "15 *$")
    file read fh line
}
file close fh
assert `header' == 1
assert `mo_ok'  == 1
assert `uo_ok'  == 1
assert `mm_ok'  == 1
assert `mu_ok'  == 1

* nosummary must print nothing at all.
tempfile quiet
quietly log using "`quiet'", text replace name(quiettest)
frlinkck lnk, nosummary
quietly log close quiettest
local any 0
file open fh2 using "`quiet'", read text
file read fh2 line
while r(eof) == 0 {
    if strpos(`"`line'"', "Match dispositions") local any 1
    if strpos(`"`line'"', "master only")        local any 1
    file read fh2 line
}
file close fh2
assert `any' == 0
display "PASS 25"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 26: every documented r() result is present"
* -----------------------------------------------------------------------------
setup
frlinkck lnk, nosummary
foreach s in N_master N_using N_match N_match_using N_total_master N_total_using {
    assert !missing(r(`s'))
}
foreach m in match_type frame_master frame_using matchvars_master matchvars_using {
    local v "`r(`m')'"
    assert "`v'" != ""
}
display "PASS 26"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 27: no marker left behind when the using capture frame exists"
* Test 10 covers the master-side refusal; this is the using-side twin.
* -----------------------------------------------------------------------------
setup
frame create uo27
capture frlinkck lnk, nomatchusing(uo27) nosummary
assert _rc == 110
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 27"

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 28: reports on framerge links, capture frames included"
* framerge writes frlink_vl2p and no frlink_vl2, exactly like frlink's
* frame(name) form, so this exercises the same recovery on a foreign link.
* Skipped, not failed, where framerge is not installed.
* -----------------------------------------------------------------------------
capture which framerge
if _rc {
    display "SKIP 28: framerge not installed"
}
else {
    frames reset
    frame create u
    frame u {
        set obs 20
        generate long k = 99 + _n
        generate double shuffle = runiform()
        sort shuffle
        drop shuffle
    }
    set obs 30
    generate long k = .
    replace k = 100 + mod(_n - 1, 15) in 1/27
    replace k = 900 + (_n - 28) in 28/30
    quietly framerge m:1 k, frame(u) linkvar(fm)
    frlinkck fm, nomatchusing(uo28) nosummary
    assert r(N_master) == 3 & r(N_using) == 5
    assert r(N_match) == 27 & r(N_match_using) == 15
    assert "`r(matchvars_using)'" == "k"
    frame uo28: levelsof k, local(g28)
    assert "`g28'" == "115 116 117 118 119"
    * and a perfect 1:1 framerge link
    frames reset
    frame create u
    frame u {
        set obs 10
        generate long k = _n
    }
    set obs 10
    generate long k = _n
    quietly framerge 1:1 k, frame(u) linkvar(fm)
    frlinkck fm, assert(match) nosummary
    assert r(N_master) == 0 & r(N_using) == 0 & r(N_match) == 10
    display "PASS 28"
}

* -----------------------------------------------------------------------------
display _n "{hline 70}" _n "TEST 29: the command leaves the master frame's data untouched"
* frlinkck re-sorts the using frame, as any use of the linkage does, but it must
* add and remove nothing in either frame and must not change the master's data.
* -----------------------------------------------------------------------------
setup
describe, varlist
local mbefore "`r(varlist)'"
quietly count if missing(lnk)
local cbefore = r(N)
frlinkck lnk, nomatchmaster(mo29) nomatchusing(uo29)
describe, varlist
assert "`r(varlist)'" == "`mbefore'"
quietly count if missing(lnk)
assert r(N) == `cbefore'
frame using_f: describe, varlist
assert strpos("`r(varlist)'", "__") == 0
display "PASS 29"

display _n "{hline 70}"
display "ALL TESTS PASSED"
display "{hline 70}"
