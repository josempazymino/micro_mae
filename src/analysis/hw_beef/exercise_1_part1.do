/*

Runs supply regression for steers (good!), cows (depends on future prices) and total (good!)
Depends on demand_regression.do

price_export_ime_agg -> from INAC
price_export_market_index_cw -> from TRADEMAP
	
*/

capture cls
capture log close 
clear mata 
clear matrix
clear
*set mem 5G
set more off
set linesize 120
* Apparently, matsize is not recoreded permanently on some systems.
set matsize 800
include project_paths

* Load monthly data (same as the one used for structural model)
insheet using `"${PATH_OUT_ANALYSIS_BEEF}/main_data_beef.csv"', clear 
save `"${PATH_OUT_ANALYSIS_BEEF}/main_data_beef.dta"',replace 


gen log_domestic = log(domestic_hook_csh)
gen log_pbutcher = log(p_average_butcher_cs)
gen log_lamb     = log(p_lamb_hook)
gen log_pigs     = log(p_pigs_hook)
gen log_pcalves  = log(price_calves140)
gen log_gdp      = log(uy_gdp_percapita)

gen log_pcalves_turkey   = log_pcalves*dummy_turkey
gen log_pcalves_noturkey = log_pcalves*(1-dummy_turkey)

*******************************
** PART 1: DEMAND ESTIMATION **
*******************************

* levels *
ivreg2 domestic_hook_csh p_average_butcher_cs trend uy_gdp_percapita p_lamb_hook p_pigs_hook 

ivreg2 domestic_hook_csh trend uy_gdp_percapita p_lamb_hook p_pigs_hook  ///
	    (p_average_butcher_cs = price_calves140) 

ivreg2 domestic_hook_csh trend uy_gdp_percapita p_lamb_hook p_pigs_hook  ///
	    (p_average_butcher_cs = p_average_hook_csh) 

ivreg2 domestic_hook_csh trend uy_gdp_percapita p_lamb_hook p_pigs_hook  ///
	    (p_average_butcher_cs = p_average_hook_csh dummy_turkey) 

ivreg2 domestic_hook_csh trend uy_gdp_percapita p_lamb_hook p_pigs_hook  ///
	    (p_average_butcher_cs = price_calves140 dummy_turkey) 		
		
* logs

ivreg2 log_domestic log_pbutcher trend log_gdp log_lamb log_pigs 

ivreg2 log_domestic trend log_gdp log_lamb log_pigs   ///
	    (log_pbutcher  = log_pcalves) 

ivreg2 log_domestic trend log_gdp log_lamb log_pigs   ///
	    (log_pbutcher  = log_pcalves_turkey log_pcalves_noturkey) 

		
*******************************
** PART 2: SUPPLY ESTIMATION **
*******************************
		

		
		
