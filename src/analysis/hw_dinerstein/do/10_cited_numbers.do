******** NUMBERS MENTIONED IN PAPER *****************

cap log close
log using "$logs/cited_numbers.log", t replace

** Calculate demand elasticity from general model (Section 6.1)

use "$temp/supply_reg_data_omega1", clear

sort market_name week
summ demand_elast if market_name!=market_name[_n-1] | week!=week[_n-1]

** Calculate trader markups

use "$temp/supply_reg_data_omega1", clear

summ p_markup_int_y_jt, d

gen gamma = (mc_star-c0)/kgs_own_adj_week
collapse (count) mkt_id (sum) profit_in* (mean) kgs_own_adj_week gamma, by(trader_id week)
ren mkt_id num_mkt

gen profit_wk_per_mkt = (profit_in - (gamma/2) * kgs_own_adj_week^2)/num_mkt

summ profit_wk_per_mkt, d

** Calculate division of surplus

* mean/median daily fixed costs for incumbents: see welfare.log

* dissipitation of profits due to FC:  see welfare.log

* estimated daily profit:  see welfare.log

* percentage of revenue kept as profit:  see welfare.log
* quantity-weighted:  see welfare.log

* consumer surplus and trader surplus as fraction of total surplus:  see welfare.log

* CS (fraction) 95% confidence interval

insheet using  "$temp/bootstrap/s2/entry_bootstrap_estimates.csv", comma clear
gen noconverge = (v1==-1000)
gen bbb=_n
keep bbb noconverge
tempfile tempboot
save `tempboot',  replace


use "$temp/cs_estimates_boot", clear
sort bbb
merge 1:1 bbb using `tempboot'
assert _m==3
drop _m

keep if noconverge==0
local NB = _N
local lb = floor(`NB'*.025)
local ub = ceil(`NB'*(1-.025))
sort cs_frac_last_pmkt
local lower95 = cs_frac_last_pmkt[`lb']
local upper95 = cs_frac_last_pmkt[`ub']

di "The 95% confidence interval is (`lower95' ,`upper95')"

* mean surplus per market-day: see BL14_estimate_fc_in_S1_iter_omega1.do (di total_welfare_last_pmkt_per)

* percent with daily profits over 40,000: see BL14_estimate_fc_in_S1_iter_omega1.do (summ profits_above_40k)

* CF: Cournot vs. collusion

use "$temp/counterfactual_estimates", clear

summ CS_prc if omega==0
local CS0 = r(mean)
summ IS_prc if omega==0
local IS0 = r(mean)
summ DWL_prc if omega==0
local DWL0 = r(mean)

summ CS_prc if omega==1
local CS1 = r(mean)
summ IS_prc if omega==1
local IS1 = r(mean)
summ DWL_prc if omega==1
local DWL1 = r(mean)

* calculate ratios
di "Moving from joint profit maximization to collusion would cause CS to increase by a factor of" `CS0'/`CS1'
di "Moving from joint profit maximization to collusion would cause DWL to decrease by a factor of" `DWL0'/`DWL1'
di "Moving from joint profit maximization to collusion would cause DWL to decrease by" 1-`DWL0'/`DWL1'

summ welfare_per_mkt_wk

di "The change in CS per market-day would be:" welfare_per_mkt_wk[1]*(`CS0'-`CS1')
di "The change in IS per market-day would be:" welfare_per_mkt_wk[1]*(`IS1'-`IS0')
di "The change in DWL per market-day would be:" welfare_per_mkt_wk[1]*(`DWL1'-`DWL0')

* using exchange rate of 0.0093 USD per Ksh
local exchange_rate = 0.0093

di "The USD change in CS per market-day would be:" welfare_per_mkt_wk[1]*(`CS0'-`CS1')*`exchange_rate'
di "The USD change in IS per market-day would be:" welfare_per_mkt_wk[1]*(`IS1'-`IS0')*`exchange_rate'
di "The USD change in DWL per market-day would be:" welfare_per_mkt_wk[1]*(`DWL1'-`DWL0')*`exchange_rate'


* perfect competition

gen cs_pc = competitive_cs/total_welfare_competitive
summ cs_pc

di "Moving from joint profit maximization to pricing at cost would increase total surplus by" `DWL1'/(1-`DWL1')


* Exit CF

gen cs_exit_frac = tot_cs_cournot_exit/tot_cs_cournot
gen pi_exit_frac = tot_pi_cournot_exit/tot_pi_cournot

summ cs_exit_frac if omega==0
local cs_exit_frac = r(mean)
summ pi_exit_frac if omega==0
local pi_exit_frac = r(mean)

di "Under a model with exit, we estimate trader profits increase by the fraction:" `pi_exit_frac'


** Entrants' estimated costs

insheet using "$temp/entry_estimates.csv", comma clear
local mu_MC_est = mu_mc[1]
local mu_FC_est = mu_fc[1]
local sigma_MC_est = sigma_mc[1]
local sigma_FC_est = sigma_fc[1]
local rho_est = rho[1]

gen mean_mc = exp(`mu_MC_est'+0.5*`sigma_MC_est'^2)
gen mean_fc = exp(`mu_FC_est'+0.5*`sigma_FC_est'^2)

summ mean_mc 
summ mean_fc

* Conditional (on entry), no subsidy marginal and fixed cost means
* see '../temp/mc_fc_estimates.mat' (mc_conditional_nosub, fc_conditional_nosub)

** Calculate non-nested test p-values

use "$temp/bootstrap/supply_est/supply_bootstrap_coeff_nn", clear
count if coll_amt_nonconst_full < 0
count if cour_amt_nonconst_full < 0
count if coll_amt_const_full < 0
count if cour_amt_const_full < 0


** Calculate entry effect relative to mean and median market sizes

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

*make number of traders zero for markets in which don't have hourly data (these were marekts without traders)
merge m:1 market_date using "$data/full_market_dates.dta"
foreach x in num_traders num_traders_incumbent {
replace `x' = 0 if _m == 2
replace `x'_trim = 0 if _m == 2
}
replace num_traders_inv = 1 if _m == 2
drop _m

*bring in any take up results
merge m:1 market_name week using "$data/mkt_any_takeup_day.dta"
replace any_takeup_that_day = 0 if _m != 3
drop _m

xi: reg num_entrants i.week i.market_name S2 if S1!=1 & weighted_price_adj_trim!=. [aweight=num_traders_inv] , r cluster(market_block) 
local beta_entry = _b[S2]
summ num_traders_incumbent if S1!=1 & weighted_price_adj_trim!=. [aweight=num_traders_inv], d
local mean_traders = r(mean)
local median_traders = r(p50)

di "The entry effect as a fraction of the mean is:" `beta_entry'/`mean_traders'
di "The entry effect as a fraction of the median is:" `beta_entry'/`median_traders'


** Calculate entry offer take-up rates by prior connections

use "$data/take_up_full.dta", clear

*convert to offer-level results
bysort trader_id block: egen num_takeup = sum(takeup)
gen any_takeup = (num_takeup>0)
keep block market_name S2_offer trader_id any_takeup num_takeup
duplicates drop
tostring trader_id, replace

*bring in trader ethnicity
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

gen prc_own_eth = 0 if S2trader_ethnicity!=.
foreach x in 1 2 3 4 5 7 {
replace prc_own_eth = prct_eth`x' if S2trader_ethnicity == `x'
drop any_eth`x' prct_eth`x'
}

merge 1:1 trader_id block using "$data/S2_pre.dta"

gen offer_given = 1 if _m == 3
replace offer_given = 0 if _m == 1
drop _m
drop s2_offer

gen offer_med = (S2_offer == "med")
gen offer_high = (S2_offer == "high")

gen offer_amount = 5000 if S2_offer == "low"
replace offer_amount = 10000 if S2_offer == "med"
replace offer_amount = 15000 if S2_offer == "high"
replace offer_amount = offer_amount/ 1000
label var offer_amount "Offer amt (thous)"


reg any_takeup know_any, cluster(trader_id)


** Quantify magnitude of cost slope

insheet using "$temp/general_supply_estimates_omega1.csv", clear comma
local gamma_omega1_bar = gamma_hat[1]

use "$temp/supply_reg_data_omega1", clear

sort trader_id week
summ kgs_own_adj_week if trader_id!=trader_id[_n-1] | week!=week[_n-1]
local sd_kgs_week = r(sd)

gen sd_cost_increase = `gamma_omega1_bar'*`sd_kgs_week'
summ sd_cost_increase

summ c0, d

** Entry rates by market

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

merge m:1 market_date using "$data/full_market_dates.dta"
foreach x in num_traders num_traders_incumbent {
replace `x' = 0 if _m == 2
replace `x'_trim = 0 if _m == 2
}
replace num_traders_inv = 1 if _m == 2
drop _m

merge m:1 market_name week using "$data/mkt_any_takeup_day.dta"
replace any_takeup_that_day = 0 if _m != 3
drop _m

preserve
keep if S2==1
collapse (max) any_takeup_that_day, by(market_name week)
tab any_takeup_that_day
restore

preserve
keep if S2==1
collapse (max) any_takeup_that_day, by(market_name block)
tab any_takeup_that_day
restore

gen multiple_entrants = (tot_takeup_that_day>1)
preserve
keep if S2==1
collapse (max) multiple_entrants any_takeup_that_day, by(market_name week)
tab multiple_entrants if any_takeup_that_day==1
restore

** DW initial quantities and prices

use "$data/DW_cleaned_plus_custnum.dta", clear

label var subsidy "Subsidy/kg" 
label var new_amount_trim "Post Q" 
label var old_amount_trim "Prior Q" 
label var price_trim "Prior P"  
gen post_price_trim = price_trim - subsidy
label var post_price_trim "Post P"
gen post_price = price - subsidy
label var new_amount "Post Q"  
label var old_amount "Prior Q" 
label var price "Prior P" 
label var post_price "Post P"

summ old_amount_trim
summ price_trim

/***  Re-estimate omega after dropping entrants ***/

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear
gen S1_entrant = 0 if S2 != 1 & how_often!=.
replace S1_entrant = 1 if how_often == 4
collapse (max) S1_entrant, by(market_name week trader_id )

tempfile tempentrants
save `tempentrants', replace

use "$temp/trader_analysis_data_trim", clear

merge m:1 market_name week using "$temp/mkt_week_derivatives"
assert _m==3
drop _m

sort  market_name week trader_id
merge  1:1  market_name week trader_id using `tempentrants'
assert _m!=1
drop if  _m==2
drop _m

gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

ivreg2 int_y_jt  i.mkt_id i.week i.trader_id  (int_q_other_adj kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0 & S1_entrant==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	
** Estimate omega in general model, excluding large markets with same-day neighbors (Appendix H)


use "$temp/supply_reg_data", clear


ivreg2 int_y_jt  i.mkt_id i.week i.trader_id  (int_q_other_adj kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0 ///
	& market_name!="malaha_(kakamega)" & market_name!="matisi_(kitale)",    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)


cap log close

