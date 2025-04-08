global rundate "2016_10_01"
global s2_rundate "2016_05_30"
set seed 610324937
local bootreps = 1000

version 14

global boot "on" // change "off" to "on" if want to run 

************
/*Figure 1*/
************

set scheme plotplain

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

keep  weighted_price_mkt_trim market_name week
rename weighted_price_mkt_trim market_price
duplicates drop

label var market_price "Price/Kg"

egen market_id = group(market_name)

foreach x in 12 13 14 15 17 18 19 20 22 23 24 25 {
sum market_price if week == `x' 
local k = _N + 1
set obs `k'
replace market_id = 61 if _n == _N
replace week = `x' if _n == _N
replace market_price = r(mean) if _n == _N
}

bysort week: egen avg_price = mean(market_price)
bysort market_name: gen count = _N

forval i = 1/60 { 
local plotline  "`plotline' plot`i'(lc(gs5)) " 
} 

xtline market_price , t(week) i(market_id)  `plotline' plot61(lc(black) lw(thick)) overlay legend(off) ///
 bgcolor(white) graphregion(color(white)) ylabel(,nogrid) xla(13 "March" 17 "April" 21 "May" 24 "June") xtitle("")
graph export "$output_figure/price_var_rep.png", replace 
graph export "$output_figure/price_var_rep.eps", replace 

**************************************
/*Figure 3, Figure 4, and Figure A.2*/
**************************************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

*generate number of traders indicator
preserve
duplicates drop market_date, force
set obs 720 // should have 60*12 = 720, but have 710 (fill in zeros for the few market-weeks that are missing any traders)
replace market_name = "holo" if _n == 711
replace week = 17 if _n == 711
replace market_name = "likuyani" if _n == 712 | _n == 713
replace week = 23 if _n == 712
replace week = 24 if _n == 713
replace market_name = "lugari station" if _n >= 714 & _n <= 718
replace week = 17 if _n == 714
replace week = 18 if _n == 715
replace week = 19 if _n == 716
replace week = 20 if _n == 717
replace week = 22 if _n == 718
replace market_name = "lwandeti" if _n == 719
replace week = 12 if _n == 719
replace market_name = "mateka" if _n == 720
replace week = 12 if _n == 720
replace num_traders = 0 if _n >= 711

xi: reg num_traders i.market_name i.week S1 S2, r cluster(market_block)
xpredict num_traders_main , with(_Iweek* _Imarket_na*) constant
bysort market_name: egen num_trainers_main_mean = median(num_traders_main)
replace num_trainers_main_mean = round(num_trainers_main_mean)
drop num_traders_main
rename num_trainers_main_mean num_traders_hetero

keep market_name num_traders_hetero
duplicates drop 

bysort num_traders_hetero: gen freq = _N
gen percent = freq/_N + 0.001

forval i = 1/10{
count if num_traders == `i'
mat c = r(N)
if `i'==1 {
		mat g = c
		}
		else {
		mat g = g\c   
		}
	}

*Figure A.2
qui graph twoway (histogram num_traders_hetero, color(gs8) lcolor(gs5) discrete frequency), ///
 bgcolor(white) graphregion(color(white)) ylabel(,nogrid angle(horizontal)) ytitle("Markets Count", angle(horizontal)) xtitle("Number Traders per Market") legend(off) plotregion(margin(b = 0)) xla(1(1)10) 
 graph export "$output_figure/num_traders_hist_rep.png", replace 
 graph export "$output_figure/num_traders_hist_rep.eps", replace 
 
drop percent

save "$temp/num_traders.dta", replace
outsheet using "$temp/num_traders.csv", replace comma
restore


*bring in number of traders indicator
merge m:1 market_name using "$temp/num_traders.dta"

tab num_traders_hetero, gen(d_num_traders_hetero)
forval i = 1/10{
gen d_S1_amt_num_traders_hetero`i' = d_num_traders_hetero`i'*S1_amt
label var d_S1_amt_num_traders_hetero`i' "`i' Traders" 
gen d_S2_num_traders_hetero`i' = d_num_traders_hetero`i'*S2
label var d_S2_num_traders_hetero`i' "`i' Traders" 
}
label var d_S1_amt_num_traders_hetero1 "1 Trader"
label var d_S2_num_traders_hetero1 "1 Trader"

sum num_traders_hetero [aweight=num_traders_inv], detail 
gen num_traders_hetero_abvm = 0
replace num_traders_hetero_abvm =1 if num_traders_hetero > 3
gen num_traders_hetero_abvm_S1_amt = num_traders_hetero_abvm*S1_amt
gen num_traders_hetero_belm_S1_amt = (1-num_traders_hetero_abvm)*S1_amt
label var num_traders_hetero_abvm_S1_amt "Above Median (>=4)"
label var num_traders_hetero_belm_S1_amt "Below Median (<4)"
gen num_traders_hetero_abvm_S2 = num_traders_hetero_abvm*S2
gen num_traders_hetero_belm_S2 = (1-num_traders_hetero_abvm)*S2
label var num_traders_hetero_abvm_S2 "Above Median (>=4)"
label var num_traders_hetero_belm_S2 "Below Median (<4)"

*bring in agree on and discuss price indicators
preserve
use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear
keep discuss_good_price_mkt agreement_price_mkt market_name
collapse discuss_good_price_mkt  agreement_price_mkt, by (market_name)
foreach x in discuss_good_price_mkt agreement_price_mkt{
sum `x', detail
gen am_`x' = (`x' > r(p50))
}
keep am* market_name
save "$temp/median_coll.dta", replace
restore

merge m:1 market_name using "$temp/median_coll.dta", nogen

foreach x in discuss_good_price_mkt agreement_price_mkt {
gen bm_`x' = 1- am_`x'
foreach y in am bm {
gen `y'_`x'_S1_amt = `y'_`x'*S1_amt
gen `y'_`x'_S2 = `y'_`x'*S2
}
}

*bring in tarmac indicator
merge m:1 market_name using "$data/randomization_main.dta", nogen keepusing(tarmac)

gen off_tarmac = 1-tarmac
foreach x in tarmac off_tarmac {
gen `x'_S1_amt = `x'*S1_amt
gen `x'_S2 = `x'*S2
}

*heterogeneity by all
local i = 1
foreach x in num_traders_hetero_abvm tarmac am_discuss_good_price_mkt am_agreement_price_mkt {
preserve
drop `x'
rename `x'_S1_amt `x'
xi: reg weighted_price_adj_trim i.week i.market_name S1_amt `x' if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
mat b = (round(_b[`x'],0.001), round(_se[`x'],0.001))
if `i'==1 {
		mat S1mat = b
		}
		else {
		mat S1mat = S1mat\b   
		}
eststo s1_hetero`i'_int
restore
local i = `i' + 1
}

foreach y in S1_amt S2{
gen am_num_traders_hetero_`y' = num_traders_hetero_abvm_`y'
gen bm_num_traders_hetero_`y' = num_traders_hetero_belm_`y'
gen am_tarmac_`y' = tarmac_`y'
gen bm_tarmac_`y' = off_tarmac_`y'
}

local i = 1
foreach x in num_traders_hetero tarmac discuss_good_price_mkt agreement_price_mkt {
preserve
xi: reg weighted_price_adj_trim i.week i.market_name am_`x'_S1_amt bm_`x'_S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
mat b = (_b[am_`x'_S1_amt],_b[am_`x'_S1_amt]+1.96*_se[am_`x'_S1_amt], _b[am_`x'_S1_amt]-1.96*_se[am_`x'_S1_amt], _b[bm_`x'_S1_amt],_b[bm_`x'_S1_amt]+1.96*_se[bm_`x'_S1_amt], _b[bm_`x'_S1_amt]-1.96*_se[bm_`x'_S1_amt])
if `i'==1 {
		mat S1mat_twoway = b
		}
		else {
		mat S1mat_twoway = S1mat_twoway\b   
		}
eststo s1_hetero`i'_twoway
restore
local i = `i' + 1
}

mat rownames S1mat_twoway = num_traders_hetero tarmac discuss_good_price_mkt agreement_price_mkt

label var num_traders_hetero_abvm `" "{bf:Above Median}" "{bf:Number Traders}""'
label var am_discuss_good_price_mkt `" "{bf:Above Median}" "{bf:Discuss Prices}""'
label var am_agreement_price_mkt `" "{bf:Above Median}" "{bf:Agree Prices}""'
label var tarmac "{bf:Tarmac}" 
label var num_traders_hetero "{bf:Number Traders}"
label var discuss_good_price_mkt "{bf:Discuss Price}"
label var agreement_price_mkt "{bf:Agree Price}"

*Figure 4
coefplot (matrix(S1mat_twoway[,4]), ci((S1mat_twoway[,5] S1mat_twoway[,6]))) (matrix(S1mat_twoway[,1]), ci((S1mat_twoway[,2] S1mat_twoway[,3]))) ///
, xline(0.224, lcolor(gs10) lp(shortdash)) bgcolor(white)  ///
graphregion(margin(l=25) color(white)) ylabel(,noticks) yscale(alt noline) coeflabels(, labgap(-155) notick) ///
grid(none glcolor(gs14) glpattern(dash))  scale(.85) legend(label(2 "Below Median/Off Tarmac") label(4 "Above Median/On Tarmac")  rows(1) region(lcolor(white)))  scheme(s1mono)
graph export "$output_figure/S1_hetero_twoway_rep.png", replace 
graph export "$output_figure/S1_hetero_twoway_rep.eps", replace 
eststo clear

*further breakdown by individual number of traders
xi: reg weighted_price_adj_trim i.week i.market_name d_num_traders_hetero* d_S1_amt_num_traders_hetero* if S2!=1 [aweight=num_traders_inv], r cluster(market_block)
eststo s1_hetero
forval i = 1/10{
mat b = (round(_b[d_S1_amt_num_traders_hetero`i'],0.01), round(_se[d_S1_amt_num_traders_hetero`i'],0.01))
if `i'==1 {
		mat d = b
		}
		else {
		mat d = d\b   
		}
	}
	
xi: reg weighted_price_adj_trim d_num_traders_hetero* i.week i.market_name num_traders_hetero_belm_S1_amt num_traders_hetero_abvm_S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block)
eststo s1_hetero_median
mat b = (round(_b[num_traders_hetero_belm_S1_amt],0.01), round(_se[num_traders_hetero_belm_S1_amt],0.01) \ round(_b[num_traders_hetero_abvm_S1_amt],0.01), round(_se[num_traders_hetero_abvm_S1_amt],0.01) )
mat d = d\b 

mat h = (g[1,1] + g[2,1]+ g[3,1])
mat h = (h \ 60-h)
mat f = g\h
matrix z= d,f

forval i = 1/12{
forval k = 1/6 {
local z`i'`k' = z[`i,',`k']
}
}

*Figure 3
coefplot (s1_hetero) (s1_hetero_median), drop(_cons _Iweek* _Imarket* d_num_traders* )  xline(0, lcolor(gs10)) bgcolor(white) xline(0.224, lcolor(gs10) lp(shortdash)) bgcolor(white) ///
graphregion(margin(l=25) color(white)) ylabel(,noticks) yscale(alt noline) coeflabels(, labgap(-155) notick) legend(label(2 "Individual") label(4 "Pooled") rows(1) region(lcolor(white))) ///
grid(none glcolor(gs14) glpattern(dash))    ciopts(lcolor(black)) headings(d_S1_amt_num_traders_hetero1 ="{bf: Markets}", axis(2))  scale(.75) scheme(s1mono) ///
groups(d_S1_amt_num_traders_hetero1 = "       `z13'" ///
d_S1_amt_num_traders_hetero2 = "      `z23'" ///
d_S1_amt_num_traders_hetero3 = "      `z33'" ///
d_S1_amt_num_traders_hetero4 = "       `z43'" ///
d_S1_amt_num_traders_hetero5 = "       `z53'" ///
d_S1_amt_num_traders_hetero6 = "       `z63'" ///
d_S1_amt_num_traders_hetero7 = "       `z73'" ///
d_S1_amt_num_traders_hetero8 = "       `z83'" ///
d_S1_amt_num_traders_hetero9 = "       `z93'" ///
d_S1_amt_num_traders_hetero10 = "       `z103'" ///
num_traders_hetero_belm_S1_amt = "      `z113'" ///
num_traders_hetero_abvm_S1_amt = "      `z123'", angle(horizontal) labgap(4)) ///
yscale(alt axis(2)) 
graph export "$output_figure/S1_hetero_traders_rep.png", replace 
graph export "$output_figure/S1_hetero_traders_rep.eps", replace 

************
/*Figure 5*/
************

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
local mean_q = r(mean)
summ price_trim
local mean_p = r(mean)
gen no_change = old_amount==new_amount
keep if subsidy>0

drop if old_amount_trim ==. |  new_amount_trim  ==. | price_trim  ==. | post_price_trim ==. 

preserve
collapse (mean) change_q (semean) se_rf=change_q, by(subsidy)
gen change_p = -subsidy
label var change_p "Change in Price (Ksh/kg)"
label var change_q "Change in Q"
gen low = change_q-1.96*se_rf
gen high = change_q+1.96*se_rf
gen elast = (change_q/change_p)*`mean_p'/`mean_q'
summ elast
list subsidy elast
twoway (connected change_q change_p, legend(off)  ytitle("Change in Quantity (kgs)") xlabel(-4.4 -3.9 -3.3 -2.8 -2.2 -1.7 -1.1 -0.6 -0.3 0))(rcap low high change_p)
graph export "$output_figure/demand_rf_figure_rep.png", replace
graph export "$output_figure/demand_rf_figure_rep.eps", replace
restore

preserve
collapse (mean) no_change (semean) se_rf=no_change, by(subsidy)
gen change_p = -subsidy
label var change_p "Change in Price (Ksh/kg)"
label var no_change "Fraction No Change in Q"
gen low = no_change-1.96*se_rf
gen high = no_change+1.96*se_rf
gen change_frac = 1-no_change
label var change_frac "Fraction Change in Q"
gen low1 = (1-no_change)-1.96*se_rf
gen high1 = (1-no_change)+1.96*se_rf
twoway (connected change_frac change_p, ytitle("Fraction Changed Quantity") legend(off) xlabel(-4.4 -3.9 -3.3 -2.8 -2.2 -1.7 -1.1 -0.6 -0.3 0))(rcap low1 high1 change_p)
graph export "$output_figure/demand_rf_zero_figure_rep.png", replace
graph export "$output_figure/demand_rf_zero_figure_rep.eps", replace
restore

************
/*Figure 6*/
************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

qui xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
local rho = _b[S1_amt]
gen rho = `rho'
keep if _n==1
keep rho
outsheet using "$temp/rho_est.csv", comma replace


if "$boot" == "on" {

tempfile tempN
use "$temp/num_traders.dta", clear
sort market_name
drop freq
save  `tempN', replace

*prep pool of bootstrapped demand estimates
insheet using "$temp/simple_demand_bootstrap.csv", clear
rename v1 delta
rename v2 a

set seed 61032493

gen rand = uniform() 
sort rand
gen merge_id = _n
drop rand
save "$temp/demand_boot.dta", replace

*run bootstrap

forval i = 1/`bootreps'{ 

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear
gen sort_id = _n

sort market_name week trader_id
gen  new_mkt_wk = (market_name!=market_name[_n-1] |  week!=week[_n-1])

*sample with replacement
sort sort_id
bsample, cluster(market_block) 

*bring in demand estimates
gen merge_id = `i'
merge m:1 merge_id using "$temp/demand_boot.dta"
drop if _m == 2
drop _m

*bring in market distribution of N
sort market_name 
merge n:1 market_name using `tempN'
drop if _m==2
drop  _m
sort merge_id

*estimate components
xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
local rho = _b[S1_amt]
gen rho = _b[S1_amt]

forvalues n=1/10 {
	gen pctN`n' = (num_traders_hetero==`n') if new_mkt_wk==1
	qui summ pctN`n'
	replace pctN`n' = r(mean)
}

keep rho a delta pctN*
keep if _n == 1
save "$temp/boot_est_`i'.dta", replace

}
*append bootstrapped rhos
clear
forval i = 1/`bootreps'{
append using "$temp/boot_est_`i'.dta"
}
save "$temp/boot_est.dta", replace

}

insheet using "$temp/rho_est.csv", comma clear
local rho_bar = rho[1]

insheet using "$temp/simple_demand_estimates.csv", comma clear
local delta_bar = delta[1]

use "$temp/num_traders.dta", clear

gen rho_est_market = 1/(1+`delta_bar'/num_traders_hetero)
qui summ rho_est_market
local expected_rho_cournot = r(mean)

use "$temp/boot_est.dta", clear

local rho_coll = 1/(1+`delta_bar')
local rho_cour = `expected_rho_cournot'


local rho_bar_label_loc = `rho_bar'+0.02
local rho_coll_label_loc = `rho_coll'-0.08

sort rho

local bottom5 = rho[25]
local top5 = rho[975]

graph twoway (histogram rho, bin(100) color(gs8) lcolor(gs5) xaxis(1 2) xla(`rho_bar_label_loc' `""Empirical   " "Point   " "Est  ""' `rho_coll_label_loc'  "            Collusive"  `rho_cour' "Cournot" 1 "Bertrand", noticks axis(2)) xla(.1(.1)1 , axis(1)) xtitle("Pass-through rate", axis(1)) xtitle("", axis(2)) xscale(noline axis(2))) ///
(scatteri 0 `rho_bar' 6.5 `rho_bar', c(l) m(i) lc(red) lw(medthick) lp(dash)) (scatteri 0 `rho_coll' 6.5 `rho_coll', c(l) m(i) lc(black) lw(medthick) lp(dash)) ///
 (scatteri 0 `rho_cour' 6.5 `rho_cour', c(l) m(i) lc(black) lw(medthick) lp(dash)) ///
 (scatteri 0 `bottom5' 6.5 `bottom5', c(l) m(i) lc(red) lw(thin) lp(shortdash)) (scatteri 0 `top5' 6.5 `top5', c(l) m(i) lc(red) lw(thin) lp(shortdash)) ///
(scatteri 0 1 6.5 1, c(l) m(i) lc(black) lw(medthick) lp(dash)), ///
 xscale(range(0 1.1)) bgcolor(white) graphregion(color(white)) ylabel("",nogrid) legend(off) plotregion(margin(b = 0))
graph export "$output_figure/rho_hist_enhanced_rep.png", replace  
graph export "$output_figure/rho_hist_enhanced_rep.eps", replace 

************
/*Figure 7*/
************

use "$temp/boot_est.dta", clear

outsheet using  "$temp/boot_est.csv",  comma  replace

*STOP AND RUN MATLAB O1_omega_wrapper.m
/*
run O1_omega_wrapper.m
it calls:
O2_solve_omega.m
*/

* input: boot_est.csv, num_traders.csv, rho_est.csv, simple_demand_estimates
* output: omega_baseline.csv, omega_boot.csv


insheet using "$temp/omega_baseline.csv", clear comma
local omega_bar = v1

insheet  using "$temp/omega_boot.csv", clear comma
rename v1 omega_boot

local expected_omega_cournot  =  0

sort omega_boot
local bottom5 = omega_boot[25]
local top5 = omega_boot[975]
local bottom5adj = `bottom5'
local cournot_label_loc = `expected_omega_cournot'-0.6

graph twoway (histogram omega_boot if omega_boot < 8, bin(100) color(gs8) lcolor(gs5) xaxis(1 2) xla(`omega_bar' `""Empirical" "Point  " "Est  ""' 1 "             Collusive"  `cournot_label_loc' "Cournot" `bottom5adj' `"" 95%  " "CI  ""' `top5' `"" 95%  " "CI  ""' , noticks axis(2)) xtitle("{&omega}", axis(1)) xtitle("", axis(2)) xscale(noline axis(2))) ///
 (scatteri 0 `omega_bar' 1.4 `omega_bar', c(l) m(i) lc(red) lw(medthick) lp(dash)) ///
(scatteri 0 1 1.4 1, c(l) m(i) lc(black) lw(medthick) lp(dash))  (scatteri 0 `expected_omega_cournot' 1.4 `expected_omega_cournot', c(l) m(i) lc(black) lw(medthick) lp(dash)) ///
(scatteri 0 `bottom5' 1.4 `bottom5', c(l) m(i) lc(red) lw(thin) lp(shortdash)) (scatteri 0 `top5' 1.4 `top5', c(l) m(i) lc(red) lw(thin) lp(shortdash)), ///
xscale(range(0 5)) bgcolor(white) graphregion(color(white)) ylabel("",nogrid) legend(off) plotregion(margin(b = 0)) xlabel(-1(1)8) 
graph export "$output_figure/omega_hist_enhanced_rep.png", replace 
graph export "$output_figure/omega_hist_enhanced_rep.eps", replace 

*General model

insheet using "$temp/general_supply_estimates.csv", clear comma
local omega_bar = omega_hat[1]

use "$temp/bootstrap/supply_est/supply_bootstrap_coeff", clear

local expected_omega_cournot  =  0

sort omega_est
local bottom5 = omega_est[25]
local top5 = omega_est[975]
local bottom5adj = `bottom5'
local cournot_label_loc = `expected_omega_cournot'-0.4
ren omega_est omega_boot
local  omega_bar_label_loc = `omega_bar'+0.35
local collusive_label_loc = 1 - 0.6

graph twoway (histogram omega_boot if omega_boot >=-1, bin(100) color(gs8) lcolor(gs5) xaxis(1 2) xla(`omega_bar_label_loc' `""Empirical" "Point  " "Est  ""' `collusive_label_loc' "             Collusive"  `cournot_label_loc' "Cournot" `bottom5adj' `"" 95%  " "CI  ""' `top5' `"" 95%  " "CI  ""' , noticks axis(2)) xtitle("{&omega}", axis(1)) xtitle("", axis(2)) xscale(noline axis(2))) ///
 (scatteri 0 `omega_bar' 1.4 `omega_bar', c(l) m(i) lc(red) lw(medthick) lp(dash)) ///
(scatteri 0 1 1.4 1, c(l) m(i) lc(black) lw(medthick) lp(dash))  (scatteri 0 `expected_omega_cournot' 1.4 `expected_omega_cournot', c(l) m(i) lc(black) lw(medthick) lp(dash)) ///
(scatteri 0 `bottom5' 1.4 `bottom5', c(l) m(i) lc(red) lw(thin) lp(shortdash)) (scatteri 0 `top5' 1.4 `top5', c(l) m(i) lc(red) lw(thin) lp(shortdash)), ///
xscale(range(-1 8)) bgcolor(white) graphregion(color(white)) ylabel("",nogrid) legend(off) plotregion(margin(b = 0)) xlabel(-1(1)8) 
graph export "$output_figure/omega_hist_enhanced_general_rep.png", replace 
graph export "$output_figure/omega_hist_enhanced_general_rep.eps", replace 

************************
/*Figure 8 and Table 4*/
************************

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

replace dist = dist/10

*analyze predictors of take-up
label var any_takeup "Take-up"
replace offer_amount = offer_amount/5
label var offer_amount "{bf:Offer amt (50 USD)}"
replace dist = dist/5
label var dist "{bf:Dist (50km)}"

*grant take-up table
forval i = 1/3{
sum any_takeup if offer_amount == `i'
local takeup = r(mean)
mat b = (`takeup')
	if `i'==1 {
		mat d = b
		}
		else {
		mat d = d\b   
		}
	}

local exchange_rate = 101.30
local avg_daily_prof = 3870
mat c = (5000, 5000/`exchange_rate'  \ 10000, 10000/`exchange_rate'  \ 15000, 15000/`exchange_rate' ) 
mat z = (60 \ 60 \ 60)
matrix d = c,d,z

mat rownames d =  "\textbf{Low Offer}" "\textbf{Medium Offer}" "\textbf{High Offer}" 
matrix list d

frmttable using "$output_table/S2_takeup_rep.tex", statmat(d) replace va tex fra ///
	ctitles("","Offer Amount", "","Take-up","Observations" \ "", "\ital{Ksh}", "\ital{USD}",  "Rate", "") ///
	multicol(1,2,2) sdec(0, 0, 2, 0 \ 0, 0, 2, 0 \ 0, 0, 2, 0) 
	
*grant amount
reg any_takeup offer_amount, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r1N = e(N)
local r1apt = round(_b[offer_amount],0.01)
local r1aLCI = round(_b[offer_amount] - 1.96*_se[offer_amount],0.01)
local r1aUCI = round(_b[offer_amount] + 1.96*_se[offer_amount],0.01)
eststo r1a


xi: reg any_takeup i.market_name offer_amount, cluster(trader_id)
estadd local marketfe "Yes"
estadd ysumm 
local r1bpt = round(_b[offer_amount],0.01)
local r1bLCI = round(_b[offer_amount] - 1.96*_se[offer_amount],0.01)
local r1bUCI = round(_b[offer_amount] + 1.96*_se[offer_amount],0.01)
eststo r1b

*distance
reg any_takeup dist, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r2N = e(N)
local r2apt = round(_b[dist],0.01)
local r2aLCI = round(_b[dist] - 1.96*_se[dist],0.01)
local r2aUCI = round(_b[dist] + 1.96*_se[dist],0.01)
eststo r2a

xi: reg any_takeup i.market_name dist, cluster(trader_id) 
estadd local marketfe "Yes"
estadd ysumm 
local r2bpt = round(_b[dist],0.01)
local r2bLCI = round(_b[dist] - 1.96*_se[dist],0.01)
local r2bUCI = round(_b[dist] + 1.96*_se[dist],0.01)
eststo r2b

*contacts
label var know_any "{bf:Have contacts}"
reg any_takeup know_any, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r3N = e(N)
local r3apt = round(_b[know_any],0.01)
local r3aLCI = round(_b[know_any] - 1.96*_se[know_any],0.01)
local r3aUCI = round(_b[know_any] + 1.96*_se[know_any],0.01)
eststo r3a

xi: reg any_takeup i.market_name know_any, cluster(trader_id) 
estadd local marketfe "Yes"
estadd ysumm 
local r3bpt = round(_b[know_any],0.01)
local r3bLCI = round(_b[know_any] - 1.96*_se[know_any],0.01)
local r3bUCI = round(_b[know_any] + 1.96*_se[know_any],0.01)
eststo r3b

*baseline profits
sum e_profit_day, detail
local medprof = r(p50)
gen above_med_profit = 0 if e_profit_day!=.
replace above_med_profit = 1 if e_profit_day > `medprof' & e_profit_day!=.
label var above_med_profit "{bf:Above median profits}"

reg any_takeup above_med_profit, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r4N = e(N)
local r4apt = round(_b[above_med_profit],0.01)
local r4aLCI = round(_b[above_med_profit] - 1.96*_se[above_med_profit],0.01)
local r4aUCI = round(_b[above_med_profit] + 1.96*_se[above_med_profit],0.01)
eststo r4a

xi: reg any_takeup i.market_name above_med_profit, cluster(trader_id) 
estadd local marketfe "Yes"
estadd ysumm 
local r4bpt = round(_b[above_med_profit],0.01)
local r4bLCI = round(_b[above_med_profit] - 1.96*_se[above_med_profit],0.01)
local r4bUCI = round(_b[above_med_profit] + 1.96*_se[above_med_profit],0.01)
eststo r4b

*ethnic match
gen prc_own_eth_x_min = minority*prc_own_eth
label var prc_own_eth "{bf:Prct own ethnicity}"
label var prc_own_eth_x_min "Minority x \% own ethnicity"

gen dist2 = dist

reg any_takeup dist2 prc_own_eth, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r5N = e(N)
local r5apt = round(_b[prc_own_eth],0.01)
local r5aLCI = round(_b[prc_own_eth] - 1.96*_se[prc_own_eth],0.01)
local r5aUCI = round(_b[prc_own_eth] + 1.96*_se[prc_own_eth],0.01)
eststo r5a

xi: reg any_takeup dist2 i.market_name prc_own_eth, cluster(trader_id)
estadd local marketfe "No"
estadd ysumm 
local r5bpt = round(_b[prc_own_eth],0.01)
local r5bLCI = round(_b[prc_own_eth] - 1.96*_se[prc_own_eth],0.01)
local r5bUCI = round(_b[prc_own_eth] + 1.96*_se[prc_own_eth],0.01)
eststo r5b

drop dist2

*num obs
local r1N = 180
local r2N = 165
local r3N = 168
local r4N = 168
local r5N = 167

*results plot
coefplot (r1a \ r2a \ r3a \ r4a  \ r5a   , label(No FE)) (r1b \ r2b \ r3b \ r4b \ r5b, label(Market FE)) , drop(_cons _Imarket* dist2) ///
xline(0, lcolor(black)) bgcolor(white) ///
graphregion(margin(l=25) color(white)) ylabel(,noticks)  yscale(alt noline) coeflabels(, labgap(-175) notick) legend(rows(1) region(lcolor(white))) ///
 grid(none glcolor(gs14) glpattern(dash))  headings(offer_amount ="{bf: Obs}", axis(2))  scale(.7) ///
groups(offer_amount =  " `r1N'" ///
 dist =   " `r2N'"  ///
 know_any =  " `r3N'"  ///
 above_med_profit =  " `r4N'"   ///
 prc_own_eth =  " `r5N'"  , angle(horizontal) labgap(5)) ///
 yscale(alt axis(2)) scheme(s1mono)
graph export "$output_figure/S2takeup_hetero_rep.png", replace 
graph export "$output_figure/S2takeup_hetero_rep.eps", replace 

***********
/*Table 1*/
***********

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

*basic results
label var weighted_price_adj_trim "Price"
label var S1_amt "Cost Change"
label var S1_amt_high "Cost Change - High"
label var S1_amt_low "Cost Change - Low"

xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo r1_rho

xi: reg weighted_price_adj_trim i.week i.market_name S1_amt_low S1_amt_high if S2!=1 [aweight=num_traders_inv], r cluster(market_block)  
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo r2_rho

qui esttab r1_rho r2_rho  using "$output_table/S1_rho_traders_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1*) ///
stats(ymean N market week, labels ("Mean Dep Var" "N" "Market FE" "Week FE")) ///
nonote 

eststo clear

***********
/*Table 2*/
***********

clear

insheet using "$temp/simple_demand_estimates.csv", comma clear
local a_bar = a[1]
local a_lower = `a_bar'-1.96*a_se
local a_upper = `a_bar'+1.96*a_se
local delta_bar = delta[1]
local delta_lower = `delta_bar'-1.96*delta_se
local delta_upper = `delta_bar'+1.96*delta_se

insheet using "$temp/omega_baseline.csv", clear comma
local omega_bar = v1

insheet  using "$temp/omega_boot.csv", clear comma
rename v1 omega_boot
sort omega_boot
local omega_lower = omega_boot[25]
local omega_upper = omega_boot[975]

insheet using "$temp/general_demand_estimates.csv", comma clear
local mu_a_bar = mu[1]
local sigma_a_bar = sigma[1]
local delta_full_bar = delta[1]

insheet using "$temp/bootstrap/demand_est/general_demand_bootstrap_estimates.csv", comma clear

sort mu
local mu_a_lower = mu[25]
local mu_a_upper = mu[975]

sort sigma
local sigma_a_lower = sigma[25]
local sigma_a_upper = sigma[975]

sort delta
local delta_full_lower = delta[25]
local delta_full_upper = delta[975]

insheet using "$temp/general_supply_estimates.csv", clear comma
local omega_full_bar = omega_hat[1]
local gamma_full_bar = gamma_hat[1]

insheet using "$temp/general_supply_estimates_omega1.csv", clear comma
local gamma_omega1_bar = gamma_hat[1]

use "$temp/bootstrap/supply_est/supply_bootstrap_coeff", clear

sort omega_est
local omega_full_lower = omega_est[25]
local omega_full_upper = omega_est[975]
sort gamma_est
local gamma_full_lower = gamma_est[25]
local gamma_full_upper = gamma_est[975]

use "$temp/bootstrap/supply_est/supply_bootstrap_coeff_o1", clear

sort gamma_est
local gamma_omega1_lower = gamma_est[25]
local gamma_omega1_upper = gamma_est[975]

* Simple model
local i = 1
foreach x in a delta omega {
mat b = (``x'_bar', ``x'_lower', ``x'_upper')
if `i'==1 {
 mat d = b
 }
 else {
 mat d = d\b  
 }
local i = `i' + 1
}

* General model
local j = 1
foreach x in mu_a sigma_a delta_full omega_full gamma_full {
mat e = (``x'_bar', ``x'_lower', ``x'_upper')
if `j'==1 {
 mat f = e
 }
 else {
 mat f = f\e  
 }
local j = `j' + 1
}

* General model, imposing omega==1
local j = 1
foreach x in gamma_omega1 {
mat e = (``x'_bar', ``x'_lower', ``x'_upper')
if `j'==1 {
 mat m = e
 }
 else {
 mat m = m\e  
 }
local j = `j' + 1
}

gen temp_name1 = .
label var temp_name1 "\emph{\textbf{Simple Model}}"
gen temp_name2 = .
label var temp_name2 "\emph{\textbf{General Model}}"
gen temp_name3 = .
label var temp_name3 "\emph{\textbf{General Model, $\omega=1$}}"

matrix g = (., .,  .) \ d
mat rownames g = temp_name1 a $\delta$ $\omega$

matrix h = (., ., .) \ f
mat rownames h = temp_name2 $\mu\textsubscript{\it{a}}$ $\sigma\textsubscript{\it{a}}$ $\delta$ $\omega$ $\gamma$

matrix i = (., ., .) \ m
mat rownames i = temp_name3 $\gamma$


matrix k = g \ h
matrix list k

matrix n = g \ h \ i
matrix list n

frmttable using "$output_table/params_model_omega1_rep.tex", statmat(n) replace va tex fra hline(1 0 1 0 0 0 0 0 0 0 0 0 0 0 1) ///
sdec(0, 0, 0 \ 2, 2, 2 \ 2, 2, 2 \ 2, 2, 2 \ 0, 0, 0 \ 2, 2, 2 \ 2, 2, 2 \ 2, 2, 2 \ 2, 2, 2 \ 4, 4, 4 \ 0, 0, 0 \ 4, 4, 4) ///
ctitles("","\textbf{Parameter}","\textbf{95\% Confidence}","\textbf{95\% Confidence}" \ "","\textbf{Estimate}", "\textbf{Interval Lower Bound}", "\textbf{Interval Upper Bound}") 


************************
/*Table 3 and Table H.1*/
************************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

preserve
sort  market_name week trader_id 
keep market_name week market_block
duplicates drop
save "$temp/market_name_week_market_block.dta", replace
restore

keep if S2==0

gen revenue = weighted_price_adj*total_kgs_adj

collapse (min) S1_low S1_high S1_amt* (sum) total_kgs_adj num_trans revenue (mean) weighted_price_adj_trim, by(market_name week)

merge 1:1 market_name week using "$temp/market_name_week_market_block.dta"
gen kgs_per_trans = total_kgs_adj/num_trans
bys market_name: egen maxtrans = max(num_trans)
gen pct_HH = num_trans/maxtrans


summ total_kgs_adj if weighted_price_adj_trim!=. & S1_low==1
local mean_kgs =  r(mean)
summ num_trans if weighted_price_adj_trim!=. & S1_low==1
local mean_trans = r(mean)
summ pct_HH if weighted_price_adj_trim!=. & S1_low==1
local mean_pct_HH = r(mean)
summ kgs_per_trans if weighted_price_adj_trim!=. & S1_low==1
local mean_kgs_per =  r(mean)

summ weighted_price_adj_trim if S1_low==1
local mean_p  =  round(r(mean),0.1)

xi: ivregress 2sls total_kgs_adj ( weighted_price_adj_trim = S1_low S1_high) i.week i.market_name, vce(cluster market_block)
local elasticity_kgs: di %2.1f round(_b[weighted_price_adj_trim]*`mean_p'/`mean_kgs',0.1)
estadd local market "Yes"
estadd local week "Yes"
estadd local price_mean `mean_p'
estadd local elasticity `elasticity_kgs'
estadd ysumm 
eststo kgs

xi: ivregress 2sls num_trans ( weighted_price_adj_trim = S1_low S1_high) i.week i.market_name, vce(cluster market_block)
local elasticity_trans: di %2.1f round(_b[weighted_price_adj_trim]*`mean_p'/`mean_trans',0.1)
estadd local market "Yes"
estadd local week "Yes"
estadd local price_mean `mean_p'
estadd local elasticity `elasticity_trans'
estadd ysumm 
eststo trans

xi: ivregress 2sls pct_HH ( weighted_price_adj_trim = S1_low S1_high) i.week i.market_name, vce(cluster market_block)
local elasticity_pct_HH: di %2.1f round(_b[weighted_price_adj_trim]*`mean_p'/`mean_pct_HH',0.1)
estadd local market "Yes"
estadd local week "Yes"
estadd local price_mean `mean_p'
estadd local elasticity `elasticity_pct_HH'
estadd ysumm 
eststo trans_rate

xi: ivregress 2sls kgs_per_trans ( weighted_price_adj_trim = S1_low S1_high) i.week i.market_name, vce(cluster market_block)
local elasticity_kgs_per: di %2.1f round(_b[weighted_price_adj_trim]*`mean_p'/`mean_kgs_per',0.1)
estadd local market "Yes"
estadd local week "Yes"
estadd local price_mean `mean_p'
estadd local elasticity `elasticity_kgs_per'
estadd ysumm 
eststo kgs_per_trans

xi: reg total_kgs_adj S1_amt i.week i.market_name if weighted_price_adj_trim!=., r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local elasticity `elasticity_kgs'
estadd ysumm 
eststo kgs_rf

xi: reg num_trans S1_amt i.week i.market_name if weighted_price_adj_trim!=., r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local elasticity `elasticity_trans'
estadd ysumm 
eststo trans_rf

xi: reg num_trans S1_low S1_high i.week i.market_name if weighted_price_adj_trim!=., r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo trans_rf_nonlinear

xi: reg pct_HH S1_amt i.week i.market_name if weighted_price_adj_trim!=., r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local elasticity `elasticity_pct_HH'
estadd ysumm 
eststo trans_rate_rf

xi: reg kgs_per_trans S1_amt i.week i.market_name if weighted_price_adj_trim!=., r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local elasticity `elasticity_kgs_per'
estadd ysumm 
eststo kgs_per_trans_rf



label var kgs_per_trans "Kgs/Trans"
label var pct_HH "Trans Rate"
label var num_trans "Num Trans"
label var total_kgs_adj "Kgs"
label var weighted_price_adj_trim "Price"
label var S1_high "High Treatment"
label var S1_low "Low Treatment"
label var S1_amt "Cost Change"

qui esttab trans_rf trans_rf_nonlinear trans_rate_rf kgs_per_trans_rf kgs_rf using "$output_table/S1_elasticities_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1_amt S1_low S1_high) ///
stats(ymean elasticity N market week, labels ("Mean Dep Var" "Elasticity" "N" "Market FE" "Week FE")) ///
nonote

qui esttab trans trans_rate kgs_per_trans kgs using "$output_table/S1_ivquant_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(weighted_price_adj_trim) ///
stats(ymean elasticity N market week, labels ("Mean Dep Var" "Elasticity" "N" "Market FE" "Week FE")) ///
nonote 

*calculate elasticities in different segments for transactions

summ num_trans if weighted_price_adj_trim!=. & S1_low+S1_high==0
local trans_C =  r(mean)

summ num_trans if weighted_price_adj_trim!=. & S1_low==1
local trans_S1low =  r(mean)

summ num_trans if weighted_price_adj_trim!=. & S1_high==1
local trans_S1high =  r(mean)

summ weighted_price_adj_trim if S1_low+S1_high==0
local price_C =  r(mean)

summ weighted_price_adj_trim if S1_low==1
local price_S1low =  r(mean)

summ weighted_price_adj_trim if S1_high==1
local price_S1high =  r(mean)

xi: reg weighted_price_adj_trim S1_low S1_high i.week i.market_name, r cluster(market_block) 
local beta_price_low = _b[S1_low]
local beta_price_high = _b[S1_high]

xi: reg num_trans S1_low S1_high i.week i.market_name, r cluster(market_block) 
local beta_trans_low = _b[S1_low]
local beta_trans_high = _b[S1_high]

local elasticity_low = (`beta_trans_low'/`beta_price_low')*(`price_S1low'/`trans_S1low')
local elasticity_high = (`beta_trans_high'/`beta_price_high')*(`price_S1high'/`trans_S1high')
local elasticity_low_to_high = ((`beta_trans_high'-`beta_trans_low')/(`beta_price_high'-`beta_price_low'))*(`price_S1high'/`trans_S1high')

di "Elasticities Evaluated on Different Segments"
di "Elasticity Low: `elasticity_low'"
di "Elasticity High: `elasticity_high'"
di "Elasticity Low to High: `elasticity_low_to_high'"

*************************
/*Table 5 and Table I.1*/
*************************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

*make number of traders zero for markets in which don't have hourly data (these were marekts without traders)
merge m:1 market_date using "$data/full_market_dates.dta"
foreach x in num_traders  num_traders_incumbent num_traders_firsttime  {
replace `x' = 0 if _m == 2
replace `x'_trim = 0 if _m == 2
}
replace num_traders_inv = 1 if _m == 2
drop _m

*bring in any take up results
merge m:1 market_name week using "$data/mkt_any_takeup_day.dta"
replace any_takeup_that_day = 0 if _m != 3
drop _m

*FS: num entrants
xi: reg num_entrants i.week i.market_name S2 if S1!=1  [aweight=num_traders_inv] , r cluster(market_block) 
xi: reg num_entrants i.week i.market_name S2 if S1!=1 & weighted_price_adj_trim!=. [aweight=num_traders_inv] , r cluster(market_block) 
estadd local regtype "FS"
estadd local marketFE "Yes"
estadd local weekFE "Yes"
estadd ysumm 
eststo r1_FS

*Check: num incumbents
label var num_traders_incumbent "Number Incumbents"
xi: reg num_traders_incumbent i.week i.market_name S2 if S1!=1 [aweight=num_traders_inv] , r cluster(market_block) 
xi: reg num_traders_incumbent i.week i.market_name S2 if S1!=1 & weighted_price_adj_trim!=. [aweight=num_traders_inv] , r cluster(market_block) 
estadd local marketFE "Yes"
estadd local weekFE "Yes"
estadd ysumm 
eststo r2

*RF
xi: reg weighted_price_adj_trim i.week i.market_name S2 if S1!=1 [aweight=num_traders_inv] , r cluster(market_block)
estadd local regtype "RF"
estadd local marketFE "Yes"
estadd local weekFE "Yes"
estadd ysumm 
eststo r1_RF

*IV: num traders
xi: ivregress 2sls weighted_price_adj_trim i.week i.market_name (num_entrants  = S2) if S1!=1 [aweight=num_traders_inv] , r cluster(market_block) 
estat firststage
mat fstat = r(singleresults)
estadd scalar fs = fstat[1,4] 
estadd local regtype "IV"
estadd local marketFE "Yes"
estadd local weekFE "Yes"
estadd ysumm 
eststo r1_IV

label var any_takeup_that_day "Any Take-up"

qui esttab r1_FS r2 r1_RF r1_IV using "$output_table/S2_main_nostar_rep.tex", replace se label booktabs ///
noconstant nostar keep(S2* *num_entrants*)  ///
stats( fs ymean N marketFE weekFE, labels ( "F-Stat FS" "Mean Dep Var" "N" "Market FE" "Week FE" )) ///
nonote 

*Entry effects for S1?
gen S1_entrant = 0 if S2 != 1 & how_often!=.
replace S1_entrant = 1 if how_often == 4
bysort market_date: egen num_entrants_S1 = total(S1_entrant)

label var S1 "Cost Reduction Market"
label var num_entrants_S1 "Number Entrants"

xi: reg num_entrants_S1 i.week i.market_name S1 if S2!=1 & weighted_price_adj_trim!=. [aweight=num_traders_inv] , r cluster(market_block)
estadd local regtype "FS"
estadd local marketFE "Yes"
estadd local weekFE "Yes"
estadd local sample "All Weeks"
estadd ysumm 
eststo r1_FS_S1

qui esttab r1_FS_S1 using "$output_table/entry_check_ref_short_nostar_rep.tex", replace se label booktabs ///
noconstant nostar keep(S1)  ///
stats(ymean N marketFE weekFE, labels ("Mean Dep Var" "N" "Market FE" "Week FE" )) ///
nonote 


***********
/*Table 6*/
***********

clear

use "$temp/S2_effects", clear
local omega_pooled_est = omegaS2[1]

use "$temp/bootstrap/s2/S2_bootstrap_coeff", clear
sort omegaS2
local omega_pooled_CILB = omegaS2[25]
local omega_pooled_CIUB = omegaS2[975]

use "$temp/S2_heterogeneous_effects", clear
qui summ know_any if S2_trader==1
local frac_known = 100*round(r(mean),.01)
local frac_unknown = 100-`frac_known'

local omega_contactW_est = omegaS2_k[1]
local omega_contactWO_est = omegaS2_u[1]

use "$temp/bootstrap/s2/S2_heter_bootstrap_coeff", clear
sort omegaS2_k
local omega_contactW_CILB = omegaS2_k[25]
local omega_contactW_CIUB = omegaS2_k[975]

sort omegaS2_u
local omega_contactWO_CILB = omegaS2_u[25]
local omega_contactWO_CIUB = omegaS2_u[975]


mat f = (.,.,.)\(`omega_pooled_est',`omega_pooled_CILB',`omega_pooled_CIUB')\(.,.,.)
foreach x in contactW contactWO {
mat e = (`omega_`x'_est',`omega_`x'_CILB',`omega_`x'_CIUB')
mat f = f\e  
}

gen temp_name1 = .
label var temp_name1 "\emph{\textbf{Pooled model}}"
gen temp_name2 = .
label var temp_name2 "$\omega\textsubscript{\textit{e}}$ All Entrants"
gen temp_name3 = .
label var temp_name3 "\emph{\textbf{Heterogeneous by contacts}}"
gen temp_name4 = .
label var temp_name4 "$\omega^{with}_e$ Entrants with contacts (`frac_known'\%)"
gen temp_name5 = .
label var temp_name5 "$\omega^{without}_e$ Entrants without contacts (`frac_unknown'\%)"

mat rownames f = temp_name1 temp_name2 temp_name3 temp_name4 temp_name5 

frmttable using "$output_table/S2_omega_rep.tex", statmat(f) replace va tex fra hline(1 0 0 1 0 0 0 0 1) ///
ctitles("","","\textbf{95\% Confidence}","\textbf{95\% Confidence}" \ "", "\textbf{Parameter}", "\textbf{Interval Lower}","\textbf{Interval Upper}" \ "\textbf{Group}","\textbf{Estimate}","\textbf{Bound}","\textbf{Bound}") ///
sdec(0,0,0\2,2,2\0,0,0\2,2,2\2,2,2)


***********
/*Table 7*/
***********

clear

insheet using "$temp/entry_estimates.csv", comma clear
local mu_MC_est = mu_mc[1]
local mu_FC_est = mu_fc[1]
local sigma_MC_est = sigma_mc[1]
local sigma_FC_est = sigma_fc[1]
local rho_est = rho[1]
local takeup_high = takeh[1]
local takeup_med = takem[1]
local takeup_low = takel[1]
local MC_intercept_high = mch[1]
local MC_intercept_med = mcm[1]
local MC_intercept_low = mcl[1]

insheet using "$temp/bootstrap/s2/entry_bootstrap_estimates.csv", comma clear
ren v1 mu_MC_est
ren v2 mu_FC_est
ren v3 sigma_MC_est
ren v4 sigma_FC_est
ren v5 rho_est

qui summ mu_MC_est if mu_MC_est!=-1000
local mu_MC_se = r(sd)

qui summ mu_FC_est if mu_FC_est!=-1000
local mu_FC_se = r(sd)

qui summ sigma_MC_est if sigma_MC_est!=-1000
local sigma_MC_se = r(sd)

qui summ sigma_FC_est if sigma_FC_est!=-1000
local sigma_FC_se = r(sd)

qui summ rho_est if rho_est!=-1000
local rho_se = r(sd)

di `takeup_high'
di `takeup_med'
di `takeup_low'
di `MC_intercept_high'
di `MC_intercept_med'
di `MC_intercept_low'

di `mu_MC_est'
di `mu_FC_est'
di `sigma_MC_est'
di `sigma_FC_est'
di `rho_est'
di `mu_MC_se'
di `mu_FC_se'
di `sigma_MC_se'
di `sigma_FC_se'
di `rho_se'


local MC_intercept_cond_high = `MC_intercept_high'/`takeup_high'
local MC_intercept_cond_med = `MC_intercept_med'/`takeup_med'
local MC_intercept_cond_low = `MC_intercept_low'/`takeup_low'


** Panel 1
matrix a =(`takeup_high')\(`takeup_med')\(`takeup_low')\(`MC_intercept_high')\(`MC_intercept_med')\(`MC_intercept_low')\(`MC_intercept_cond_high')\(`MC_intercept_cond_med')\(`MC_intercept_cond_low')

gen temp_name1 = .
label var temp_name1 "Weekly takeup rate - high offer"
gen temp_name2 = .
label var temp_name2 "Weekly takeup rate - medium offer"
gen temp_name3 = .
label var temp_name3 "Weekly takeup rate - low offer"
gen temp_name4 = .
label var temp_name4 "Entry * marginal cost intercept - high offer"
gen temp_name5 = .
label var temp_name5 "Entry * marginal cost intercept - medium offer"
gen temp_name6 = .
label var temp_name6 "Entry * marginal cost intercept - low offer"

gen temp_name7 = .
label var temp_name7 "Marginal cost intercept - high offer"
gen temp_name8 = .
label var temp_name8 "Marginal cost intercept - medium offer"
gen temp_name9 = .
label var temp_name9 "Marginal cost intercept - low offer"

mat rownames a = temp_name1 temp_name2 temp_name3 temp_name4 temp_name5 temp_name6 temp_name7 temp_name8 temp_name9

frmttable using "$output_table/EntryModel_panel1_rep.tex", statmat(a) replace va tex fra hline(1 1 0 0 0 0 0 0 1 0 0 1) ///
ctitles("\emph{Panel A: \textbf{Model Moments}}" \ "Description","Estimate") sdec(4\4\4\2\2\2\2\2\2)  

** Panel 2
local j = 1
foreach x in mu_MC mu_FC sigma_MC sigma_FC rho {
mat e = (``x'_est',``x'_se')
if `j'==1 {
 mat f = e
 }
 else {
 mat f = f\e  
 }
local j = `j' + 1
}

mat rownames f = $\mu\textsubscript{MC}$ $\mu\textsubscript{FC}$ $\sigma\textsubscript{MC}$ $\sigma\textsubscript{FC}$ $\rho\textsubscript{MCFC}$

frmttable using "$output_table/EntryModel_panel2_rep.tex", statmat(f) replace va tex fra hline(1 1 0 0 0 0 0 1) ///
ctitles("\emph{Panel B: \textbf{Model Estimates}}" \ "Parameter","Estimate","Standard Error") sdec(2,2\2,2\2,2\2,2\2,2)
*************
/*Table A.1*/
*************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

gen prct_comp_pri = 0 if edu !=.
replace prct_comp_pri = 1 if edu > 1 & edu <= 8
label var prct_comp_pri "Complete primary"

gen prct_comp_sec = 0 if edu !=.
replace prct_comp_sec = 1 if edu > 3 & edu <= 8
label var prct_comp_sec "Complete secondary"

gen ravens_prct = ravens/12
label var ravens_prct "Percent corrrect Ravens"

gen any_written_records = 0 if record_keep!=.
replace any_written_records = 1 if record_written == 1
label var any_written_records "Keep written records"

gen fin_review_monthly = 0 if fin_review!=.
replace fin_review_monthly  = 1 if fin_review == 4
label var fin_review_monthly "Review financial stregth monthly+"

label var any_emp "Any employees"

label var num_emp "Number employees"

label var lorry_trader "Own lorry"

local vars prct_comp_pri prct_comp_sec ravens_prct fin_review_monthly any_written_records any_emp num_emp lorry_trader
local numvars : word count `vars'
tokenize `vars'

forvalues i = 1/`numvars' {
	sum ``i'' 
	mat b = (r(mean), r(sd), r(min), r(max), r(N))
	if `i'==1 {
		mat z = b
		}
		else {
		mat z = z\b 
		}
	}
mat rownames z = `vars'

drop if S2_trader == 1 // exclude entry traders when look at how well traders know each other at baseline

gen regular_trader = 0 if how_often!=. 
replace regular_trader = 1 if how_often == 1  
label var regular_trader "Work in this market most weeks"

gen new_trader = 0 if how_often!=. 
replace new_trader = 1 if how_often == 4 
label var new_trader "New trader"

label var worked_with_all_before "Worked with all before"

label var know_well_yn "Know other traders well"

gen know_well_somewhat_well = 0 if know_well!=.
replace know_well_somewhat_well = 1 if know_well == 1 | know_well == 2
label var know_well_somewhat_well "Know other traders well or somewhat well"

label var discuss_good_price_yn "Self-report discuss price"

label var discuss_good_price_mkt "Someone in market report discuss price"

replace dicuss_good_price_with_prc = 1 if dicuss_good_price_with_prc > 1 & dicuss_good_price_with_prc!=. 
gen dicuss_good_price_with_prc_ifyes =  dicuss_good_price_with_prc if discuss_good_price_yn==1
label var dicuss_good_price_with_prc_ifyes "Percent traders with whom discuss price"

label var agreement_price_yn "Self-report agree price"

label var agreement_price_mkt "Someone in market report agree price"

replace agreement_price_with_prc = 1 if agreement_price_with_prc > 1 & agreement_price_with_prc!=.
gen agreement_price_with_prc_ifyes =  agreement_price_with_prc if agreement_price_yn ==1
label var agreement_price_with_prc_ifyes "Percent traders with whom agree price"

preserve
use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear
drop if trader_id==.
sort trader_id market_name
gen num_trader_market  =  (trader_id!=trader_id[_n-1]) | (market_name!=market_name[_n-1])
collapse (sum) num_trader_market, by(trader_id)
gen obsnum = _n
keep  obsnum num_trader_market
gen num_single_market = (num_trader_market==1)
save "$temp/tempptentry.dta", replace
restore

append using "$temp/tempptentry.dta"
label var num_single_market "Single sample market trader"
label var num_trader_market "Number sample markets visited"

local vars regular_trader new_trader worked_with_all_before know_well_yn know_well_somewhat_well num_single_market num_trader_market discuss_good_price_yn discuss_good_price_mkt dicuss_good_price_with_prc_ifyes agreement_price_yn agreement_price_mkt agreement_price_with_prc_ifyes 
local numvars : word count `vars'
tokenize `vars'

forvalues i = 1/`numvars' {
	sum ``i'' 
	mat b = (r(mean), r(sd), r(N))
	if `i'==1 {
		mat d = b
		}
		else {
		mat d = d\b
		}
	}
mat rownames d = `vars'

matrix g = (., .,  .) \ d[1..7, 1...] \ (., ., .) \ d[8..13, 1...] 
matrix p = z[1..8, 1..2],z[1..8, 5]
matrix j = (., .,  .) \ p \ g

gen temp_name1 = .
label var temp_name1 "\emph{\textbf{Market Experience}}"
gen temp_name2 = .
label var temp_name2 "\emph{\textbf{Collusion Reports}}"
gen temp_name3 = .
label var temp_name3 "\emph{\textbf{Self-Reported Mark-ups}}"
gen temp_name4 = .
label var temp_name4 "\emph{\textbf{Sale Characteristics}}"
gen temp_name5 = .
label var temp_name5 "\emph{\textbf{Education and Business Characteristics}}"

mat rownames g = temp_name1 regular_trader new_trader worked_with_all_before know_well_yn know_well_somewhat_well ///
 temp_name2 discuss_good_price_yn discuss_good_price_mkt dicuss_good_price_with_prc_ifyes agreement_price_yn agreement_price_mkt agreement_price_with_prc_ifyes 
 
 mat rownames j = temp_name5 prct_comp_pri prct_comp_sec ravens_prct fin_review_monthly any_written_records any_emp num_emp lorry_trader ///
temp_name1 regular_trader new_trader worked_with_all_before know_well_yn know_well_somewhat_well num_single_market num_trader_market ///
 temp_name2 discuss_good_price_yn discuss_good_price_mkt dicuss_good_price_with_prc_ifyes agreement_price_yn agreement_price_mkt agreement_price_with_prc_ifyes 
 
frmttable using "$output_table/trader_side3_rep", statmat(j) replace va tex fra ///
	ctitles("","Mean","Std. Dev.", "Obs") ///
	sdec(0, 0, 0 \ 2, 2, 0 \ 2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \ 0, 0, 0 \ 2, 2, 0 \ 2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0  \ 0, 0, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0 \2, 2, 0  )

*************
/*Table A.2*/
*************

use "$data/WR Customer Survey_appended.dta", clear

*weight to be representative of consumer population
gen weight = 42.77/50 if  pre_cust_type == "Vendor"
replace weight = 57.23/50 if  pre_cust_type == "Households/general customers"

*how often buy
gen often_buy_per_week = a_1
replace often_buy_per_week = a_1*7 if a_2 ==1
replace often_buy_per_week = a_1/4 if a_2 ==3
replace often_buy_per_week = a_1/52 if a_2 ==4

*construct vars
gen buy_once_a_week = (often_buy_per_week >=1)
gen num_markets = a_4
gen search_yes = (a_6!=4)
gen same_trader = (a_9==1)

label var num_markets "Number markets"
label var buy_once_a_week "Buys at least once a week"
label var search_yes "Search"
label var same_trader "Same trader"

*construct table
sum num_markets [aw=weight], det
mat b = (`r(mean)',`r(p50)',`r(sd)')
mat d = b
foreach var in  buy_once_a_week search_yes same_trader {
	sum `var' [aw=weight]
	mat b = (`r(mean)',. ,. )
	mat d = d\b
}

mat rownames d = num_markets buy_once_a_week search_yes same_trader
matrix list d

frmttable using "$output_table/consumer_survey_results_rep.tex", statmat(d) replace va tex fra ///
	ctitles("","Mean", "Median","SD") sdec(2, 2, 2) 
	

*************
/*Table C.1*/
*************

*gen last block's treatment status
use "$data/randomization_main.dta", clear
keep market_name block1 block2 block3

preserve
keep market_name block1
rename block1 last_block_treat
gen block = "2"
save "$temp/treat_last_block_b2.dta", replace
restore

keep market_name block2
rename block2 last_block_treat
gen block = "3"

append using "$temp/treat_last_block_b2.dta"

gen S1_last_block = (last_block_treat == "S1")
gen S2_last_block = (last_block_treat == "S2")
label var S1_last_block "Cost Shock Previous"
label var S2_last_block "Entry Previous"
drop last_block_treat

save "$temp/treat_last_block.dta", replace

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear
merge m:1 block market_name using "$temp/treat_last_block.dta"
drop if _m == 2
drop _m

gen week_1 = (week == 12 | week == 17 | week == 22)
gen week_2 = (week == 13 | week == 18 | week == 23)
gen week_3 = (week == 14 | week == 19 | week == 24)
gen week_4 = (week == 15 | week == 20 | week == 25)

label var S1 "Cost Shock"
label var S2 "Entry Market"

gen ln_num_trans_trim=log(num_trans_trim)
label var ln_num_trans_trim "Ln Num Customers"
label var ln_weighted_price_adj_trim "Ln Price"

xi: reg ln_weighted_price_adj_trim i.week i.market_name S1 S2 S1_last_block S2_last_block   [aweight=num_traders_inv], r cluster(market_block)
estadd local sample "Full Block"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo p_order

xi: reg ln_weighted_price_adj_trim i.week i.market_name S1 S2 S1_last_block S2_last_block if (week == 17 | week == 22)  [aweight=num_traders_inv], r cluster(market_block)
estadd local sample "W1 Only"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo p_order_w1

xi: reg ln_total_kgs_mkt_trim i.week i.market_name S1 S2 S1_last_block S2_last_block   [aweight=num_traders_inv], r cluster(market_block) 
estadd local sample "Full Block"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo q_order

xi: reg ln_total_kgs_mkt_trim i.week i.market_name S1 S2 S1_last_block S2_last_block if (week == 17 | week == 22)  [aweight=num_traders_inv], r cluster(market_block) 
estadd local sample "W1 Only"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo q_order_w1

xi: reg ln_num_trans_trim i.week i.market_name S1 S2 S1_last_block S2_last_block   [aweight=num_traders_inv], r cluster(market_block) 
estadd local sample "Full Block"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo t_order

xi: reg ln_num_trans_trim i.week i.market_name S1 S2 S1_last_block S2_last_block if (week == 17 | week == 22)  [aweight=num_traders_inv], r cluster(market_block)
estadd local sample "W1 Only"
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo t_order_w1

qui esttab q_order q_order_w1 t_order t_order_w1 p_order p_order_w1  ///
 using "$output_table/q_order_effects_updated_rep.tex", replace se label booktabs ///
noconstant star(* 0.10 ** 0.05 *** 0.01)  keep (S1_last_block) ///
stats(ymean N sample market week, labels ("Mean DV" "N" "Sample" "Market FE" "Week FE")) ///
nonote nonumbers 

eststo clear


****************************
/*Figure C.1 and Table C.2*/
****************************

use "$data/WR Hourly Trader Survey cleaned_trans.dta", clear

tostring qual, gen(qual_temp) force // convert to scale in which 4 = best
replace qual_tem = "4" if qual_temp == "1"
replace qual_tem = "3" if qual_temp == ".6600000262"
replace qual_tem = "2" if qual_temp == ".3300000131"
replace qual_tem = "1" if qual_temp == "0"
drop qual
destring qual_temp, replace
rename qual_temp qual

tostring trader_id, replace
gen trader_date = trader_id + date

gen household = 0 if cust_type !=.
replace household = 1 if cust_type == 3

sum amt_kg
gen amt_kg_SD = amt_kg/r(sd)
gen ln_price = ln(price_per_kg)
gen ln_q = ln(amt_kg)

label var ln_price "Ln Price"
label var amt_kg_SD "Quantity (1 SD)"
label var credit "Credit"
label var household "HH Customer"
label var qual "Quality (1-4, 4=best)"

xi: reg ln_price i.market_date qual, r cluster(trader_date)
estadd local mdfe "Yes"
estadd local controls "No"
estadd ysumm 
eststo qual_mdfe

xi: reg ln_price i.market_date credit, r cluster(trader_date)
estadd local mdfe "Yes"
estadd local controls "No"
estadd ysumm 
eststo credit_mdfe

xi: reg ln_price i.market_date amt_kg_SD household credit qual, r cluster(trader_date)
estadd local mdfe "Yes"
estadd local controls "Yes"
estadd ysumm 
eststo all_mdfe

*Table C.2
qui esttab qual_mdfe credit_mdfe all_mdfe  using "$output_table/prod_diff_baseline_nostar_rep.tex", replace se label booktabs  ///
noconstant nostar  keep (qual credit) ///
stats(ymean N mdfe controls, labels ("Mean Dep Var" "N" "Market-day FE" "Other Controls")) nonote 

xi: reg ln_price i.trader_date
predict resid_p, residuals

xi: reg ln_q i.trader_date
predict resid_q, residuals

*Figure C.1
twoway lpolyci resid_p resid_q, scheme(s1mono) yline(0, lp(longdash)) xtitle("Residual Log Quantity") ytitle("Residual Log Price",angle(horizontal)) legend(off)
graph export "$output_figure/price_disc_lpoly_rep.png", replace 
graph export "$output_figure/price_disc_lpoly_rep.eps", replace 

*************
/*Table F.1*/
*************

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

label var weighted_price_adj_trim "Price"
label var S1_amt "Cost Reduction"
label var S1_amt_high "Cost Reduction - High"
label var S1_amt_low "Cost Reduction - Low"

keep if S2==0
collapse (min) S1_low S1_high (sum) total_kgs_adj  num_trans (mean)  weighted_price_adj_trim, by(market_name week)
merge 1:1 market_name week using "$temp/market_name_week_market_block.dta"
gen kgs_per_trans = total_kgs_adj/num_trans
bys market_name: egen maxtrans = max(num_trans)
gen pct_HH = num_trans/maxtrans

xi: reg kgs_per_trans S1_low S1_high i.week i.market_name, r cluster(market_block) 
estadd ysumm 
eststo kgs_per_trans

xi: reg pct_HH S1_low S1_high i.week i.market_name, r cluster(market_block) 
estadd ysumm 
eststo pct_HH

xi: reg num_trans S1_low S1_high i.week i.market_name, r cluster(market_block) 
estadd ysumm 
eststo num_trans

xi: reg total_kgs_adj S1_low S1_high i.week i.market_name, r cluster(market_block) 
estadd ysumm 
eststo total_kgs_adj

label var kgs_per_trans "Kgs/Transaction"
label var pct_HH "Transaction Rate"
label var num_trans "Number Transactions"
label var total_kgs_adj "Total Kgs"

label var S1_high "High Cost Reduction Treatment"
label var S1_low "Low Cost Reduction Treatment"

qui esttab pct_HH kgs_per_trans using "$output_table/append_S1_quantitymoments_rep.tex", replace se label booktabs ///
nostar keep(S1_low S1_high _cons)  ///
stats(ymean, labels ("Mean Dep Var" )) ///
nonote 

eststo  clear

*************
/*Table G.1*/
*************

clear

use "$temp/S2_heterogeneous_effects", clear

local omega_abovemed_est = omegaS2_a[1]
local omega_belowmed_est = omegaS2_b[1]

local omega_ethmaj_est = omegaS2_j[1]
local omega_ethmin_est = omegaS2_n[1]

use "$temp/bootstrap/s2/S2_heter_bootstrap_coeff", clear
sort omegaS2_a
local omega_abovemed_CILB = omegaS2_a[25]
local omega_abovemed_CIUB = omegaS2_a[975]

sort omegaS2_b
local omega_belowmed_CILB = omegaS2_b[25]
local omega_belowmed_CIUB = omegaS2_b[975]

sort omegaS2_j
local omega_ethmaj_CILB = omegaS2_j[25]
local omega_ethmaj_CIUB = omegaS2_j[975]

sort omegaS2_n
local omega_ethmin_CILB = omegaS2_n[25]
local omega_ethmin_CIUB = omegaS2_n[975]

di `omega_abovemed_est'
di `omega_abovemed_CILB'
di `omega_abovemed_CIUB'
di `omega_belowmed_est'
di `omega_belowmed_CILB'
di `omega_belowmed_CIUB'

di `omega_ethmaj_est'
di `omega_ethmaj_CILB'
di `omega_ethmaj_CIUB'
di `omega_ethmin_est'
di `omega_ethmin_CILB'
di `omega_ethmin_CIUB'


mat f = (.,.,.)\(`omega_abovemed_est',`omega_abovemed_CILB',`omega_abovemed_CIUB')\(`omega_belowmed_est',`omega_belowmed_CILB',`omega_belowmed_CIUB')\(.,.,.)
foreach x in ethmaj  ethmin {
mat e = (`omega_`x'_est',`omega_`x'_CILB',`omega_`x'_CIUB')
mat f = f\e  
}

gen temp_name1 = .
label var temp_name1 "\emph{\textbf{Heterogeneous by profits}}"
gen temp_name2 = .
label var temp_name2 "$\omega^{above}_e$ Entrants with above median profits"
gen temp_name3 = .
label var temp_name3 "$\omega^{below}_e$ Entrants with below median profits"
gen temp_name4 = .
label var temp_name4 "\emph{\textbf{Heterogeneous by ethnicity}}"
gen temp_name5 = .
label var temp_name5 "$\omega^{maj}_e$ Entrants in ethnic majority"
gen temp_name6 = .
label var temp_name6 "$\omega^{min}_e$ Entrants in ethnic minority"


mat rownames f = temp_name1 temp_name2 temp_name3 temp_name4 temp_name5 temp_name6 

frmttable using "$output_table/S2_omega_appendix_rep.tex", statmat(f) replace va tex fra hline(1 1 0 0 0 0 0 1) ///
ctitles("\textbf{Group}","\textbf{Parameter Estimate}","\textbf{95\% CI LB}","\textbf{95\% CI UB}") ///
sdec(0,0,0\2,2,2\2,2,2\0,0,0\2,2,2\2,2,2) 


**************************************************
/*Table H.2, Table H.3, Table H.4, and Table H.5*/
**************************************************

*read in out of sample markets
insheet using "$data/Market Census Info_ALL COUNTIES_2016_02_03.csv", comma clear
drop if inlist(primary_mkt_day,"None","none","Not verified")
drop if atleast_1_trader=="no" | atleast_1_trader=="No"
replace market_name = lower(market_name)
replace market_name="kambi_ya_mwanza" if market_name=="kambi ya mwanza"
replace market_name="lugari station" if market_name=="lugari center"
replace market_name="malaha_(kakamega)" if market_name=="malaha"
replace market_name="matisi_(kitale)" if market_name=="matisi" & county=="Trans nzoia"
replace market_name="mayanja_bitungu" if market_name=="mayanja bitunguu"
replace market_name="mayanja_kibuke" if market_name=="mayanja(kibuke)"
replace market_name="webuye" if market_name=="webuye/ dina junction"

replace  market_name = "eshisiro" if market_name=="bukura" &  county=="Kakamega"  & sub_county=="Lurambi"
replace market_name = "ogalo" if market_name=="buhuyi (ogalo)" &  county=="Kakamega"  & sub_county=="Matungu"
replace market_name = "maili saba_1" if market_name=="maili saba" &  county=="Trans nzoia"  & sub_county=="Kiminini"
replace market_name = "makutano_1" if market_name=="makutano" &  county=="Kakamega"  & sub_county=="Lugari"
replace market_name = "sango3" if market_name=="sango" &  county=="Bungoma"  & sub_county=="Webuye East"
replace market_name = "sango2" if market_name=="sango" &  county=="Kakamega"  & sub_county=="Likuyani"

keep market_name  primary_mkt_day county sub_county
sort  market_name
ren  market_name market
duplicates drop
tempfile tempday
save `tempday', replace

use "$data/market_gps_map.dta", clear

* calculate prevalence of large markets
tab market_size
tab market_size if ifs

sort market
merge 1:1 market county sub_county using  `tempday'
drop if _m==2
drop  _m

replace primary_mkt_day = upper(primary_mkt_day)

tempfile tempbase
save `tempbase', replace
local numM = _N

local r1 = 3
local r2 = 5
local r3 = 10
local r4 = 25
local numr = 4

tempfile tempsave
forvalues m=1/`numM' {
	use `tempbase', clear
	keep if mktid==`m'
	local lat1 = gpslatitude
	local lon1 = gpslongitude
	local day  = primary_mkt_day
	use `tempbase', clear
	drop  if mktid==`m'
	
	gen lat1  =  `lat1'
	gen lon1 = `lon1'
	
	geodist lat1 lon1  gpslatitude gpslongitude, gen(dist)
	
	forvalues rr=1/`numr' {
	
	gen dist`r`rr''s =  (dist<=`r`rr'' &  inlist(market_size,"Small","small","tiny"))
	gen dist`r`rr''m =  (dist<=`r`rr'' &  inlist(market_size,"Medium","medium"))
	gen dist`r`rr''l =  (dist<=`r`rr'' &  inlist(market_size,"Large","large"))
	
	gen dist`r`rr''s_in =  dist`r`rr''s*ifsampled
	gen dist`r`rr''m_in =  dist`r`rr''m*ifsampled
	gen dist`r`rr''l_in =  dist`r`rr''l*ifsampled
	
	gen distsame`r`rr''s =  (dist<=`r`rr'' &  inlist(market_size,"Small","small","tiny")) & primary_mkt_day=="`day'"
	gen distsame`r`rr''m =  (dist<=`r`rr'' &  inlist(market_size,"Medium","medium")) & primary_mkt_day=="`day'"
	gen distsame`r`rr''l =  (dist<=`r`rr'' &  inlist(market_size,"Large","large")) & primary_mkt_day=="`day'"
	
	gen distsame`r`rr''s_in =  dist`r`rr''s*ifsampled if primary_mkt_day=="`day'"
	gen distsame`r`rr''m_in =  dist`r`rr''m*ifsampled if primary_mkt_day=="`day'"
	gen distsame`r`rr''l_in =  dist`r`rr''l*ifsampled if primary_mkt_day=="`day'"
	
	}
	
	replace  mktid = `m'
	drop dist
	collapse (sum) dist*,  by(mktid)
	
	if `m'>1  {
		append  using `tempsave'
	}
	sort mktid
	save `tempsave', replace

}

assert dist`r1's>=dist`r1's_in
assert dist`r1'm>=dist`r1'm_in
assert dist`r1'l>=dist`r1'l_in

merge 1:1 mktid using `tempbase'
assert  _m==3
drop _m

sort market

ren market market_name

gen numNeighbors5 = dist5s+dist5m+dist5l
gen numNeighborsame5 = distsame5s+distsame5m+distsame5l
tab numNeighbors5 if inlist(market_size,"Large","large") & ifsampled==1
tab numNeighborsame5 if inlist(market_size,"Large","large") & ifsampled==1

drop numNeighbors5 numNeighborsame5

save "$temp/market_num_neighbors.dta", replace

use "$data/WR Hourly Trader Survey cleaned_trader2.dta", clear

sort market_name
merge n:1 market_name using "$temp/market_num_neighbors.dta"
assert _m!=1
assert ifsampled==0 if  _m==2
drop if _m==2
drop _m


foreach r in "3" "5" "10" "25" {
	gen  S1_amt_numNeighbors`r' = S1_amt*(dist`r's+dist`r'm+dist`r'l)
	gen  S1_amt_numNeighbors`r'l = S1_amt*(dist`r'l)
	gen  S1_amt_numNeighbors`r'sm = S1_amt*(dist`r's+dist`r'm)
	gen  S1_amt_numNeighbors`r's = S1_amt*(dist`r's)
	gen  S1_amt_numNeighbors`r'm = S1_amt*(dist`r'm)
	
	gen  S1_amt_numNeighborsame`r' = S1_amt*(distsame`r's+distsame`r'm+distsame`r'l)
	gen  S1_amt_numNeighborsame`r'sm = S1_amt*(distsame`r's+distsame`r'm)
	gen  S1_amt_numNeighborsame`r's = S1_amt*(distsame`r's)
	gen  S1_amt_numNeighborsame`r'm = S1_amt*(distsame`r'm)
	gen  S1_amt_numNeighborsame`r'l = S1_amt*(distsame`r'l)
}

*calculate price effects
gen large = inlist(market_size,"Large","large")
gen medium = inlist(market_size,"Medium","medium")
gen small =  inlist(market_size,"Small","small","tiny")


xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local sample "All"
estadd ysumm 
eststo price_baseline


xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 & large==0 [aweight=num_traders_inv], r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local sample "No Large"
estadd ysumm 
eststo price_nolarge

xi: reg weighted_price_adj_trim i.week i.market_name S1_amt if S2!=1 & market_name!="malaha_(kakamega)" & market_name!="matisi_(kitale)" [aweight=num_traders_inv], r cluster(market_block) 
estadd local market "Yes"
estadd local week "Yes"
estadd local sample "No Donors"
estadd ysumm 
eststo price_nodonors


foreach r in "3" "5" "10" {

	xi: reg weighted_price_adj_trim i.week i.market_name S1_amt S1_amt_numNeighborsame`r' if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo price_`r'_same
	
	xi: reg weighted_price_adj_trim i.week i.market_name S1_amt S1_amt_numNeighborsame`r'l if S2!=1 [aweight=num_traders_inv], r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo price_`r'_samel
	
	


}


gen numNeighborsame5 = distsame5s+distsame5m+distsame5l
gen numNeighborsame5l = distsame5l

gen numNeighborsame5_in = distsame5s_in+distsame5m_in+distsame5l_in
gen numNeighborsame5l_in = distsame5l_in

gen frac5_in = numNeighborsame5_in/numNeighborsame5
gen frac5l_in = numNeighborsame5l_in/numNeighborsame5l

sort market_name week
summ frac5_in frac5l_in if market_name!=market_name[_n-1]

keep if S2==0

collapse (min) S1_low S1_high S1_amt* numNeighborsame5 numNeighborsame5l (sum) total_kgs_adj num_trans (mean) dist* weighted_price_adj_trim, by(market_name week market_size)
merge 1:1 market_name week using "$temp/market_name_week_market_block.dta"

areg total_kgs_adj S1_amt  i.week, ab(market_name) r cluster(market_block)
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo kgs_baseline


foreach r in "3" "5" "10" {


	areg total_kgs_adj S1_amt S1_amt_numNeighborsame`r'  i.week, ab(market_name) r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo kgs_`r'_same
	
	areg total_kgs_adj S1_amt S1_amt_numNeighborsame`r'l  i.week, ab(market_name) r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo kgs_`r'_samel

}


areg num_trans S1_amt  i.week, ab(market_name) r cluster(market_block)
estadd local market "Yes"
estadd local week "Yes"
estadd ysumm 
eststo trans_baseline

foreach r in "3" "5" "10" {

	areg num_trans S1_amt S1_amt_numNeighborsame`r'  i.week, ab(market_name) r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo trans_`r'_same
	
	areg num_trans S1_amt S1_amt_numNeighborsame`r'l  i.week, ab(market_name) r cluster(market_block) 
	estadd local market "Yes"
	estadd local week "Yes"
	estadd ysumm 
	eststo trans_`r'_samel

}

*calculate the prevalence of large, same-day neighbors:
summ numNeighborsame5 numNeighborsame5l

label var weighted_price_adj_trim "Price"
label var total_kgs_adj "Kgs"
label var num_trans "Trans"
label var S1_amt "Cost Change"

foreach r in "3" "5" "10" "25" {
label var S1_amt_numNeighborsame`r' "CC x Num Neigh `r'km"
label var S1_amt_numNeighborsame`r'sm "CC x Num SmMed Neigh `r'km"
label var S1_amt_numNeighborsame`r'l "CC x Num Large Neigh `r'km"
}

qui esttab kgs_baseline kgs_10_same kgs_10_samel kgs_5_same kgs_5_samel kgs_3_same kgs_3_samel   using "$output_table/S1_kgs_neighbors_same_univar_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1*) ///
stats(ymean N market week, labels ("Mean Dep Var" "N" "Market FE" "Week FE")) ///
nonote 

qui esttab trans_baseline trans_10_same trans_10_samel trans_5_same trans_5_samel trans_3_same trans_3_samel  using "$output_table/S1_trans_neighbors_same_univar_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1*) ///
stats(ymean N market week, labels ("Mean Dep Var" "N" "Market FE" "Week FE")) ///
nonote 

qui esttab price_baseline price_10_same price_10_samel price_5_same price_5_samel price_3_same price_3_samel  using "$output_table/S1_price_neighbors_same_univar_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1*) ///
stats(ymean N market week, labels ("Mean Dep Var" "N" "Market FE" "Week FE")) ///
nonote 

qui esttab price_baseline price_nolarge price_nodonors using "$output_table/S1_price_neighbors_same_checks_nostar_rep.tex", replace se label booktabs ///
noconstant nostar  keep(S1*) ///
stats(ymean N market week sample, labels ("Mean Dep Var" "N" "Market FE" "Week FE" "Sample")) ///
nonote

*************
/*Table J.1*/
*************

use "$data/DW_cleaned_plus_custnum.dta", clear

label var price "Price"
label var old_amount "Quantity"

xi: reg price i.subsidy
estadd local marketdayFE "No"
estadd ysumm 
local ftest = round(Ftail(e(df_m), e(N) - e(df_m) - 1, e(F)),0.01)
estadd local ftest `ftest'
eststo r1

xi: reg old_amount i.subsidy
estadd local marketdayFE "No"
estadd ysumm 
local ftest = round(Ftail(e(df_m), e(N) - e(df_m) - 1, e(F)),0.01)
estadd local ftest `ftest'
eststo r2

label var subsidy "Subsidy Amount"
forval i = 1/10{
	label var _Isubsidy_`i' "Subsidy Level `i'"
}

qui esttab r1 r2  using "$output_table/demand_balance_nostar_rep.tex", replace se label booktabs b(%10.2f) sfmt(%10.2f %10.0f) ///
noconstant nostar  keep(*subsidy*) ///
stats(ymean N ftest, fmt(%10.2f %10.0f %10.2f) labels ("Mean Dep Var" "N" "F-Test"))  nonote nonum

eststo clear

