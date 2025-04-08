%% Master file to estimate demand
clear all;

rng('default')
rng(20190123)

%% data
int_moments_data = readtable('../../temp/quantity_moments.csv');

intensivetdata = readtable('../../temp/demand_exp_analysis_data.csv');
intensivetdata = sortrows(intensivetdata, 1); % order by market ID already
selection = logical(intensivetdata.p0 >-10000);
% variable
num_a = size(unique(intensivetdata.market_name(selection)),1);
market_id = intensivetdata.mid(selection);% order by market ID already
p_prior = intensivetdata.p0(selection);
p_post = intensivetdata.p1(selection);
q_prior = intensivetdata.q0(selection);
q_post = intensivetdata.q1(selection);
log_dq = log(q_post) - log(q_prior);
subsidy = intensivetdata.subsidy(selection);

sub_id = dummyvar(grp2idx(intensivetdata.subsidy(selection)));

% price lower bound
lb_price = nan(num_a,1);
for i = 1: num_a
    lb_price(i) = max(p_prior(market_id == i));
end

% pre-set simuluation of heterogeneous a 
S = 1000; % sample size used to evaluate 
UDraws = rand(num_a, S);
SS = 1e6;
NDraws = randn(SS,1);
NDraws = sort(NDraws);

%% Variable 
iv = sub_id(:,1:end); % iv for endogeneous regressors
% input variables
int_data.iv = iv;
int_data.p_prior = p_prior;
int_data.q_prior = q_prior;
int_data.p_post = p_post;
int_data.log_dq =log_dq;
int_data.market_id = market_id;
int_data.num_a =num_a;
int_data.lb_price = lb_price;
int_data.UDraws = UDraws;
int_data.NDraws = NDraws;
int_data.S  = S;
int_data.SS = SS;

% market-week average price
int_data.pC = int_moments_data.b_int_price_C_trader;
int_data.pS1low = int_moments_data.b_int_price_S1_low_trader;
int_data.pS1high = int_moments_data.b_int_price_S1_high_trader;
% extensive - average percentage of purchase - data
int_data.cdfS1_low = int_moments_data.b_transcdf_S1_low_mkt;
int_data.cdfS1_high = int_moments_data.b_transcdf_S1_high_mkt;
int_data.cdfC = int_moments_data.b_transcdf_C_mkt;
int_data.cdfVarCov = eye(6);
int_data.cdfVarCov(1,1) = int_moments_data.varcc_mktcdf;
int_data.cdfVarCov(2,2) = int_moments_data.varll_mktcdf;
int_data.cdfVarCov(3,3) = int_moments_data.varhh_mktcdf;
% intensive - average kg per trans - data
int_data.b_int_C = int_moments_data.b_int_cdf_C_mkt;
int_data.b_int_S1_low = int_moments_data.b_int_cdf_S1_low_mkt;
int_data.b_int_S1_high = int_moments_data.b_int_cdf_S1_high_mkt;
int_data.cdfVarCov(4,4) = int_moments_data.varcc_int_mktcdf;
int_data.cdfVarCov(5,5) = int_moments_data.varll_int_mktcdf;
int_data.cdfVarCov(6,6) = int_moments_data.varhh_int_mktcdf;
% covariance matrix
int_data.cdfVarCov(1,4) = int_moments_data.covcc;
int_data.cdfVarCov(2,5) = int_moments_data.covll;
int_data.cdfVarCov(3,6) = int_moments_data.covhh;
int_data.cdfVarCov(4,1) = int_moments_data.covcc;
int_data.cdfVarCov(5,2) = int_moments_data.covll;
int_data.cdfVarCov(6,3) = int_moments_data.covhh;

%% estimation 
% para = delta and a
[para] = D2a_general_demand_estimation(3,1e9,int_data);

%% eta and b
delta = para(1);
mu = para(2);
sigma = para(3);


    tt = table(delta,mu,sigma, ...
        'VariableNames',{'delta','mu','sigma'});
    writetable(tt,'../../temp/general_demand_estimates.csv','Delimiter',',','QuoteStrings',true)

fixpara_from_int_est.delta = delta;
fixpara_from_int_est.mu = mu;
fixpara_from_int_est.sigma = sigma;

save('../../temp/general_demand_estimates','-struct','fixpara_from_int_est');
 