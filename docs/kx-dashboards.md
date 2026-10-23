# Building the dashboard in KX Dashboards

The gateway (`gw.q`, port 5020) exposes every query the dashboard needs as a q function, so KX Dashboards only needs **one connection**. Menu labels differ slightly between KX Dashboards versions; refer to the official documentation on [code.kx.com](https://code.kx.com) for the exact screens of your release.

## 1. Start the stack

```bash
./scripts/start.sh
q scripts/smoke_test.q   # make sure data is flowing
```

## 2. Create the connection

In KX Dashboards, add a new **kdb+/q connection**:

| Field | Value |
|---|---|
| Name | `tickGW` |
| Host | `localhost` (or the machine running the stack) |
| Port | `5020` |

## 3. Create view states (dashboard variables)

| View state | Type | Default | Used by |
|---|---|---|---|
| `vsSym` | symbol / string | `AAPL` | every per-symbol query |
| `vsBar` | number | `5` | bar size in seconds |
| `vsDateFrom` | date | first date in `getDates[]` | history tab |
| `vsDateTo` | date | today | history tab |

Bind `vsSym` to a **drop-down** whose items come from a data source `exec sym from getStats[]`, and `vsBar` to a **button bar** with values 1, 5, 15, 60.

## 4. Create the data sources

Use **function** (or q expression) data sources on the `tickGW` connection. Map the function parameters to the view states.

| Data source | Query | Parameters | Refresh |
|---|---|---|---|
| `dsStats` | `getStats` | – | poll 500 ms |
| `dsTop` | `getTop` | – | poll 500 ms |
| `dsBars` | `getBars` | `vsSym`, `vsBar`, `300` | poll 1 s |
| `dsTape` | `getTape` | `50` | poll 500 ms |
| `dsSpread` | `getSpread` | `vsSym`, `10` | poll 2 s |
| `dsVolume` | `getVolume` | – | poll 2 s |
| `dsHist` | `getHistBars` | `vsSym`, `vsDateFrom`, `vsDateTo`, `15` | on change |

The gateway accepts symbols and dates as strings, so view states can be passed unchanged.

Equivalent q expressions, if you prefer expression data sources:

```q
getBars[`$vsSym; vsBar; 300]
getHistBars[`$vsSym; vsDateFrom; vsDateTo; 15]
select from getStats[] where sym=`$vsSym
```

## 5. Lay out the widgets

**Tab "Live"**

| Widget | Data source | Settings |
|---|---|---|
| Drop-down | `exec sym from getStats[]` | selection → `vsSym` |
| Button bar | static 1 / 5 / 15 / 60 | selection → `vsBar` |
| Text / KPI × 5 | `dsStats` filtered on `vsSym` | lastPx, chgPct, vwap, volume, trades |
| Candlestick (Canvas chart / Highcharts) | `dsBars` | x `bar`, open/high/low/close, volume as secondary series |
| Data grid "Market watch" | `dsStats` joined with `dsTop` | conditional colour on `chgPct`; row click → `vsSym` |
| Data grid "Time & sales" | `dsTape` | colour rows on `side` |
| Bar chart | `dsVolume` | x `sym`, y `notional` |
| Line chart | `dsSpread` | `mid` and `spreadBps` on two axes |

**Tab "History"**

| Widget | Data source | Settings |
|---|---|---|
| Date pickers | – | `vsDateFrom`, `vsDateTo` |
| Candlestick | `dsHist` | x `date`+`bar` |
| Data grid | `getHistDaily` with the two dates | daily OHLCV per symbol |

History appears after the first end of day. To create a partition immediately: `q)h:hopen 5010; h".u.endofday[]"`.

## 6. Tips

- Keep polling at 500 ms or slower per widget; the RTE queries are cheap, but a browser rendering dozens of widgets at 100 ms is not.
- Prefer `getStats` / `getTop` (pre-aggregated in the RTE) over aggregating trades in the dashboard.
- For heavier dashboards, add dedicated functions to `gw.q` that return exactly the shape a widget needs, rather than reshaping in the dashboard.
