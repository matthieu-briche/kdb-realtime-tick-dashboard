/ =============================================================================
/ sym.q -- tick schema shared by every process in the stack
/ -----------------------------------------------------------------------------
/ Loaded by the tickerplant; subscribers receive these definitions on .u.sub.
/ The first column of every table MUST be `time (timespan): the tickerplant
/ stamps incoming rows with .z.N when the feed does not supply it.
/ =============================================================================

trade:([]
  time:`timespan$();
  sym:`g#`symbol$();
  price:`float$();
  size:`long$();
  side:`symbol$())

quote:([]
  time:`timespan$();
  sym:`g#`symbol$();
  bid:`float$();
  ask:`float$();
  bsize:`long$();
  asize:`long$())
