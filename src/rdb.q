/ =============================================================================
/ rdb.q -- real-time database
/ -----------------------------------------------------------------------------
/ Subscribes to all tables on the tickerplant, keeps today's ticks in memory,
/ replays the tickerplant log on start-up, and writes the day to the HDB at
/ end of day.
/ usage:  q src/rdb.q -p 5011 [-tp 5010] [-hdb 5012] [-hdbdir db]
/ =============================================================================

args:.Q.opt .z.x
.rdb.opt:{[k;d] $[k in key args; first args k; d]}

.rdb.tpPort:"J"$.rdb.opt[`tp;"5010"]
.rdb.hdbPort:"J"$.rdb.opt[`hdb;"5012"]
.rdb.hdbDir:.rdb.opt[`hdbdir;"db"]

/ every tick message from the tickerplant (and from the log replay) lands here
upd:insert

/ end of day: save every table as a date partition, reload the HDB, clear memory
.u.end:{[d]
  -1 (string .z.p)," rdb: end of day ",string d;
  .Q.hdpf[hsym `$"localhost:",string .rdb.hdbPort; hsym `$.rdb.hdbDir; d; `sym];
  {[t] t set update sym:`g#sym from value t} each tables`.;
 }

/ ---- query API (used by the gateway and KX Dashboards) ------------------------
/ OHLCV bars of secs seconds for symbol s, last n bars
.api.bars:{[s;secs;n]
  r:0!select open:first price, high:max price, low:min price, close:last price,
      volume:sum size, vwap:size wavg price, trades:count i
      by bar:secs xbar `second$time from trade where sym=s;
  neg[n] sublist r}

/ most recent n trades, newest first
.api.tape:{[n] reverse update time:`time$time from neg[n] sublist trade}

/ mid price and spread (bps) sampled every secs seconds for symbol s
.api.spread:{[s;secs]
  0!select mid:last 0.5*bid+ask, spreadBps:last 1e4*(ask-bid)%0.5*bid+ask
    by bar:secs xbar `second$time from quote where sym=s}

/ traded volume and notional per symbol since the open
.api.volume:{[] 0!select volume:sum size, notional:sum price*size, trades:count i by sym from trade}

/ ---- start-up ----------------------------------------------------------------
.rdb.init:{[]
  h:hopen hsym `$"localhost:",string .rdb.tpPort;
  / subscribe and get the log position in one round trip, so nothing is missed
  r:h"(.u.sub[`;`];(.u.j;.u.L))";
  {[p] (p 0) set p 1} each r 0;
  if[0<first r 1; -11!r 1];
  -1 (string .z.p)," rdb: subscribed to tp:",string[.rdb.tpPort],
     ", replayed ",string[first r 1]," messages | rows: ",
     ", " sv {string[x],"=",string count value x} each tables`.;
 }

.rdb.init[]
.z.pc:{[h] -2 (string .z.p)," rdb: connection ",string[h]," closed"}
