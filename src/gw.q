/ =============================================================================
/ gw.q -- gateway: the single entry point for every client
/ -----------------------------------------------------------------------------
/ One port, three protocols:
/   * q IPC     -> KX Dashboards, PyKX, q clients call getBars[], getStats[] ...
/   * HTTP      -> serves the web dashboard from ./web  (http://host:port/index.html)
/   * WebSocket -> pushes a JSON snapshot to every browser every -push ms
/ usage:  q src/gw.q -p 5020 [-rdb 5011] [-rte 5013] [-hdb 5012] [-push 500] [-web web]
/ =============================================================================

args:.Q.opt .z.x
.gw.opt:{[k;d] $[k in key args; first args k; d]}
.gw.num:{[k;d] "J"$.gw.opt[k;string d]}

/ ---- back-end connections (lazy, auto-reconnect) -----------------------------
.gw.conn:`rdb`rte`hdb!hsym `$"localhost:",/:string (.gw.num[`rdb;5011]; .gw.num[`rte;5013]; .gw.num[`hdb;5012])
.gw.h:`rdb`rte`hdb!3#0Ni

.gw.handle:{[p]
  if[null .gw.h p; .gw.h[p]:@[hopen;(.gw.conn p;1000);{[e] 0Ni}]];
  .gw.h p}

.gw.call:{[p;qry]
  h:.gw.handle p;
  if[null h; :()];
  @[h; qry; {[p;e] -2 (string .z.p)," gw: ",string[p]," error: ",e; ()}[p]]}

/ argument coercion, so callers may pass strings (KX Dashboards, JSON) or q types
.gw.sym:{$[10=abs type x; `$x; -11=type x; x; `$string x]}
.gw.date:{$[10=abs type x; "D"$x; "d"$x]}

/ ---- public API --------------------------------------------------------------
getTop:{[] .gw.call[`rte; (`.api.top; ::)]}
getStats:{[] .gw.call[`rte; (`.api.stats; ::)]}
getBars:{[s;secs;n] .gw.call[`rdb; (`.api.bars; .gw.sym s; "j"$secs; "j"$n)]}
getTape:{[n] .gw.call[`rdb; (`.api.tape; "j"$n)]}
getSpread:{[s;secs] .gw.call[`rdb; (`.api.spread; .gw.sym s; "j"$secs)]}
getVolume:{[] .gw.call[`rdb; (`.api.volume; ::)]}
getHistBars:{[s;d0;d1;m] .gw.call[`hdb; (`.api.histBars; .gw.sym s; .gw.date d0; .gw.date d1; "j"$m)]}
getHistDaily:{[d0;d1] .gw.call[`hdb; (`.api.histDaily; .gw.date d0; .gw.date d1)]}
getDates:{[] .gw.call[`hdb; (`.api.dates; ::)]}

/ ---- web dashboard: HTTP + WebSocket -----------------------------------------
.h.HOME:.gw.opt[`web;"web"]

/ per browser: selected symbol and bar size (seconds)
.gw.clients:(`int$())!`symbol$()
.gw.bar:(`int$())!`long$()

.z.wo:{[h] .gw.clients[h]:`; .gw.bar[h]:5}
.z.wc:{[h] .gw.clients _: h; .gw.bar _: h}

/ browsers send {"sym":"MSFT","bar":15}
.z.ws:{[m]
  c:@[.j.k; m; {[e] ()!()}];
  if[99<>type c; :()];
  if[`sym in key c; .gw.clients[.z.w]:`$c`sym];
  if[`bar in key c; .gw.bar[.z.w]:1|"j"$c`bar];
 }

.gw.snapshot:{[top;st;tape;h]
  syms:$[98=type st; st`sym; `symbol$()];
  s:.gw.clients h;
  if[null s; if[count syms; .gw.clients[h]:s:first syms]];
  bars:$[null s; (); getBars[s; .gw.bar h; 300]];
  if[98=type bars; bars:update t:1000*`long$bar from bars];
  neg[h] .j.j `type`time`sym`bar`top`stats`tape`bars!(`snapshot; .z.T; s; .gw.bar h; top; st; tape; bars);
 }

.gw.push:{[]
  if[0=count .gw.clients; :()];
  top:getTop[]; st:getStats[]; tape:getTape[40];
  {[top;st;tape;h] @[.gw.snapshot[top;st;tape]; h; {[e] -2 "gw: ws push error: ",e}]}[top;st;tape] each key .gw.clients;
 }

.z.ts:{@[.gw.push; ::; {[e] -2 "gw: push error: ",e}]}
system "t ",string .gw.num[`push;500];

.z.pc:{[h] .gw.h[where .gw.h=h]:0Ni}

-1 (string .z.p)," gw: ready on port ",string[system "p"];
-1 "    dashboard -> http://localhost:",string[system "p"],"/index.html";
