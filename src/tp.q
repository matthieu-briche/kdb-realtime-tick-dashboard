/ =============================================================================
/ tp.q -- tickerplant
/ -----------------------------------------------------------------------------
/ Receives ticks from feed handlers, stamps them, writes every message to a
/ daily log file (for recovery) and publishes them to subscribers.
/ usage:  q src/tp.q -p 5010 [-schema schema/sym.q] [-logdir tplogs]
/ API exposed to clients:
/   .u.upd[t;x]   publish rows x into table t   (called by feed handlers)
/   .u.sub[t;s]   subscribe to table t (` = all) for syms s (` = all)
/   .u.endofday[] roll the day (normally triggered automatically at midnight)
/ =============================================================================

args:.Q.opt .z.x
.tp.opt:{[k;d] $[k in key args; first args k; d]}

.tp.schema:.tp.opt[`schema;"schema/sym.q"]
.tp.logdir:.tp.opt[`logdir;"tplogs"]

system "l ",.tp.schema

/ ---- subscription state ------------------------------------------------------
/ .u.w : table -> list of (handle; sym filter)
.u.t:tables`.
.u.w:.u.t!(count .u.t)#()

/ x: table, y: sym filter (` means everything)
.u.sel:{[x;y] $[`~y; x; select from x where sym in y]}

/ remove handle h from table t
.u.del:{[t;h] .u.w[t]_:.u.w[t;;0]?h}

/ register the calling handle on table t for syms s, return (t; schema)
.u.add:{[t;s]
  $[(count .u.w t)>i:.u.w[t;;0]?.z.w;
    .[`.u.w;(t;i;1);union;s];
    .u.w[t],:enlist(.z.w;s)];
  (t;@[0#value t;`sym;`g#])}

.u.sub:{[t;s]
  if[t~`; :.u.sub[;s] each .u.t];
  if[not t in .u.t; 'string t];
  .u.del[t].z.w;
  .u.add[t;s]}

/ push table x (already a table) for t to every subscriber
.u.pub:{[t;x]
  {[t;x;w] if[count x:.u.sel[x]w 1; (neg first w)(`upd;t;x)]}[t;x] each .u.w t}

/ tell every subscriber the day d is over
.u.end:{[d] (neg union/[.u.w[;;0]])@\:(`.u.end;d)}

.z.pc:{[h] .u.del[;h] each .u.t}

/ ---- logging -----------------------------------------------------------------
/ open (or create) the log for date d, set .u.L and the message count .u.j
.u.ld:{[d]
  system "mkdir -p ",.tp.logdir;
  L:hsym `$.tp.logdir,"/",string[d],".tplog";
  if[not type key L; .[L;();:;()]];
  .u.j:-11!(-2;L);
  if[0<=type .u.j; -2 "tp: corrupt log ",string[L],", truncate it with -11!(-4;L) first"; exit 1];
  .u.L:L;
  -1 (string .z.p)," tp: logging to ",string[L]," (",string[.u.j]," messages)";
  hopen L}

.u.d:.z.D
.u.l:.u.ld .u.d

/ ---- publishing --------------------------------------------------------------
/ x is either one row (list of atoms) or a list of columns, with or without time
.u.upd:{[t;x]
  if[.u.d<.z.D; .u.endofday[]];
  if[not -16=type first first x;
    x:$[0>type first x; .z.N,x; (enlist(count first x)#.z.N),x]];
  c:cols t;
  .u.pub[t; $[0>type first x; enlist c!x; flip c!x]];
  .u.l enlist (`upd;t;x);
  .u.j+:1;
 }

.u.endofday:{[]
  -1 (string .z.p)," tp: end of day ",string .u.d;
  .u.end .u.d;
  .u.d+:1;
  hclose .u.l;
  .u.l:.u.ld .u.d;
 }

/ roll the day even when no ticks arrive around midnight
.z.ts:{if[.u.d<.z.D; .u.endofday[]]}
\t 1000

-1 (string .z.p)," tp: ready on port ",string[system "p"]," | tables: ",", " sv string .u.t;
