# Finite import experiments: 12 runs

2000 mature accounts, 365 cycles, seeds 101/211/307. No live reward changes.

|Scenario|Mint|Retirement + external outflow|Net server money increase|Actual trade gross|Free medicine fulfillment|
|---|---:|---:|---:|---:|---:|
|w14_import12_batch6|9,379,078|1,606,099|7,772,979|2,176,051|93.52%|
|w14_import6_batch6|9,379,078|1,271,791|8,107,287|1,701,921|95.39%|
|w7_import12_batch1|14,413,618|1,752,345|12,661,273|2,307,418|93.58%|
|w7_import12_batch6|14,413,618|1,611,152|12,802,467|2,209,271|94.07%|

19 tests passed; independent money and gross audit: 12 runs, 4380 daily rows, 1491323 transactions. None passes every model gate. This is not an inflation estimate.

External imports reduce this server money, not necessarily global money. Finite NPC cash, stock and capacity remain enforced; retail margin stays in the NPC wallet. Opening inventory is not charged twice. Craft fee 2 replaces 1.

These scenarios do not implement the new Pro textile/metal/alchemy chain. Existing basket quotes cannot certify price stability after base price replacement. Profession sales include resale; sold_opportunity_cost uses production-time reference quotes or acquisition cash, not executable market depth. unsold_units is all held finished inventory, including purchased goods. Do not interpret these as pure manufacturing profit or sell-through.

imports-pre-basis-fix is an aborted diagnostic batch; exclude it from completed run counts. Its resale cost basis was incomplete.
