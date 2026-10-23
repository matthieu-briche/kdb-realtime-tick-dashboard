/ =============================================================================
/ smoke_test.q -- checks that ticks flow end to end through the running stack
/ usage:  q scripts/smoke_test.q [-gw 5020]
/ =============================================================================

args:.Q.opt .z.x
port:$[`gw in key args; first args`gw; "5020"]
h:@[hopen; (hsym `$"localhost:",port; 2000); {-2 "FAIL: gateway not reachable: ",x; exit 1}]

fails:0
check:{[name;ok] -1 $[ok; "  ok    "; "  FAIL  "],name; if[not ok; `fails set fails+1]}

s1:h"getStats[]"
check["real-time engine returns stats"; (98=type s1) and 0<count s1]
system "sleep 2"
s2:h"getStats[]"
ntrades:{$[98=type x; sum x`trades; 0]}
check["trade count increases (ticks are flowing)"; (ntrades s2)>ntrades s1]
if[not 98=type s2; -1 "stopping: no stats from the real-time engine (see logs/rte.log)"; exit 1]
sym:first s2`sym
b:h(`getBars; sym; 5; 50)
check["rdb returns OHLCV bars for ",string sym; (98=type b) and 0<count b]
check["bars are consistent (low <= open,close <= high)"; all (b[`low]<=b[`open]&b`close) and (b[`high]>=b[`open]|b`close)]
t:h(`getTape; 10)
check["tape returns 10 prints"; 10=count t]
tb:h"getTop[]"
check["top of book has bid < ask"; all tb[`bid]<tb`ask]

-1 $[fails; string[fails]," check(s) failed"; "all checks passed"];
exit $[fails; 1; 0]
