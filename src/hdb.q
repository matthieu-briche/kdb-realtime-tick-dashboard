/ =============================================================================
/ hdb.q -- historical database
/ -----------------------------------------------------------------------------
/ Serves the date-partitioned tick history written by the RDB at end of day.
/ The RDB sends "\l ." after each write-down, so new days appear automatically.
/ usage:  q src/hdb.q -p 5012 [-hdbdir db]
/ =============================================================================

args:.Q.opt .z.x
.hdb.dir:$[`hdbdir in key args; first args`hdbdir; "db"]

/ ---- query API ---------------------------------------------------------------
/ OHLCV bars of m minutes for symbol s between dates d0 and d1
.api.histBars:{[s;d0;d1;m]
  if[not `trade in tables[]; :()];
  0!select open:first price, high:max price, low:min price, close:last price,
      volume:sum size, vwap:size wavg price
      by date, bar:m xbar `minute$time from trade where date within (d0;d1), sym=s}

/ daily summary per symbol between d0 and d1
.api.histDaily:{[d0;d1]
  if[not `trade in tables[]; :()];
  0!select open:first price, high:max price, low:min price, close:last price,
      volume:sum size, notional:sum price*size, trades:count i
      by date, sym from trade where date within (d0;d1)}

/ dates available in the HDB
.api.dates:{[] @[value;`date;`date$()]}

system "mkdir -p ",.hdb.dir;
system "l ",.hdb.dir;

-1 (string .z.p)," hdb: ready on port ",string[system "p"]," | dates: ",string count .api.dates[];
