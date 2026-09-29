# V3 production chain and campaign feasibility

27 runs: 2000 mature accounts, 365 cycles, seeds 101/211/307. All values below are model outputs, not player telemetry.
Fixed prices deliberately isolate quantity and wallet feasibility. No inflation, price-stability or market-clearing-price verdict.
No changes to actual rewards, saves or runtime. Two campaigns start on cycles 120 and 240; normal days include postwar days.

|Scenario|Annual mint|Retire + import outflow|Net money increase|Trade gross + base NPC sales|
|---|---:|---:|---:|---:|
|w0_control|42,276,183|1,105,493|41,170,689|1,346,789|
|w0_war_prep7|42,276,183|1,124,134|41,152,049|1,373,016|
|w7_control|14,374,638|1,105,493|13,269,144|1,346,789|
|w7_war_prep7|14,374,638|1,124,134|13,250,504|1,373,016|
|w14_control|9,336,073|1,105,493|8,230,579|1,346,789|
|w14_war_prep7|9,336,073|1,124,134|8,211,939|1,373,016|
|w14_war_mint|9,348,073|1,124,134|8,223,939|1,373,016|
|w14_war_no_prep|9,336,073|1,124,134|8,211,939|1,373,032|
|w14_war_70_30|9,336,073|1,124,475|8,211,598|1,373,885|

## Medicine by phase (free accounts)

|Scenario|Phase|Craft fill incl. delivered field medicine|System guarantee fill|Total fill|
|---|---|---:|---:|---:|
|w0_control|normal|99.55%|0.45%|100.00%|
|w0_war_prep7|normal|99.53%|0.47%|100.00%|
|w0_war_prep7|preparation|100.00%|0.00%|100.00%|
|w0_war_prep7|action|100.00%|0.00%|100.00%|
|w7_control|normal|99.55%|0.45%|100.00%|
|w7_war_prep7|normal|99.53%|0.47%|100.00%|
|w7_war_prep7|preparation|100.00%|0.00%|100.00%|
|w7_war_prep7|action|100.00%|0.00%|100.00%|
|w14_control|normal|99.55%|0.45%|100.00%|
|w14_war_prep7|normal|99.53%|0.47%|100.00%|
|w14_war_prep7|preparation|100.00%|0.00%|100.00%|
|w14_war_prep7|action|100.00%|0.00%|100.00%|
|w14_war_mint|normal|99.53%|0.47%|100.00%|
|w14_war_mint|preparation|100.00%|0.00%|100.00%|
|w14_war_mint|action|100.00%|0.00%|100.00%|
|w14_war_no_prep|normal|99.55%|0.45%|100.00%|
|w14_war_no_prep|action|100.00%|0.00%|100.00%|
|w14_war_70_30|normal|99.53%|0.47%|100.00%|
|w14_war_70_30|preparation|100.00%|0.00%|100.00%|
|w14_war_70_30|action|100.00%|0.00%|100.00%|

## Production sold at least once

|Scenario|Profession|Produced|First-sale ratio|End product inventory|
|---|---|---:|---:|---:|
|w0_control|textile|28,653|81.27%|5,367|
|w0_control|leather|20,100|56.19%|5,162|
|w0_control|metal|51,571|90.31%|4,998|
|w0_control|alchemy|46,573|70.70%|3,994|
|w0_war_prep7|textile|29,023|81.69%|5,315|
|w0_war_prep7|leather|20,290|56.44%|5,150|
|w0_war_prep7|metal|52,412|90.47%|4,997|
|w0_war_prep7|alchemy|47,415|71.15%|3,994|
|w7_control|textile|28,653|81.27%|5,367|
|w7_control|leather|20,100|56.19%|5,162|
|w7_control|metal|51,571|90.31%|4,998|
|w7_control|alchemy|46,573|70.70%|3,994|
|w7_war_prep7|textile|29,023|81.69%|5,315|
|w7_war_prep7|leather|20,290|56.44%|5,150|
|w7_war_prep7|metal|52,412|90.47%|4,997|
|w7_war_prep7|alchemy|47,415|71.15%|3,994|
|w14_control|textile|28,653|81.27%|5,367|
|w14_control|leather|20,100|56.19%|5,162|
|w14_control|metal|51,571|90.31%|4,998|
|w14_control|alchemy|46,573|70.70%|3,994|
|w14_war_prep7|textile|29,023|81.69%|5,315|
|w14_war_prep7|leather|20,290|56.44%|5,150|
|w14_war_prep7|metal|52,412|90.47%|4,997|
|w14_war_prep7|alchemy|47,415|71.15%|3,994|
|w14_war_mint|textile|29,023|81.69%|5,315|
|w14_war_mint|leather|20,290|56.44%|5,150|
|w14_war_mint|metal|52,412|90.47%|4,997|
|w14_war_mint|alchemy|47,415|71.15%|3,994|
|w14_war_no_prep|textile|29,029|81.67%|5,321|
|w14_war_no_prep|leather|20,290|56.44%|5,150|
|w14_war_no_prep|metal|52,407|90.48%|4,990|
|w14_war_no_prep|alchemy|47,417|71.15%|3,995|
|w14_war_70_30|textile|29,041|81.70%|5,316|
|w14_war_70_30|leather|20,290|56.44%|5,150|
|w14_war_70_30|metal|52,455|90.46%|5,003|
|w14_war_70_30|alchemy|47,451|71.14%|3,992|

## Campaign readiness and investment cash

|Scenario|Faction readiness gates met / 6 events per faction|Project capital paid|Unspent refund|
|---|---|---:|---:|
|w0_war_prep7|6/6 ; 6/6|40,000|32,288|
|w7_war_prep7|6/6 ; 6/6|40,000|32,288|
|w14_war_prep7|6/6 ; 6/6|40,000|32,288|
|w14_war_mint|6/6 ; 6/6|40,000|32,288|
|w14_war_no_prep|6/6 ; 6/6|40,000|32,288|
|w14_war_70_30|6/6 ; 6/6|40,000|32,228|

Investment rows model funded procurement and pro-rata unspent refund only. There is no operating revenue/dividend or verified NPC kill model; these are readiness gates, not world victory.

## Interpretation constraints

- Replayed Q30 cash does not consume modeled time or additional battle supplies; all repeat policies remain offline assumptions.
- Profession price quotes and raw quotes are fixed candidates. Cash cost basis is actual paid cost; raw executable opportunity profit stays UNKNOWN.
- First-sale ratio excludes resales; self-use is not counted as a sale. Inventory is not booked as copper wealth.
- Bound system medicine may satisfy personal demand but never project procurement; craft and guarantee contributions remain separate.
- Initial merchant cash is included in opening money. Project investments and treasury funding transfer money; procurement authorization mints exactly once.
- Finite raw supply is derived from a random actual tower lineup, but tower choice, win probability and four-unit drop are simulation assumptions.
- No new-player progression, advanced sealed-item market, dynamic price discovery, investment returns, persistent faction feedback, or actual news-driven participation measured.
- Read independent_audit.json for accounting checks; a passing audit is not economic approval.
