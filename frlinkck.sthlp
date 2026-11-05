{smcl}
{* *! version 0.1.0  05nov2026}{...}
{vieweralsosee "[D] frlink" "help frlink"}{...}
{vieweralsosee "[D] frget" "help frget"}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{vieweralsosee "[D] frames intro" "help frames intro"}{...}
{viewerjumpto "Syntax" "frlinkck##syntax"}{...}
{viewerjumpto "Description" "frlinkck##description"}{...}
{viewerjumpto "Options" "frlinkck##options"}{...}
{viewerjumpto "Remarks" "frlinkck##remarks"}{...}
{viewerjumpto "Examples" "frlinkck##examples"}{...}
{viewerjumpto "Stored results" "frlinkck##results"}{...}
{p2colset 1 16 18 2}{...}
{p2col:{bf:frlinkck} {hline 2}}Match dispositions after {bf:frlink}{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:frlinkck} {it:linkvar}
[{cmd:,} {it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt assert(keywords)}}error and exit unless every observation falls
in one of the dispositions listed; {it:keywords} are {opt mas:ter},
{opt us:ing} and {opt mat:ch}{p_end}
{synopt :{opt nomatchm:aster(newframe)}}put the unmatched observations of the
master frame into {it:newframe}{p_end}
{synopt :{opt nomatchu:sing(newframe)}}put the unmatched observations of the
linked frame into {it:newframe}{p_end}
{synopt :{opt nosum:mary}}suppress the table; still assert, still store
{cmd:r()}{p_end}
{synoptline}
{p2colreset}{...}

{pstd}
{it:linkvar} is the name of a link variable that {helpb frlink} has already
created in the current frame. The frames, the match variables and the match
type are read from the link variable, so none of them is specified again.

{marker description}{...}
{title:Description}

{pstd}
{cmd:frlinkck} reports, for an existing {helpb frlink} linkage, the three match
dispositions that {helpb merge} reports and {cmd:frlink} does not:

{p2colset 8 32 34 2}{...}
{p2col:{bf:master only}}observations in the current frame that matched no
observation in the linked frame; {cmd:merge}'s {cmd:_merge==1}{p_end}
{p2col:{bf:using only}}observations in the linked frame that no observation in
the current frame matched; {cmd:merge}'s {cmd:_merge==2}{p_end}
{p2col:{bf:matched}}observations that matched; {cmd:merge}'s
{cmd:_merge==3}{p_end}
{p2colreset}{...}

{pstd}
What {cmd:frlink} reports is a single count of unmatched observations in the
current frame. Nothing reports the linked frame's unmatched observations, and
nothing stops a do-file when the match fails. {cmd:frlinkck} supplies both, and
can put the unmatched records from either side into a new frame for inspection.

{pstd}
Note that {bf:matched} is reported twice, because under {cmd:m:1} the two counts
differ: several observations in the current frame can match the same observation
in the linked frame. The first line counts observations in the current frame,
the second counts distinct observations in the linked frame that were matched.

{marker options}{...}
{title:Options}

{phang}
{opt assert(keywords)} specifies the dispositions you expect. Any observation
outside them is an error and {cmd:frlinkck} exits with return code 9. The
keywords and their meaning are {helpb merge}'s: {opt master}, {opt using} and
{opt match}, specified in any combination and any order.

{pmore}
The permitted abbreviations are also {cmd:merge}'s: {cmd:match} to {cmd:mat},
{cmd:master} to {cmd:mas}, {cmd:using} to {cmd:us}. {cmd:ma} is not permitted,
being ambiguous between {cmd:match} and {cmd:master}.

{pmore}
{cmd:assert(match)} is the usual claim: every observation in both frames
matched. {cmd:assert(match master)} permits unmatched observations in the
current frame but not in the linked frame.

{pmore}
The table is displayed before the error, so you can see what went wrong.

{phang}
{opt nomatchmaster(newframe)} creates {it:newframe} holding the observations of
the current frame that matched nothing. All variables are copied except the link
variable itself, which would address nothing outside the master frame. The match
variables are ordered first.

{phang}
{opt nomatchusing(newframe)} creates {it:newframe} holding the observations of
the linked frame that nothing matched. {cmd:frlinkck} refuses to overwrite an
existing frame.

{phang}
{opt nosummary} suppresses the table. {cmd:assert()} is still enforced and
{cmd:r()} is still stored, which is what you want inside a do-file that only
needs the check.

{marker remarks}{...}
{title:Remarks}

{pstd}
{bf:How the using-frame count is obtained.} {cmd:frlink} sorts the linked frame
by the match variables and records, in the link variable, the physical
observation number of the matched row in that order; the value is missing where
nothing matched. The set of linked-frame observations that were matched is
therefore exactly the set of non-missing link-variable values, and the
complement of that set is the {bf:using only} group.

{pstd}
{bf:Why the linkage is verified first.} That correspondence holds only while the
linked frame remains in match-variable order. Re-sort the linked frame and the
link variable still holds the same numbers, but they now address different rows.
A naive implementation then reports the correct {it:number} of unmatched
observations and the wrong {it:observations}, with no error. {cmd:frlinkck}
verifies the linkage before reading the linked frame, which also restores its
sort order. If the linkage cannot be verified, {cmd:frlinkck} refuses to report
and tells you to run {helpb frlink##rebuild:frlink rebuild}.

{pstd}
{bf:Nothing is left behind.} {cmd:frlinkck} creates no permanent variable in
either frame. It does re-sort the linked frame, as any use of the linkage does.

{marker examples}{...}
{title:Examples}

{pstd}Setup{p_end}
{phang2}{cmd:. webuse persons, clear}{p_end}
{phang2}{cmd:. frame create txcounty}{p_end}
{phang2}{cmd:. frame txcounty: webuse txcounty, clear}{p_end}
{phang2}{cmd:. frlink m:1 countyid, frame(txcounty) generate(cty)}{p_end}

{pstd}Report the dispositions{p_end}
{phang2}{cmd:. frlinkck cty}{p_end}

{pstd}Require a perfect match, and stop the do-file otherwise{p_end}
{phang2}{cmd:. frlinkck cty, assert(match)}{p_end}

{pstd}Permit unmatched persons, but no unused counties{p_end}
{phang2}{cmd:. frlinkck cty, assert(match master)}{p_end}

{pstd}Capture both unmatched sides for inspection{p_end}
{phang2}{cmd:. frlinkck cty, nomatchmaster(lost_persons) nomatchusing(unused_counties)}{p_end}
{phang2}{cmd:. frame unused_counties: list}{p_end}

{pstd}Silent check inside a pipeline{p_end}
{phang2}{cmd:. frlinkck cty, assert(match) nosummary}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:frlinkck} stores the following in {cmd:r()}. The results are stored before
{cmd:assert()} is evaluated, so they remain readable after a failed assertion
caught with {helpb capture}.

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt :{cmd:r(N_master)}}unmatched observations in the current frame{p_end}
{synopt :{cmd:r(N_using)}}unmatched observations in the linked frame{p_end}
{synopt :{cmd:r(N_match)}}matched observations, counted in the current
frame{p_end}
{synopt :{cmd:r(N_match_using)}}matched observations, counted in the linked
frame{p_end}
{synopt :{cmd:r(N_total_master)}}observations in the current frame{p_end}
{synopt :{cmd:r(N_total_using)}}observations in the linked frame{p_end}

{p2col 5 24 28 2: Macros}{p_end}
{synopt :{cmd:r(match_type)}}{cmd:1:1} or {cmd:m:1}{p_end}
{synopt :{cmd:r(frame_master)}}name of the current frame{p_end}
{synopt :{cmd:r(frame_using)}}name of the linked frame{p_end}
{synopt :{cmd:r(matchvars_master)}}match variables in the current frame{p_end}
{synopt :{cmd:r(matchvars_using)}}match variables in the linked frame{p_end}
{p2colreset}{...}

{marker author}{...}
{title:Author}

{phang}
Marshall Garland{break}
Center for Applied Research in Education{break}
{browse "mailto:garlandm@usc.edu":garlandm@usc.edu}

{title:Also see}

{psee}
Help: {helpb frlink}, {helpb frget}, {helpb merge}, {helpb frames intro}
{p_end}
