function [obj] = D2b_general_demand_obj(param,int_data,W)
%% objective function
% parameters
delta = param(1);
mu = param(2);
sigma = param(3);

%% data
% DW data
iv = int_data.iv;
p_prior = int_data.p_prior;
q_prior = int_data.q_prior;
p_post = int_data.p_post;
log_dq = int_data.log_dq;
market_id= int_data.market_id;
S = int_data.S; 

% market-week average price
pC = int_data.pC;
pS1low = int_data.pS1low;
pS1high = int_data.pS1high;

% extensive - average percentage of purchase - data
cdfS1lowdata = int_data.cdfS1_low;
cdfS1highdata = int_data.cdfS1_high;
cdfCdata = int_data.cdfC;

% intensive - average kg per trans - data
int_C_data = int_data.b_int_C;
int_S1_low_data = int_data.b_int_S1_low;
int_S1_high_data = int_data.b_int_S1_high;

%% DW moments
% simulate a_j
NDdraws_r_j = S1_simulate_aj(mu, sigma, int_data);
aj_for_i = NDdraws_r_j(market_id,:);

% residuals
e = mean(...
    log_dq*ones(1,S)...
    -1/delta*((log((aj_for_i-p_post*ones(1,S))./(aj_for_i-p_prior*ones(1,S)))))...
    , 2);
% moment1
mom1 = (1/size(iv,1))*iv' * e;

%% extensive moments
cdfC = 1-normcdf(pC,mu,sigma);
cdfS1low = 1-normcdf(pS1low,mu,sigma);
cdfS1high = 1-normcdf(pS1high,mu,sigma);

mom2 = [cdfC-cdfCdata ; cdfS1low-cdfS1lowdata ; cdfS1high-cdfS1highdata];
%% intensive moments
bj_for_i = (aj_for_i-p_prior*ones(1,S)) ./ ((q_prior*ones(1,S)).^delta);
bj_for_i((aj_for_i-p_prior*ones(1,S)) <= 0) = nan;

aj_for_i_C = aj_for_i;
aj_for_i_C((aj_for_i-pC)<=0) = nan;
predqC = nanmean(nanmean(((aj_for_i_C-pC )./bj_for_i).^(1/delta),2),1);
aj_for_i_S1low = aj_for_i;
aj_for_i_S1low((aj_for_i-pS1low)<=0) = nan;
predqS1low = nanmean(nanmean(((aj_for_i_S1low-pS1low )./bj_for_i).^(1/delta),2),1);
aj_for_i_S1high = aj_for_i;
aj_for_i_S1high((aj_for_i-pS1high)<=0) = nan;
predqS1high = nanmean(nanmean(((aj_for_i_S1high-pS1high )./bj_for_i).^(1/delta),2),1);

% moment 3
mom3 = [predqC-int_C_data ; predqS1low-int_S1_low_data ; predqS1high-int_S1_high_data];

%% combine three sets of moments
mom = [mom1;mom2;mom3];

% objective function
obj = size(iv,1)*mom'*W*mom;

end
