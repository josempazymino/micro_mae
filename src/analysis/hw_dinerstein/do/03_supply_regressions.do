********************************************************************************
* supply analysis
********************************************************************************


* read in demand derivatives
import delimited "$temp/mkt_week_derivatives.csv", clear

cap: gen temp = real(invdqdp_int_sim)
cap: gen invdQdp_int_sim = temp
cap: drop temp
cap: rename invdqdp_int_sim  invdQdp_int_sim
cap: drop invdqdp_int_sim

save "$temp/mkt_week_derivatives.dta", replace


********************************************************************************
* baseline supply estimates
********************************************************************************
local bseed = 20190220 
set seed `bseed'
* trader level data
use "$temp/trader_analysis_data_trim", clear

* merge demand derivatives
merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m

gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt = p_cost_adj_jt +  int_q_own_adj


	
	quietly: ivreg2 int_y_jt  i.mkt_id i.week i.trader_id  (int_q_other_adj kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	local omega_hat = _b[int_q_other_adj ]
	local gamma_hat = _b[kgs_own_adj_week ]


save "$temp/supply_reg_data", replace

preserve
gen omega_hat = `omega_hat'
gen gamma_hat = `gamma_hat'
keep omega_hat gamma_hat
keep if _n==1

outsheet using "$temp/general_supply_estimates.csv", replace comma
restore



********************************************************************************
* baseline supply estimates, imposing omega==1
********************************************************************************
local bseed = 20190220 
set seed `bseed'
* trader level data
use "$temp/trader_analysis_data_trim", clear

* merge demand derivatives
merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m

gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt_omega1 = p_cost_adj_jt +  int_q_own_adj - int_q_other_adj



	
	ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)

	
	local gamma_hat = _b[kgs_own_adj_week ]



* demand elasticity	
gen demand_elast = (1/invdQdp_int_sim)*(weighted_price_adj_trim)/(kgs_own_adj+kgs_other_adj)

sort market_name week

summ demand_elast if market_name!=market_name[_n-1] | week!=week[_n-1], d

* mark up
gen markup_int_y_jt = -int_q_own_adj + 1 * int_q_other_adj
gen p_markup_int_y_jt = markup_int_y_jt/weighted_price_jt

* profit
gen mc_star = weighted_price_jt-markup_int_y_jt
gen c0 = mc_star - `gamma_hat' * kgs_own_adj_week
gen profit_in = (weighted_price_jt*kgs_own_adj) - c0*kgs_own_adj

save "$temp/supply_reg_data_omega1", replace

preserve
gen gamma_hat = `gamma_hat'
keep gamma_hat
keep if _n==1

outsheet using "$temp/general_supply_estimates_omega1.csv", replace comma
restore



********************************************************************************
* baseline entry estimates
********************************************************************************

set matsize 5000
local bseed = 20190220 
set seed `bseed'
* trader level data
use "$temp/trader_analysis_data_trim", clear

* merge demand derivatives
merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m

gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

gen kgs_S2_trader = kgs_own_adj if S2_trader==1
bys market_name week: egen kgs_S2_traders = sum(kgs_S2_trader)
replace kgs_S2_traders = 0 if kgs_S2_traders==.


gen int_q_other_entry = int_q_other_adj*(kgs_S2_traders>0)
gen int_y_jt_origomega1 = int_y_jt-int_q_other_adj

ivreg2 int_y_jt_origomega1  i.mkt_id i.week i.trader_id  (int_q_other_entry kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
global omegaS2 = _b[int_q_other_entry]+1



gen omegaS2 = $omegaS2

save "$temp/S2_effects", replace



set mat 10000
********************************************************************************
* entry estimates, heterogeneous effects
********************************************************************************

use "$data/S2_pre.dta", clear  

* size (above/below median in profits) and whether the trader has connections

sum e_profit_day, detail
local medprof = r(p50)
gen above_med_profit = 0 if e_profit_day!=.
replace above_med_profit = 1 if e_profit_day > `medprof' & e_profit_day!=.

keep block trader_id  market_name know_any above_med_profit
ren  market_name S2_pre_market_name
destring trader_id  , replace
tempfile tempS2connection
save `tempS2connection', replace

use "$data/S2_offers_2016_05_30.dta", clear
rename S2_block block
rename S2_offer s2_offer

replace market_name = "eshisiro" if market_name == "eshitinji(eshisiro)"
replace market_name = "ogalo" if market_name == "buhuyi (ogalo)"
replace market_name = "lugari station" if market_name == "lugari center(lugari station)"

keep block trader_id s2_offer market_name
ren market_name S2_market_name
sort trader_id block
assert trader_id!=trader_id[_n-1] | block!=block[_n-1]
destring trader_id block, replace
sort trader_id block
merge 1:1 block trader_id    using `tempS2connection'
drop _m

tempfile S2entrytype
save `S2entrytype', replace


*** ethnicity

use "$data/take_up_full.dta", clear

keep block market_name S2_offer trader_id
duplicates drop
tostring trader_id, replace

*bring in S2 trader ethnicity
merge m:1 trader_id using "$data/S2_ethnicity2.dta"
drop if _m == 2
drop _m
rename e_1 S2trader_ethnicity
gen minority = 0 if S2trader_ethnicity == 2
replace minority = 1 if S2trader_ethnicity!=. & S2trader_ethnicity != 2

*bring in market ethnicity info
replace market_name ="ogalo" if market_name == "buhuyi (ogalo)"
replace market_name ="eshisiro" if market_name == "eshitinji(eshisiro)"
replace market_name ="lugari station" if market_name == "lugari center(lugari station)"
merge m:1 market_name using "$data/market_ethnic.dta"
drop if _m == 2
drop _m

gen any_own_eth = 0 if S2trader_ethnicity!=.
gen prc_own_eth = 0 if S2trader_ethnicity!=.
foreach x in 1 2 3 4 5 7 {
replace any_own_eth = 1 if S2trader_ethnicity == `x' & any_eth`x' == 1
replace prc_own_eth = prct_eth`x' if S2trader_ethnicity == `x'
drop any_eth`x' prct_eth`x'
}
destring trader_id, replace
gen maj_eth = prc_own_eth>=.5

sort trader_id block
keep  trader_id block maj_eth
tempfile tempeth
save `tempeth', replace

local bseed = 20190220 
set seed `bseed'
* trader level data
use "$temp/trader_analysis_data_trim", clear

* merge demand derivatives
merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m

gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

gen kgs_S2_trader = kgs_own_adj if S2_trader==1
bys market_name week: egen kgs_S2_traders = sum(kgs_S2_trader)
replace kgs_S2_traders = 0 if kgs_S2_traders==.

gen int_q_other_nonS2trader_adj = -(kgs_other_adj-kgs_S2_traders)*invdQdp_int_sim
gen int_q_S2trader = -kgs_S2_traders*invdQdp_int_sim

*==============================================================================*
* entrant's connection to incumbent traders
*==============================================================================*
sort trader_id block
merge m:1 trader_id block using `S2entrytype', gen(_s2trader)
drop if _s2trader==2

sort trader_id block
merge m:1 trader_id block using `tempeth', gen(_s2tradereth)
drop if _s2tradereth==2

replace know_any = 0 if know_any == .
* market week's entrant type
bys market_name week: egen known_to_entrant = max(know_any*(kgs_S2_traders>0)* (S2_trader==1))
bys market_name week: egen above_med_entrant = max(above_med_profit*(kgs_S2_traders>0)* (S2_trader==1))
bys market_name week: egen maj_eth_entrant = max(maj_eth*(kgs_S2_traders>0)* (S2_trader==1))

bys market_name week: egen unknown_to_entrant = max((1-know_any)*(kgs_S2_traders>0)* (S2_trader==1))
bys market_name week: egen below_med_entrant = max((1-above_med_profit)*(kgs_S2_traders>0)* (S2_trader==1))
bys market_name week: egen min_eth_entrant = max((1-maj_eth)*(kgs_S2_traders>0)* (S2_trader==1))

preserve
* trader size
collapse (mean) above_med_profit , by(trader_id)

* trader connection
merge 1:m trader_id using `S2entrytype'
drop if _m==1
drop _m

* trader ethnicity
merge m:1 trader_id block using `tempeth'
drop if _m==1
drop _m


replace know_any = 0 if know_any == .

* construct instruments
gen iv_know_high = know_any  if s2_offer == "high"
gen iv_profit_high = above_med_profit  if s2_offer == "high"
gen iv_maj_eth_high = maj_eth  if s2_offer == "high"

keep if s2_offer == "high"
cap drop market_name
rename S2_market_name  market_name
keep market_name iv_know_high iv_profit_high iv_maj_eth_high

tempfile s2iv 
save `s2iv', replace

restore

* merge IV to main data
merge m:1 market_name using `s2iv'

replace iv_know_high = iv_know_high * S2
replace iv_profit_high = iv_profit_high * S2
replace iv_maj_eth_high = iv_maj_eth_high * S2


* entrant's kgs
cap drop int_q_other_entry
gen int_q_other_entry = int_q_other_adj*(kgs_S2_traders>0)

gen int_q_other_entry_know = int_q_other_entry * known_to_entrant
gen int_q_other_entry_unknow = int_q_other_entry * (1- known_to_entrant)

gen int_q_other_entry_aboveprof = int_q_other_entry * above_med_entrant
gen int_q_other_entry_belowprof = int_q_other_entry * (1- above_med_entrant)

gen int_q_other_entry_maj_eth = int_q_other_entry * maj_eth_entrant
gen int_q_other_entry_min_eth = int_q_other_entry * (1- maj_eth_entrant)


gen int_y_jt_omega1 = int_y_jt-int_q_other_adj


*------------------------------------------------------------------------------*
* entrant size and connection
*------------------------------------------------------------------------------*


* - by connection

ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  ///
	(int_q_other_entry_know int_q_other_entry_unknow  kgs_own_adj_week = ///
	iv_know_high S1_low S1_high S2  ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week   ///
	S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high)  ///
	if S2_trader==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
global omegaS2_k = _b[int_q_other_entry_know]+1
global omegaS2_u = _b[int_q_other_entry_unknow]+1

gen omegaS2_k = $omegaS2_k
gen omegaS2_u = $omegaS2_u



* - by size (profits)

ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  ///
	(int_q_other_entry_aboveprof int_q_other_entry_belowprof  kgs_own_adj_week = ///
	iv_profit_high S1_low S1_high S2  ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week   ///
	S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high)  ///
	if S2_trader==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
global omegaS2_a = _b[int_q_other_entry_aboveprof]+1
global omegaS2_b = _b[int_q_other_entry_belowprof]+1

gen omegaS2_a = $omegaS2_a
gen omegaS2_b = $omegaS2_b


* - by ethnicity match

ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  ///
	(int_q_other_entry_maj_eth int_q_other_entry_min_eth  kgs_own_adj_week = ///
	iv_maj_eth_high S1_low S1_high S2  ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week   ///
	S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high)  ///
	if S2_trader==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
global omegaS2_j = _b[int_q_other_entry_maj_eth]+1
global omegaS2_n = _b[int_q_other_entry_min_eth]+1

gen omegaS2_j = $omegaS2_j
gen omegaS2_n = $omegaS2_n


keep market_name week trader_id know_any S2_trader omegaS2_*

save "$temp/S2_heterogeneous_effects", replace

