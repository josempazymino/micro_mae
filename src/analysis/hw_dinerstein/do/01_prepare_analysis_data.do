********************************************************************************
* Create baseline trader level data used for model
********************************************************************************
 
set seed 20190220

********************************************************************************
* read in entry experiment offers
********************************************************************************

use "$data/S2_offers_2016_05_30.dta", clear
rename S2_block block
rename S2_offer s2_offer
keep block trader_id s2_offer market_name
ren market_name S2_market_name
sort trader_id block
assert trader_id!=trader_id[_n-1] | block!=block[_n-1]

destring trader_id block, replace
sort trader_id block

tempfile tempS2pre
save `tempS2pre', replace

********************************************************************************
* trader level data
********************************************************************************
use "$data/WR Hourly Trader Survey cleaned_trader2", clear
sort market_name

drop if total_kgs_adj == 0 | total_kgs_adj == . | num_trans == 0 | num_trans == . | weighted_price_adj ==. | weighted_price_adj==0 // drop markets without transactions

duplicates drop market_name week trader_id  ///
total_kgs_adj_trim num_trans_trim weighted_price_adj_trim  ///
total_kgs_adj num_trans weighted_price_adj, force

replace total_kgs_adj  = . if weighted_price_adj ==.
replace num_trans  = . if weighted_price_adj ==.

collapse (sum) total_kgs_adj num_trans  ///
(mean) weighted_price_adj_trim  weighted_price_adj ///
(min) S1 S2 S1_low S1_high S2_trader   ///
, by(market_name trader_id week market_block)

bys market_name week : egen Q_tot_jt = total(total_kgs_adj) if weighted_price_adj !=.

gen kgs_own_adj = total_kgs_adj
gen kgs_other_adj =  (Q_tot_jt - total_kgs_adj) 

bys market_name week : gen num_traders = _N

egen  mkt_id = group(market_name)
sort trader_id market_name week

bys market_name week : egen weighted_price_jt = ///
sum(weighted_price_adj*total_kgs_adj/Q_tot_jt)  if weighted_price_adj!=.

gen p_cost_adj_jt = weighted_price_jt + 2.222 * S1_low + 4.444 *  S1_high // price minus cost shock from cost experiment

gen block = 1*(week>=12 & week<=15) + 2*(week>=17 & week<=20) + 3*(week>=22 & week<=25)

sort trader_id block
merge n:1 trader_id block using `tempS2pre'

drop if _m==2
drop _m

gen S2_high = (s2_offer=="high")
gen S2_med = (s2_offer=="med")
gen S2_low = (s2_offer=="low")

* construct trader IVs related to experimental status in all markets

* whether a trader has an entry offer
bys trader_id block: egen S2_trader_block_offer_high = max(S2_high)
bys trader_id block: egen S2_trader_block_offer_med = max(S2_med)
bys trader_id block: egen S2_trader_block_offer_low = max(S2_low)
* trader's market-level treatment status
bys trader_id week: egen trader_pS1low_week = mean(S1_low)
bys trader_id week: egen trader_pS1high_week = mean(S1_high)
bys trader_id week: egen trader_pS2_week = mean(S2)

bys trader_id week: egen kgs_own_adj_week = sum(kgs_own_adj)

sort market_name week trader_id

merge 1:1 market_name week trader_id using "$data/sort_order" // merge on sort order, to avoid non-unique sorts
assert _m==3
drop _m
sort sortorder
drop sortorder

save "$temp/trader_analysis_data", replace
outsheet using "$temp/trader_analysis_data.csv", comma replace

use "$temp/trader_analysis_data", clear
gen total_kgs_mkt = kgs_own_adj + kgs_other_adj

* trim on market week total
xtile qnt = total_kgs_mkt, n(100)
drop if qnt<2 | qnt>98
drop qnt 
save "$temp/trader_analysis_data_trim", replace
outsheet using "$temp/trader_analysis_data_trim.csv", comma replace // trader level data



collapse (min) weighted_price_jt total_kgs_mkt, by(market_name week)

keep market_name week weighted_price_jt total_kgs_mkt
outsheet using "$temp/market_analysis_data_trim.csv", comma replace // market level data



********************************************************************************
* prepare demand experiment data
********************************************************************************


use "$data/DW_cleaned_plus_custnum.dta", clear

drop if inlist(cust_phone_id,"2","5","6","1197","1198") // phone codes corresponding to missing

gen sort_num = _n // seed the sort

merge m:1 cust_phone_id using "$data/wealth_cust_survey2.dta" 
drop _m

destring cust_phone_id, replace
sort cust_phone_id sort_num

gen post_price_trim = price_trim - subsidy

drop if old_amount_trim ==. |  new_amount_trim  ==. | price_trim  ==. | post_price_trim ==. 

gen income = wealth

keep old_amount_trim new_amount_trim  price_trim post_price_trim market_name subsidy income


gen cust_id = _n

rename old_amount_trim q0
rename new_amount_trim q1 
rename price_trim  p0
rename post_price_trim p1 

drop if income==0  

drop if subsidy==0

sort market_name
egen mid = group(market_name)


sort cust_id
assert cust_id!=cust_id[_n-1]

export delimited  using "$temp/demand_exp_analysis_data.csv",nolabel replace // demand experiment data

********************************************************************************
* prepare transaction level data
********************************************************************************


use "$data/WR Hourly Trader Survey cleaned_trans.dta", clear
drop if amt_kg_trim == . | price_per_kg_trim == .
keep price_per_kg_trim  amt_kg_trim 
export delimited using "$temp/transaction_analysis_data.csv", replace // transaction level data


********************************************************************************
* construct moments for demand model
********************************************************************************

use "$temp/trader_analysis_data", clear

keep if S2==0 // drop markets in entry experiment

gen total_kgs_mkt = kgs_own_adj + kgs_other_adj

* trim on market week total
xtile qnt = total_kgs_mkt, n(100)
dis "r(N)"
sum  if qnt<2
sum  if qnt>98
drop if qnt<2 | qnt>98
drop qnt 

* weight = inverse of traders
gen inv_num_traders = 1/num_traders

* control variable
gen control = 1-S1

* mean price for each treatment group
reg weighted_price_jt S1_low S1_high control [aweight=inv_num_traders], r cluster(market_block) nocons
gen b_int_price_C_trader = _b[control]  
gen b_int_price_S1_low_trader = _b[S1_low]
gen b_int_price_S1_high_trader = _b[S1_high]

collapse (min) S1 S1_low S1_high b_int_price_* control ///
(sum) total_kgs_adj  num_trans , by(market_name week)

egen market_id = group(market_name)
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
	
outsheet using "$temp/quantity_moments.csv", comma replace






