
********************************************************************************
* read in demand and entry estimates
********************************************************************************

set seed 3442388


insheet using "$temp/general_demand_estimates.csv", comma clear
global mu = mu[1]
global sigma = sigma[1]
global delta = delta[1]

global numsim = 100

insheet using  "$temp/bootstrap/s2/entry_bootstrap_estimates.csv", comma clear

ren v1 mc_mu
ren v2 fc_mu
ren v3 mc_sigma
ren v4 fc_sigma
ren v5 mc_fc_rho

tempfile tempbootestimates tempboot
save `tempbootestimates',  replace

preserve
drop if mc_mu==-1000
summ 
restore

********************************************************************************
* supply parameters
********************************************************************************



forvalues bbb=1/1000 {

use `tempbootestimates',  clear
keep if _n==`bbb'

global mc_mu = mc_mu
global fc_mu = fc_mu
global mc_sigma = mc_sigma
global fc_sigma = fc_sigma
global mc_fc_rho = mc_fc_rho


use "$temp/supply_reg_data_omega1", clear

cap drop  mc_star 
cap drop c0

qui ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
gen gamma_est = _b[kgs_own_adj_week]


gen mc_star = weighted_price_jt-markup_int_y_jt
gen c0 = mc_star - gamma_est * kgs_own_adj_week

keep if S2==0

preserve
tempfile tempmktwk
collapse (mean) weighted_price_jt, by(market_name week)
save `tempmktwk', replace
restore

gen c0last = mc_star - gamma_est * kgs_own_adj

gen mc = c0
gen logmc =  log(mc)

qui summ mc if mc>0
global mc_lb = r(min)

replace logmc = log($mc_lb) if mc<0
gen last_profits = (weighted_price_jt*kgs_own_adj) - c0last*kgs_own_adj - 0.5*gamma_est*kgs_own_adj^2

gen mean_fc = $fc_mu + $mc_fc_rho * $fc_sigma / $mc_sigma * (logmc - $mc_mu)
gen sd_fc = sqrt($fc_sigma^2 * (1 - $mc_fc_rho^2))

gen trader_mkt_wk_id = _n

expand $numsim

gen cdfdraw = runiform()

gen logfcdraw_last = mean_fc + sd_fc * invnormal(cdfdraw*(normal((log(last_profits)-mean_fc)/sd_fc)))

gen fc_sim_last = exp(logfcdraw_last)
gen fc_below_profits_last = fc_sim_last<last_profits
bys trader_mkt_wk_id: egen any_fc_below_profits_last = max(fc_below_profits_last)
replace fc_sim_last = last_profits if any_fc_below_profits_last==0
replace fc_sim_last = . if fc_sim_last > last_profits
gen total_profits_last = last_profits-fc_sim_last

collapse (mean) total_profits_last, by(market_name week trader_mkt_wk_id)

tempfile tempprofits

save `tempprofits', replace

********************************************************************************
* calculate consumer surplus
********************************************************************************


use "$data/WR Hourly Trader Survey cleaned_trans.dta", clear

merge n:1 market_name week using `tempmktwk'
assert _m!=2
keep if _m==3
drop _m

gen mean_a_pmkt = $mu + normalden((weighted_price_jt-${mu})/${sigma})/(1-normal((weighted_price_jt-${mu})/${sigma})) * $sigma

gen cs_pmkt = ${delta} / (1+${delta}) * amt_kg * (mean_a_pmkt-weighted_price_jt)

collapse (sum) cs_pmkt, by(market_name week)

merge 1:n market_name week using `tempprofits'
assert _m==3
drop _m


collapse (sum) total_profits_last (mean) cs_pmkt, by(market_name week)

gen collapser = 1
collapse (sum) total_profits_last cs_pmkt, by(collapser)

gen total_welfare_last_pmkt = total_profits_last+cs_pmkt
gen cs_frac_last_pmkt = cs_pmkt / total_welfare_last_pmkt



gen bbb =  `bbb'
keep bbb cs_frac_last_pmkt


if `bbb'>1 {
	append using `tempboot'
}
save `tempboot', replace

}
save "$temp/cs_estimates_boot", replace
