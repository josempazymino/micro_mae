set seed 20190220

forvalues bbb = 1/1000 {
	import delimited "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'.csv", clear
	
	cap: gen temp = real(invdqdp_int_sim)
	cap: gen invdQdp_int_sim = temp
	cap: drop temp
	cap: rename invdqdp_int_sim  invdQdp_int_sim
	cap: drop invdqdp_int_sim
	

	save "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'.dta", replace
}


*==============================================================================*
* baseline supply estimates
*==============================================================================*

forvalues bbb = 1/1000 {
	disp `bbb'
	local bseed = 20190220 + `bbb' 
	set seed `bseed'
	* trader level data
	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear

	* merge demand derivatives
	merge m:1 market_name week using "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'"
	keep if _m==3
	drop _m

	gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
	gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
	gen int_y_jt = p_cost_adj_jt +  int_q_own_adj


	disp `bbb'


		
		quietly: ivreg2 int_y_jt i.mkt_id i.week i.trader_id  (int_q_other_adj kgs_own_adj_week = S1_low S1_high S2 ///
		trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
		estadd local mkt "Yes"
		estadd local week "Yes"
		estadd local trader "Yes"
		estadd local traderIV "Yes"
		estadd local S2 "No"
		estadd local weighted "No"
		estadd ysumm 
		eststo nonconst_mc_noS2
		
		local omega_est = _b[int_q_other_adj ]
		local gamma_est = _b[kgs_own_adj_week ]

	
	clear 
	set obs 1
	gen bbb = `bbb'

	gen omega_est = `omega_est'
	gen gamma_est = `gamma_est'


	save "$temp/bootstrap/supply_est/supply_bootstrap_coeff_`bbb'", replace

}


*==============================================================================*
* combine all coefficients
*==============================================================================*

clear
forvalues bbb = 1/1000 {
	append using "$temp/bootstrap/supply_est/supply_bootstrap_coeff_`bbb'"
}
save "$temp/bootstrap/supply_est/supply_bootstrap_coeff", replace
forvalues bbb = 1/1000 {
	erase "$temp/bootstrap/supply_est/supply_bootstrap_coeff_`bbb'.dta"
}

*==============================================================================*
* baseline imposing omega==1
*==============================================================================*



forvalues bbb = 1/1000 {
	disp `bbb'
	local bseed = 20190220 + `bbb' 
	set seed `bseed'
	* trader level data
	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear

	* merge demand derivatives
	merge m:1 market_name week using "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'"
	keep if _m==3
	drop _m


	gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
	gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
	gen int_y_jt_omega1 = p_cost_adj_jt +  int_q_own_adj - int_q_other_adj


	disp `bbb'

		
		quietly: ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (kgs_own_adj_week = S1_low S1_high S2 ///
		trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
		local gamma_est = _b[kgs_own_adj_week ]

	clear 
	set obs 1
	gen bbb = `bbb'
	

	gen gamma_est = `gamma_est'
	


	save "$temp/bootstrap/supply_est/supply_bootstrap_coeff_o1_`bbb'", replace

}

*==============================================================================*
* combine all coefficients
*==============================================================================*
clear
forvalues bbb = 1/1000 {
	append using "$temp/bootstrap/supply_est/supply_bootstrap_coeff_o1_`bbb'"
}
save "$temp/bootstrap/supply_est/supply_bootstrap_coeff_o1", replace
forvalues bbb = 1/1000 {
	erase "$temp/bootstrap/supply_est/supply_bootstrap_coeff_o1_`bbb'.dta"
}



*==============================================================================*
* non-nested test
*==============================================================================*


set seed 20190220


forvalues bbb = 1/1000 {
	disp `bbb'
	local bseed = 20190220 + `bbb' 
	set seed `bseed'
	* trader level data
	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear

	* merge demand derivatives
	merge m:1 market_name week using "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'"
	keep if _m==3
	drop _m


	gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
	gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
	gen int_y_jt = p_cost_adj_jt +  int_q_own_adj
	
	gen y_collusion  = int_y_jt-int_q_other_adj
	gen y_cournot  = int_y_jt
	
	gen S1_amt = 2.222 * S1_low + 4.444 *  S1_high

	
	ivreg2 y_collusion  i.mkt_id i.week i.trader_id  S1_amt (kgs_own_adj_week =  S2 ///
		trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	cap local coll_amt_nonconst_full = _b[S1_amt ]
	
	ivreg2 y_cournot  i.mkt_id i.week i.trader_id  S1_amt (kgs_own_adj_week =  S2 ///
		trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	cap local cour_amt_nonconst_full = _b[S1_amt ]
	
	ivreg2 y_collusion  i.mkt_id i.week i.trader_id  S1_amt  if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	cap local coll_amt_const_full = _b[S1_amt ]	
		
	ivreg2 y_cournot  i.mkt_id i.week i.trader_id  S1_amt  if S2_trader==0 & S2==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	cap local cour_amt_const_full = _b[S1_amt ]
	

	disp `bbb'

	
	*==============================================================================*
	* save coefficients
	*==============================================================================*
	clear 
	set obs 1
	gen bbb = `bbb'
	
	cap gen coll_amt_nonconst_full = `coll_amt_nonconst_full'
	
	cap gen cour_amt_nonconst_full = `cour_amt_nonconst_full'
	
	cap gen coll_amt_const_full = `coll_amt_const_full'

	cap gen cour_amt_const_full = `cour_amt_const_full'
	
	
	save "$temp/bootstrap/supply_est/supply_bootstrap_coeff_nn_`bbb'", replace

}


clear
forvalues  bbb=1/1000 {
	append using "$temp/bootstrap/supply_est/supply_bootstrap_coeff_nn_`bbb'"
}
save  "$temp/bootstrap/supply_est/supply_bootstrap_coeff_nn", replace
forvalues  bbb=1/1000 {
	erase "$temp/bootstrap/supply_est/supply_bootstrap_coeff_nn_`bbb'.dta"
}


********************************************************************************
* baseline entry analysis
********************************************************************************


set seed 20190220
set matsize 10000

forvalues bbb = 1/1000 {
	disp `bbb'
	local bseed = 20190220 + `bbb'
	set seed `bseed'
	* trader level data
	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear

	merge m:1 market_name week using "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'"
	keep if _m==3
	drop _m


	gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
	gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
	gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

	gen kgs_S2_trader = kgs_own_adj if S2_trader==1
	bys market_name week: egen kgs_S2_traders = sum(kgs_S2_trader)
	replace kgs_S2_traders = 0 if kgs_S2_traders==.


	gen int_q_other_entry = int_q_other_adj*(kgs_S2_traders>0)


	gen int_y_jt_omega1 = int_y_jt-int_q_other_adj



	ivreg2 int_y_jt_omega1  i.mkt_id i.week i.trader_id  (int_q_other_entry kgs_own_adj_week = S1_low S1_high S2 ///
		trader_pS1low_week trader_pS1high_week trader_pS2_week S2_trader_block_offer_low S2_trader_block_offer_med S2_trader_block_offer_high) if S2_trader==0,    ///
		cluster(market_block) partial(i.mkt_id i.week i.trader_id)
	global omegaS2 = _b[int_q_other_entry]+1

		






	*==============================================================================*
	* save coefficeints
	*==============================================================================*
	clear 
	set obs 1
	gen bbb = `bbb'

	gen omegaS2 = $omegaS2
	label variable omegaS2 "Omega, jointly estimated imposing omega=1" 


	save "$temp/bootstrap/s2/S2_bootstrap_coeff_`bbb'", replace

}

clear
forvalues bbb = 1/1000 {
	append using "$temp/bootstrap/s2/S2_bootstrap_coeff_`bbb'"
}
save "$temp/bootstrap/s2/S2_bootstrap_coeff", replace

forvalues bbb = 1/1000 {
	erase "$temp/bootstrap/s2/S2_bootstrap_coeff_`bbb'.dta"
}




********************************************************************************
* entry heterogeneity
********************************************************************************

set seed 20190220
set matsize 10000
********************************************************************************
* Entrant's potential connection
********************************************************************************

use "$data/S2_pre.dta", clear  

sum e_profit_day, detail
local medprof = r(p50)
gen above_med_profit = 0 if e_profit_day!=.
replace above_med_profit = 1 if e_profit_day > `medprof' & e_profit_day!=.

keep block trader_id  market_name know_any above_med_profit

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
save "$temp/S2entrytype", replace

use "$data/take_up_full.dta", clear

*convert to offer-level results
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
save "$temp/S2ethnicitytype", replace


forvalues bbb = 1/1000 {
	disp `bbb'
	local bseed = 20190220 + `bbb'
	set seed `bseed'
	* trader level data
	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear
	
	merge m:1 market_name week using "$temp/bootstrap/derivative/mkt_week_derivatives_`bbb'"
	keep if _m==3
	drop _m


	gen int_q_own_adj = kgs_own_adj * invdQdp_int_sim
	gen int_q_other_adj = -kgs_other_adj * invdQdp_int_sim
	gen int_y_jt = p_cost_adj_jt +  int_q_own_adj

	gen kgs_S2_trader = kgs_own_adj if S2_trader==1
	bys market_name week: egen kgs_S2_traders = sum(kgs_S2_trader)
	replace kgs_S2_traders = 0 if kgs_S2_traders==.


	sort trader_id block
	merge m:1 trader_id block using "$temp/S2entrytype", gen(_s2trader)
	drop if _s2trader==2

	sort trader_id block
	merge m:1 trader_id block using "$temp/S2ethnicitytype", gen(_s2tradereth)
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
	
		
	collapse (mean) above_med_profit , by(trader_id)

	* trader connection
	merge 1:m trader_id using "$temp/S2entrytype"
	drop if _m==1
	drop _m

	* trader ethnicity
	merge m:1 trader_id block using "$temp/S2ethnicitytype"
	drop if _m==1
	drop _m


	replace know_any = 0 if know_any == .

	* instruments
	gen iv_know_high = know_any  if s2_offer == "high"
	gen iv_profit_high = above_med_profit  if s2_offer == "high"
	gen iv_maj_eth_high = maj_eth  if s2_offer == "high"

	keep if s2_offer == "high"
	cap drop market_name
	rename S2_market_name  market_name
	keep market_name iv_know_high iv_profit_high iv_maj_eth_high

	save "$temp/bootstrap/s2/s2iv`bbb'", replace
	restore


	* merge IV to main data
	merge m:1 market_name using "$temp/bootstrap/s2/s2iv`bbb'"


	replace iv_know_high = iv_know_high * S2
	replace iv_profit_high = iv_profit_high * S2
	replace iv_maj_eth_high = iv_maj_eth_high * S2



	cap drop int_q_other_entry
	gen int_q_other_entry = int_q_other_adj*(kgs_S2_traders>0)

	gen int_q_other_entry_know = int_q_other_entry * known_to_entrant
	gen int_q_other_entry_unknow = int_q_other_entry * (1- known_to_entrant)

	gen int_q_other_entry_aboveprof = int_q_other_entry * above_med_entrant
	gen int_q_other_entry_belowprof = int_q_other_entry * (1- above_med_entrant)

	gen int_q_other_entry_maj_eth = int_q_other_entry * maj_eth_entrant
	gen int_q_other_entry_min_eth = int_q_other_entry * (1- maj_eth_entrant)

	* dependent variable
	gen int_y_jt_omega1 = int_y_jt-int_q_other_adj
	


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



	*==============================================================================*
	* save coefficients
	*==============================================================================*
	clear 
	set obs 1
	gen bbb = `bbb'

	gen omegaS2_k = $omegaS2_k
	label variable omegaS2_k "Omega known, jointly estimated imposing omega=1" 
	gen omegaS2_u = $omegaS2_u
	label variable omegaS2_u "Omega unknown, jointly estimated imposing omega=1" 

	gen omegaS2_a = $omegaS2_a
	label variable omegaS2_a "Omega above, jointly estimated imposing omega=1" 
	gen omegaS2_b = $omegaS2_b
	label variable omegaS2_b "Omega below, jointly estimated imposing omega=1" 
	
	gen omegaS2_j = $omegaS2_j
	label variable omegaS2_j "Omega majority, jointly estimated imposing omega=1" 
	gen omegaS2_n = $omegaS2_n
	label variable omegaS2_n "Omega minority, jointly estimated imposing omega=1" 
	

	save "$temp/bootstrap/s2/S2_heter_bootstrap_coeff_`bbb'", replace

}

clear
forvalues bbb = 1/1000 {
	append using "$temp/bootstrap/s2/S2_heter_bootstrap_coeff_`bbb'"
}
save "$temp/bootstrap/s2/S2_heter_bootstrap_coeff", replace
forvalues bbb = 1/1000 {
	erase "$temp/bootstrap/s2/S2_heter_bootstrap_coeff_`bbb'.dta"
}
forvalues bbb = 1/1000 {
	erase "$temp/bootstrap/s2/s2iv`bbb'.dta"
}
