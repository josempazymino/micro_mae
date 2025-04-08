********************************************************************************
* prepare data for entry model
********************************************************************************


use "$data/S2_pre.dta", clear  
keep block trader_id  market_name know_any
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

gen know_any_low = know_any if s2_offer=="low"
gen know_any_med = know_any if s2_offer=="med"
gen know_any_high = know_any if s2_offer=="high"

collapse (min) know_any_low know_any_med know_any_high, by(market_name block)


tempfile S2entrytype
save `S2entrytype', replace


* recover supply side parameters (cost function)
local bseed = 20190220 
set seed `bseed'
* trader level data
use "$temp/trader_analysis_data_trim", clear

merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m



gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

gen int_y_jt_omega1 = int_y_jt - int_q_other_adj


ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
gen gamma_est = _b[kgs_own_adj_week]
gen cost_intercept = int_y_jt_omega1 - _b[kgs_own_adj_week]*kgs_own_adj_week

keep if S2==1

egen mkt_index = group(mkt_id)
egen week_index = group(week)
egen mkt_week_index = group(mkt_id week)

sort market_name week trader_id


qui summ mkt_week_index
local total_mkt_weeks = r(max)

preserve

keep mkt_index week_index mkt_week_index kgs_own_adj p_cost_adj_jt cost_intercept S2_trader gamma_est
order mkt_index week_index mkt_week_index cost_intercept kgs_own_adj S2_trader p_cost_adj_jt gamma_est

outsheet using "$temp/S2_CF_data.csv", comma replace // data for entry model

restore

replace S2_market = "eshisiro" if S2_market=="eshitinji(eshisiro)"
replace S2_market = "ogalo" if S2_market=="buhuyi (ogalo)"
gen entry_market_match = (S2_market==market_name)
replace S2_low = 0 if S2_low==1 & entry_market_match==0
replace S2_med = 0 if S2_med==1 & entry_market_match==0
replace S2_high = 0 if S2_high==1 & entry_market_match==0

save "$temp/S2_data_for_boot", replace

********************************************************************************
* entry model moments
********************************************************************************

preserve 

qui summ S2_low
local n_S2_low = r(sum)

qui summ S2_med
local n_S2_med = r(sum)

qui summ S2_high
local n_S2_high = r(sum)

gen entry_prob_low = `n_S2_low'/`total_mkt_weeks'
gen entry_prob_med = `n_S2_med'/`total_mkt_weeks'
gen entry_prob_high = `n_S2_high'/`total_mkt_weeks'

gen cost_intercept_low = cost_intercept*entry_prob_low if S2_low==1
gen cost_intercept_med = cost_intercept*entry_prob_med if S2_med==1
gen cost_intercept_high = cost_intercept*entry_prob_high if S2_high==1

gen counter = 1
collapse (mean) cost_intercept_* entry_prob_*, by(counter)

keep  entry_prob_low entry_prob_med entry_prob_high cost_intercept_low cost_intercept_med cost_intercept_high
order  entry_prob_low entry_prob_med entry_prob_high cost_intercept_low cost_intercept_med cost_intercept_high


outsheet using "$temp/S2_mc_fc_moments.csv", comma replace

restore

********************************************************************************
* data on potential entrants
********************************************************************************

preserve

sort market_name block
merge n:1 market_name block using `S2entrytype'
drop if _m==2

gen cost_intercept_low = cost_intercept if S2_low==1
gen cost_intercept_med = cost_intercept if S2_med==1
gen cost_intercept_high = cost_intercept if S2_high==1

collapse (min) know_any_low know_any_med know_any_high (max) S2_low S2_med S2_high cost_intercept_low cost_intercept_med cost_intercept_high, by(mkt_week_index)

replace cost_intercept_low = 0 if cost_intercept_low==.
replace cost_intercept_med = 0 if cost_intercept_med==.
replace cost_intercept_high = 0 if cost_intercept_high==.

replace know_any_low = 0 if know_any_low==.
replace know_any_med = 0 if know_any_med==.
replace know_any_high = 0 if know_any_high==.



outsheet using "$temp/S2_potential_entrant_types_name.csv", comma replace
restore

********************************************************************************
* bootstrap
********************************************************************************

forvalues bbb = 1/1000 {
local bseed = 20190810 + `bbb' 
set seed `bseed'

use "$temp/S2_data_for_boot", clear
bsample, cluster(market_block) idcluster(mkt_week_index_boot)
collapse (min) mkt_week_index, by(mkt_week_index_boot)
cou
order mkt_week_index_boot
save "$temp/bootstrap/resample_data/S2_model_boot_`bbb'", replace
outsheet using  "$temp/bootstrap/resample_data/S2_model_boot_`bbb'.csv",  comma replace

}




