********************************************************************************
* Create baseline trader level data used for model bootstrap
********************************************************************************

forvalues bbb = 1/1000 {
local bseed = 20190220 + `bbb' 
set seed `bseed'

* sample trader-level data
use "$temp/trader_analysis_data_trim", clear
bsample, cluster(market_block)
save "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", replace
* construct market-level data
collapse (min) weighted_price_jt total_kgs_mkt , by(market_name week)

keep market_name week weighted_price_jt total_kgs_mkt
save "$temp/bootstrap/resample_data/market_analysis_data_trim_`bbb'", replace
outsheet using "$temp/bootstrap/resample_data/market_analysis_data_trim_`bbb'.csv", comma replace

}


********************************************************************************
* Create moments used for model bootstrap
********************************************************************************
forvalues bbb = 1/1000  {

	use "$temp/bootstrap/resample_data/trader_analysis_data_trim_`bbb'", clear

	keep if S2==0 // drop markets in entry experiment


	* weight = inverse of traders
	gen inv_num_traders = 1/num_traders

	* control variable
	gen control = 1-S1

	* mean price for each treatment group
	reg weighted_price_jt S1_low S1_high control [aweight=inv_num_traders], r cluster(market_block) nocons
	gen b_int_price_C_trader = _b[control]  
	gen b_int_price_S1_low_trader = _b[S1_low]
	gen b_int_price_S1_high_trader = _b[S1_high]


	collapse (min) S1_low S1_high b_int_price_* control ///
	(sum) total_kgs_adj  num_trans , by(market_name week)

	gen kg_per_trans = total_kgs_adj/num_trans

	* mean kilograms per transaction for each treatment group
	reg kg_per_trans control S1_low S1_high, nocons
	gen b_int_cdf_S1_low_mkt = _b[S1_low]
	gen b_int_cdf_S1_high_mkt = _b[S1_high]
	gen b_int_cdf_C_mkt = _b[control]
	gen varll_int_mktcdf = _se[S1_low]^2
	gen varhh_int_mktcdf = _se[S1_high]^2
	gen varcc_int_mktcdf = _se[control]^2


	bys market_name: egen maxtrans = max(num_trans)

	gen pct_HH = num_trans/maxtrans

	* mean transaction rate for each treatment group
	reg pct_HH control S1_low S1_high, nocons
	gen b_transcdf_S1_low_mkt = _b[S1_low]
	gen b_transcdf_S1_high_mkt = _b[S1_high]
	gen b_transcdf_C_mkt = _b[control]
	gen varll_mktcdf = _se[S1_low]^2
	gen varhh_mktcdf = _se[S1_high]^2
	gen varcc_mktcdf = _se[control]^2

	gen kgs_per_maxtrans = total_kgs_adj / maxtrans

	qui summ kgs_per_maxtrans if control==1
	local n1 = r(N)
	local v1 = r(mean)
	qui summ kg_per_trans if control==1
	local v2 = r(mean)
	gen covcc = 1/`n1' * (`v1'-`v2'*b_transcdf_C_mkt)

	qui summ kgs_per_maxtrans if S1_low==1
	local n1 = r(N)
	local v1 = r(mean)
	qui summ kg_per_trans if S1_low==1
	local v2 = r(mean)
	gen covll = 1/`n1' * (`v1'-`v2'*b_transcdf_S1_low_mkt)

	qui summ kgs_per_maxtrans if S1_high==1
	local n1 = r(N)
	local v1 = r(mean)
	qui summ kg_per_trans if S1_high==1
	local v2 = r(mean)
	gen covhh= 1/`n1' * (`v1'-`v2'*b_transcdf_S1_high_mkt)


	keep b_int_price_* b_int_cdf_* varll* varhh*  varcc* cov* b_transcdf_*
	keep if _n==1
	order b_int_price_C_trader b_int_price_S1_low_trader b_int_price_S1_high_trader  ///
		b_int_cdf_C_mkt    b_int_cdf_S1_low_mkt  b_int_cdf_S1_high_mkt   ///
		varcc_int_mktcdf   varll_int_mktcdf      varhh_int_mktcdf ///
		b_transcdf_S1_low_mkt b_transcdf_S1_high_mkt b_transcdf_C_mkt varll_mktcdf varhh_mktcdf varcc_mktcdf ///
		covcc covll covhh
		
	outsheet using "$temp/bootstrap/moments/quantity_moments_`bbb'.csv", comma replace


}


