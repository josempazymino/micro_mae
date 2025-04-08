********************************************************************************
* prepare data for counterfactuals
********************************************************************************

* recover supply side parameters (cost functin)
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

keep if S2==0

egen mkt_index = group(mkt_id)
egen week_index = group(week)
egen mkt_week_index = group(mkt_id week)


preserve

keep mkt_index week_index mkt_week_index kgs_own_adj weighted_price_jt p_cost_adj_jt cost_intercept gamma_est
order mkt_index week_index mkt_week_index cost_intercept kgs_own_adj weighted_price_jt p_cost_adj_jt gamma_est

outsheet using "$temp/S1_CF_data.csv", comma replace

restore




