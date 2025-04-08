
********************************************************************************
* read in demand and entry estimates
********************************************************************************

set seed 3442388

insheet using "$temp/entry_estimates.csv", comma clear
global mc_mu = mu_mc[1]
global fc_mu = mu_fc[1]
global mc_sigma = sigma_mc[1]
global fc_sigma = sigma_fc[1]
global mc_fc_rho = rho[1]

insheet using "$temp/general_demand_estimates.csv", comma clear
global mu = mu[1]
global sigma = sigma[1]
global delta = delta[1]

global numsim = 100

cap log close
log using "$logs/welfare.log", t replace

********************************************************************************
* supply parameters
********************************************************************************


use "$temp/supply_reg_data_omega1", clear



cap drop  mc_star 
cap drop c0

qui ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (kgs_own_adj_week = S1_low S1_high S2 ///
	trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
	cluster(market_block) partial(i.mkt_id i.week i.trader_id)
gen gamma_est = _b[kgs_own_adj_week]


gen mc_star = weighted_price_jt-markup_int_y_jt
gen c0 = mc_star - gamma_est * kgs_own_adj_week

keep if S2==0 // drop entry offer markets


preserve
tempfile tempmktwk
collapse (mean) weighted_price_jt, by(market_name week)
save `tempmktwk', replace
restore

gen c0last = mc_star - gamma_est * kgs_own_adj // get marginal cost intercepts
gen c0lastpos = max(0,c0last)


gen mc = c0
gen logmc =  log(mc)

qui summ mc if mc>0
global mc_lb = r(min)

replace logmc = log($mc_lb) if mc<0

* calculate variable profits for each trader/market/week
* because of non-constant MC, profits differ depending on market order; here, we use the last market of the week, but results are robust to other choices

gen last_profits = (weighted_price_jt*kgs_own_adj) - c0last*kgs_own_adj - 0.5*gamma_est*kgs_own_adj^2

* draw fixed costs conditional on marginal cost intercepts
gen mean_fc = $fc_mu + $mc_fc_rho * $fc_sigma / $mc_sigma * (logmc - $mc_mu)
gen sd_fc = sqrt($fc_sigma^2 * (1 - $mc_fc_rho^2))


gen trader_mkt_wk_id = _n


expand $numsim

gen cdfdraw = runiform()
* draw fixed cost from truncated conditional logN distribution (truncation: FC<variable profits; conditional on MC)
gen logfcdraw_last = mean_fc + sd_fc * invnormal(cdfdraw*(normal((log(last_profits)-mean_fc)/sd_fc)))

gen fc_sim_last = exp(logfcdraw_last)

gen fc_below_profits_last = fc_sim_last<last_profits
bys trader_mkt_wk_id: egen any_fc_below_profits_last = max(fc_below_profits_last)

replace fc_sim_last = last_profits if any_fc_below_profits_last==0
replace fc_sim_last = . if fc_sim_last > last_profits
gen total_profits_last = last_profits-fc_sim_last
gen profits_fraction_last = total_profits_last/last_profits

collapse (mean) fc_sim_last total_profits_last profits_fraction_last kgs_own_adj weighted_price_jt, by(market_name week trader_mkt_wk_id)

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

gen total_markup_last = (total_profits_last/kgs_own_adj)/weighted_price_jt

gen  profits_above_40k = total_profits_last>40000

summ fc_sim_last, d
summ total_profits_last, d
summ profits_fraction_last, d
summ total_markup_last,  d
summ total_markup_last [aweight=kgs_own_adj]
summ profits_above_40k


collapse (sum) total_profits_last (mean) cs_pmkt weighted_price_jt, by(market_name week)

preserve

local num_mkt_week = _N

gen collapser = 1
collapse (sum) total_profits_last cs_pmkt (mean) weighted_price_jt, by(collapser)

gen total_welfare_last_pmkt = total_profits_last+cs_pmkt
gen cs_frac_last_pmkt = cs_pmkt / total_welfare_last_pmkt

summ cs_frac_last_pmkt


gen total_welfare_last_pmkt_per = total_welfare_last_pmkt/`num_mkt_week'

di total_welfare_last_pmkt_per



restore


cap log close

********************************************************************************
* summarize counterfactual results
********************************************************************************



set seed 3442388
global numsim = 100


insheet using "$temp/competitive_surplus.csv", comma clear
global competitive_cs = v1
global competitive_varpi = v2

* read in counterfactual estimates
insheet using "$temp/omega_surplus.csv", comma clear
global omega00cs  = v1[1]
global omega01cs  = v2[1]
global omega02cs  = v3[1]
global omega03cs  = v4[1]
global omega04cs  = v5[1]
global omega05cs  = v6[1]
global omega06cs  = v7[1]
global omega07cs  = v8[1]
global omega08cs  = v9[1]
global omega09cs  = v10[1]
global omega10cs  = v11[1]
global omega00vpi  = v1[2]
global omega01vpi  = v2[2]
global omega02vpi  = v3[2]
global omega03vpi  = v4[2]
global omega04vpi  = v5[2]
global omega05vpi  = v6[2]
global omega06vpi  = v7[2]
global omega07vpi  = v8[2]
global omega08vpi  = v9[2]
global omega09vpi  = v10[2]
global omega10vpi  = v11[2]

* read in counterfactual with exit) estimates
insheet using "$temp/omega_exit_surplus.csv", comma clear
egen meanrow =  rowmean(v1-v10)
global exitcs =  meanrow[1]
global exittpi = meanrow[2]


use "$temp/supply_reg_data_omega1", clear

keep if S2==0


gen gamma_est = (mc_star-c0)/kgs_own_adj_week

gen c0last = mc_star - gamma_est * kgs_own_adj
gen c0lastpos = max(0,c0last)

gen mc = c0
gen logmc =  log(mc)

qui summ mc if mc>0
global mc_lb = r(min)

replace logmc = log($mc_lb) if mc<0

gen last_profits_posc = (weighted_price_jt*kgs_own_adj) - c0lastpos*kgs_own_adj - 0.5*gamma_est*kgs_own_adj^2

gen mean_fc = $fc_mu + $mc_fc_rho * $fc_sigma / $mc_sigma * (logmc - $mc_mu)
gen sd_fc = sqrt($fc_sigma^2 * (1 - $mc_fc_rho^2))

gen trader_mkt_wk_id = _n

expand $numsim

gen cdfdraw = runiform()


gen logfcdraw_last_posc = mean_fc + sd_fc * invnormal(cdfdraw*(normal((log(last_profits_posc)-mean_fc)/sd_fc)))
gen fc_sim_last_posc = exp(logfcdraw_last_posc)

gen fc_below_profits_last_posc = fc_sim_last_posc<last_profits_posc


bys trader_mkt_wk_id: egen any_fc_below_profits_last_posc = max(fc_below_profits_last_posc)

replace fc_sim_last_posc = last_profits_posc if any_fc_below_profits_last_posc==0
replace fc_sim_last_posc = . if fc_sim_last_posc > last_profits_posc


collapse (mean) fc_sim_last_pos, by(market_name week trader_mkt_wk_id)

collapse (sum) fc_sim_last_posc, by(market_name week)

local num_mkt_week = _N
gen collapser = 1
collapse (sum) fc_sim_last_posc, by(collapser)

gen total_welfare_competitive = $competitive_cs  + $competitive_varpi - fc_sim_last_posc

gen competitive_cs = $competitive_cs

expand 11
gen omega =  (_n-1)/10
replace omega =  .  if _n>11
gen IS_prc =  .
gen CS_prc = .
gen DWL_prc =  .
forvalues oo=1/10 {
	local oo1 = `oo'-1
	replace IS_prc = (${omega0`oo1'vpi}-fc_sim_last_posc)/total_welfare_competitive if _n==`oo'
	replace CS_prc = ${omega0`oo1'cs}/total_welfare_competitive if _n==`oo'
	replace DWL_prc = 1-IS_prc-CS_prc if _n==`oo'
}

forvalues oo=11/11 {
	replace IS_prc = (${omega10vpi}-fc_sim_last_posc)/total_welfare_competitive if _n==`oo'
	replace CS_prc = ${omega10cs}/total_welfare_competitive if _n==`oo'
	replace DWL_prc = 1-IS_prc-CS_prc if _n==`oo'
}

**** Create Figure 9:


graph twoway (line IS_prc omega, sort lcolor(black) lpattern(longdash)) ///
(line CS_prc omega, sort lcolor(black)) ///
(line DWL_prc omega, sort lcolor(black) lpattern(shortdash)) , ///
  legend(label(1 "TS") label(2 "CS") label(3 "DWL") rows(2) pos(7) ring(0) region(lcolor(white)) bmargin(medlarge) ) ///
  ytitle("% of Surplus",angle(horizontal))  ylabel(,nogrid angle(horizontal)) bgcolor(white) graphregion(color(white)) xtitle("")  ///
    xline(0, lcolor(gs10) lpattern(shortdash)) xline(1, lcolor(gs10) lpattern(shortdash)) ///
	xlabel(0 "Cournot"  1 "Collusive") xscale(range(0.2)) scheme(s1mono)  xscale(range(0 1.1)) 
graph export "$output_figure/omega_counterfact_omega1.png", replace 
graph export "$output_figure/omega_counterfact_omega1.eps", replace 

gen welfare_per_mkt_wk = total_welfare_competitive/`num_mkt_week'

gen  tot_cs_cournot = ${omega00cs}
gen  tot_pi_cournot =  (${omega00vpi}-fc_sim_last_posc)

gen  tot_cs_cournot_exit =  $exitcs
gen  tot_pi_cournot_exit =  $exittpi

keep omega CS_prc IS_prc DWL_prc welfare_per_mkt_wk competitive_cs total_welfare_competitive tot_cs_cournot tot_pi_cournot tot_cs_cournot_exit tot_pi_cournot_exit

save "$temp/counterfactual_estimates", replace
