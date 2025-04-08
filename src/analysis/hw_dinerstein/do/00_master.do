******** MASTER ANALYSIS FILE THAT CALLS ALL OTHER STATA PROGRAMS: DATA REPOSITORY openicpsr-119743 *****************

clear
clear all
clear matrix
set mem 200m
set more off, permanently
set maxvar 15000
set matsize 10000
set emptycells drop, permanently

version 15

* set path
global dir "" // enter directory here

global do "$dir/analysis_code/do" 
global data "$dir/data_clean" 
global temp "$dir/temp" 
global output_table "$dir/tables"
global output_figure "$dir/figures"
global logs "$dir/logs" 


/****** 1. Prepare Data for Demand and Supply Estimation ***********************************/


do "$do/01_prepare_analysis_data.do"
* prepares for analysis:
* transaction, trader, and market level data from control and cost shock markets
* transaction data from demand experiment

do "$do/02_prepare_analysis_data_bootstrap.do"
* prepares similar data for bootstrap

/****** 2. Estimate Demand in Simple Model ************************************************/

*** SWITCH TO MATLAB
/* run D1_simple_demand.m */
* estimates demand in simple model

/****** 3. Estimate Demand in General Model ***********************************/

*** SWITCH TO MATLAB
/* run D2_general_demand.m */
* estimates demand in general model

*** SWITCH TO MATLAB
/* run D3_general_demand_derivatives.m */
* estimates demand derivatives (using general model estimates), for use on supply side

/****** 4. Bootstrap Demand in General Model **********************************/


*** SWITCH TO MATLAB
/* run B1_resample_data.m */
* resamples demand experiment data for bootstrap model

*** SWITCH TO MATLAB. Run with a PBS job submission system (see corresponding .sh file).
* If you don't have a PBS job submission system, use the _NOPBS m file.
/* run B2_general_demand.m */
* general demand bootstrapped

*** SWITCH TO MATLAB
/* run B3_compile_demand.m */
* compile bootstrap demand estimates

*** SWITCH TO MATLAB. Run with a PBS job submission system (see corresponding .sh file).
* If you don't have a PBS job submission system, use the _NOPBS m file.
/* run B4_demand_derivatives.m */
* estimates bootstrapped demand derivatives (using general model estimates), for use on supply side


/****** 5. Estimate General Supply and Entry Models **************************************/

do "$do/03_supply_regressions.do"
* estimate general supply model (omega, gamma)
* estimate gamma in model imposing omega=1
* estimate effect of entry on competition
* estimate heterogeneous effect of entry on competition

/****** 6. Bootstrap General Supply and Entry Models *************************************/


do "$do/04_supply_regressions_bootstrap.do"
* bootstrapped version of 03
* plus perform non-nested test

/****** 7. Entry Model ********************************************************/


do "$do/05_prepare_entry_data.do"
* prepare data for model of entry

*** SWITCH TO MATLAB
/* run E01_monopoly.m */
* find equilibrium prices and quantities under monopoly

*** SWITCH TO MATLAB
/* run E02_cournot.m */
* find equilibrim prices and quantities under Cournot

*** SWITCH TO MATLAB
/* run E03_grid.m */
* find potential entrant profits under monopoly and Cournot
* E01, E02, E03 pre-calculates prices/quantities/profits under different entry and competition scenarios, to make model estimation faster

*** SWITCH TO MATLAB
/* run E04_entry_model.m */
* estimate cost parameters in model of trader entry

/****** 8. Bootstrap Entry Model *********************************************/

*** SWITCH TO MATLAB. Run with a PBS job submission system (see corresponding .sh file).
* If you don't have a PBS job submission system, use the _NOPBS m file.
/* run B5_entry.m */
* bootstrapped version of E04

*** SWITCH TO MATLAB
/* run B6_entry_export.m */
* export bootstrapped estimates

/****** 9. Counterfactual ****************************************************/

do "$do/06_prepare_cf_data.do"
* prepare data from control and cost shock markets for counterfactual analysis

*** SWITCH TO MATLAB
/* run CF1_omega.m */
* solve for counterfactual equilibria under different assumptions about omega

*** SWITCH TO MATLAB
/* run CF1a_omega_surplus.m */
* calculate surplus under these conterfactual equilibria

/****** 10. Counterfactual with Exit ******************************************/

*** SWITCH TO MATLAB
/* run CF2_omega_exit.m */
* solve for counterfactual Cournot equilibria with exit

*** SWITCH TO MATLAB
/* run CF2a_omega_exit_surplus.m */
* calculate surplus under these conterfactual equilibria, with exit


/****** 11. Welfare Estimates *************************************************/

*** SWITCH TO MATLAB
/* run CF_competitive.m */
* find competitive equilibrium, for benchmarking welfare effects

do "$do/07_welfare_analysis.do"
* calculate welfare statistics (Section 8 of paper)
* calculate counterfactual statistics
* produce Figure 9

do "$do/08_welfare_analysis_bootstrap.do"
* calculate bootstrapped consumer surplus

/****** 12. Tables and Figures ****************************************************/

do "$do/09_figures_tables.do"
* produce all other tables and figures

/****** 13. Extra Paper Numbers ***************************************************/

do "$do/10_cited_numbers.do"
* produce numbers cited in text


