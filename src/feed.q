/ =============================================================================
/ feed.q -- simulated market data feed handler
/ -----------------------------------------------------------------------------
/ Generates a random-walk trade and quote stream for a basket of symbols and
/ publishes it asynchronously to the tickerplant. Replace this process with a
/ real feed handler (exchange, broker API, Kafka, websocket ...) to go live:
/ the rest of the stack does not change.
/
/ usage:  q src/feed.q [-tp 5010] [-rate 100] [-batch 15] [-sigma 0.0003]
/                      [-syms AAPL,MSFT,NVDA]
/ =============================================================================

args:.Q.opt .z.x
.feed.opt:{[k;d] $[k in key args; first args k; d]}

.feed.tpPort:"J"$.feed.opt[`tp;"5010"]
.feed.rate:"J"$.feed.opt[`rate;"100"]          / timer in ms
.feed.maxBatch:"J"$.feed.opt[`batch;"15"]      / max ticks per timer call
.feed.sigma:"F"$.feed.opt[`sigma;"0.0003"]     / per-tick log-return volatility

.feed.syms:$[`syms in key args; `$"," vs first args`syms; `AAPL`MSFT`NVDA`AMZN`GOOGL`META`TSLA`JPM]

/ indicative starting prices; unknown symbols start at 100
.feed.ref:`AAPL`MSFT`NVDA`AMZN`GOOGL`META`TSLA`JPM!230 430 180 220 250 700 450 300f
.feed.px:.feed.syms!100f^.feed.ref .feed.syms

.feed.round:{0.01*`long$100*x}
.feed.gauss:{[n] sqrt[-2*log 1-n?1f]*cos 2*acos[-1]*n?1f}

.feed.h:hopen hsym `$"localhost:",string .feed.tpPort

.feed.tick:{[]
  n:1+rand .feed.maxBatch;
  s:n?.feed.syms;
  p:.feed.round .feed.px[s]*exp .feed.sigma*.feed.gauss n;
  .feed.px[s]:p;
  neg[.feed.h](`.u.upd; `trade; (s; p; 100*1+n?10; n?`buy`sell));
  hs:0.01|.feed.round p*0.0001*1+n?3;
  neg[.feed.h](`.u.upd; `quote; (s; .feed.round p-hs; .feed.round p+hs; 100*1+n?50; 100*1+n?50));
 }

.z.ts:{.feed.tick[]}
.z.pc:{[h] -2 "feed: tickerplant disconnected, exiting"; exit 0}
system "t ",string .feed.rate

-1 (string .z.p)," feed: publishing ",string[count .feed.syms]," symbols to tp:",string[.feed.tpPort],
   " every ",string[.feed.rate],"ms";
