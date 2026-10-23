/ =============================================================================
/ rte.q -- real-time engine
/ -----------------------------------------------------------------------------
/ Subscribes to trades and quotes and maintains, incrementally, the analytics
/ a dashboard polls constantly: session OHLC, volume, notional, VWAP and the
/ latest top of book. Queries are O(number of symbols), not O(number of ticks).
/ usage:  q src/rte.q -p 5013 [-tp 5010]
/ =============================================================================

args:.Q.opt .z.x
.rte.tpPort:"J"$$[`tp in key args; first args`tp; "5010"]

/ ---- state -------------------------------------------------------------------
.rte.reset:{[]
  .rte.stats:([sym:`symbol$()]
    open:`float$(); high:`float$(); low:`float$(); lastPx:`float$();
    volume:`long$(); notional:`float$(); trades:`long$(); updTime:`timespan$());
  .rte.top:([sym:`symbol$()]
    bid:`float$(); ask:`float$(); bsize:`long$(); asize:`long$();
    mid:`float$(); spreadBps:`float$(); updTime:`timespan$());
 }
.rte.reset[]

/ ---- incremental analytics ---------------------------------------------------
.rte.onTrade:{[x]
  s:select open:first price, high:max price, low:min price, lastPx:last price,
      volume:sum size, notional:sum price*size, trades:count i, updTime:last time
      by sym from x;
  prev:`sym xkey select sym, oOpen:open, oHigh:high, oLow:low,
      oVol:volume, oNot:notional, oN:trades from 0!.rte.stats;
  m:s lj prev;
  m:update open:open^oOpen, high:high|oHigh, low:low^low&oLow,
      volume:volume+0^oVol, notional:notional+0f^oNot, trades:trades+0^oN from m;
  `.rte.stats upsert delete oOpen, oHigh, oLow, oVol, oNot, oN from m;
 }

.rte.onQuote:{[x]
  b:select by sym from x;
  b:update mid:0.5*bid+ask, spreadBps:1e4*(ask-bid)%0.5*bid+ask, updTime:time from b;
  `.rte.top upsert delete time from b;
 }

/ live messages arrive as tables; log replay delivers raw column lists
.rte.toTable:{[t;x] $[98=type x; x; 0>type first x; enlist (cols t)!x; flip (cols t)!x]}

upd:{[t;x]
  x:.rte.toTable[t;x];
  $[t~`trade; .rte.onTrade x;
    t~`quote; .rte.onQuote x;
    ()];
 }

.u.end:{[d] -1 (string .z.p)," rte: end of day ",string d; .rte.reset[]}

/ ---- query API ---------------------------------------------------------------
.api.top:{[] 0!update updTime:`time$updTime from .rte.top}

.api.stats:{[]
  0!update vwap:notional%volume, chgPct:100*(lastPx-open)%open, updTime:`time$updTime
    from .rte.stats}

/ ---- start-up ----------------------------------------------------------------
.rte.init:{[]
  h:hopen hsym `$"localhost:",string .rte.tpPort;
  r:h"(.u.sub[;`] each `trade`quote;(.u.j;.u.L))";
  {[p] (p 0) set p 1} each r 0;
  if[0<first r 1; -11!r 1];
  -1 (string .z.p)," rte: subscribed to tp:",string[.rte.tpPort],
     ", replayed ",string[first r 1]," messages, tracking ",string[count .rte.stats]," symbols";
 }

.rte.init[]
