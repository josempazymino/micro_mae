% general demand bootstrap

rng('default')
rng(20190123)

switch getenv('PBS_ENVIRONMENT')
    case {'PBS_BATCH'}
    otherwise
        disp([ 'Not using batch PBS. Switch to _NOPBS m file'])
end

%% job ID
temp = extractBetween(getenv('PBS_JOBID'),'[',']');
temp = temp{1,1};
startB = str2num(temp);
endB =  str2num(temp);
clear temp

%% data

for bbb = startB : endB
    %% extensive moments - bootstrap
    int_moments_data = readtable(strcat('../../temp/bootstrap/moments/quantity_moments_',num2str(bbb),'.csv'));% gen by MS02
    %% bootstrap intensive data
    rng(20190123+bbb)
    intensivetdata_temp = load(strcat('../../temp/bootstrap/resample_data/demand_exp_data_',num2str(bbb))); 
    intensivetdata = intensivetdata_temp.intensivetdata;
    selection = logical(intensivetdata.p0 >-10000);
    intensivetdata = sortrows(intensivetdata, 1); % order by market ID already

    num_a = size(unique(intensivetdata.market_name(selection)),1);

    temp_mid = intensivetdata.mid(selection);
    temp_mid_index = unique(temp_mid);%  market ID list
    market_id = nan(size(temp_mid));
    for i = 1: num_a
        market_id(temp_mid == temp_mid_index(i),:) = i; % recreated ID from 1 to max by 1
    end

    p_prior = intensivetdata.p0(selection);
    p_post = intensivetdata.p1(selection);
    q_prior = intensivetdata.q0(selection);
    q_post = intensivetdata.q1(selection);
    log_dq = log(q_post) - log(q_prior);
    subsidy = intensivetdata.subsidy(selection);

    sub_id = dummyvar(grp2idx(intensivetdata.subsidy(selection)));

    % price: lower bound of market price
    lb_price = nan(num_a,1);
    for i = 1: num_a
        lb_price(i) = max(p_prior(market_id == i));
    end

    S = 1000; % sample size used to evaluate 
    UDraws = rand(num_a, S);
    SS = 1e6;
    NDraws = randn(SS,1);
    NDraws = sort(NDraws);

    %% Variable 
    iv = sub_id(:,1:end); % iv for endogeneous regressors
    % input variables
    cdfVarCov = eye(6);
    % extensive - average percentage of purchase - data
    cdfVarCov(1,1) = int_moments_data.varcc_mktcdf;
    cdfVarCov(2,2) = int_moments_data.varll_mktcdf;
    cdfVarCov(3,3) = int_moments_data.varhh_mktcdf;
    % intensive - average kg per trans - data
    cdfVarCov(4,4) = int_moments_data.varcc_int_mktcdf;
    cdfVarCov(5,5) = int_moments_data.varll_int_mktcdf;
    cdfVarCov(6,6) = int_moments_data.varhh_int_mktcdf;
    % covariance matrix
    cdfVarCov(1,4) = int_moments_data.covcc;
    cdfVarCov(2,5) = int_moments_data.covll;
    cdfVarCov(3,6) = int_moments_data.covhh;
    cdfVarCov(4,1) = int_moments_data.covcc;
    cdfVarCov(5,2) = int_moments_data.covll;
    cdfVarCov(6,3) = int_moments_data.covhh;
    
    int_data = struct('iv', iv, ...
                    'p_prior', p_prior, ...
                    'q_prior', q_prior, ...
                    'p_post', p_post, ...
                    'log_dq', log_dq, ...
                    'market_id', market_id, ...
                    'num_a', num_a, ...
                    'lb_price', lb_price, ...
                    'UDraws', UDraws, ...
                    'NDraws', NDraws, ...
                    'S', S, ...
                    'SS', SS,...
                    'pC' , int_moments_data.b_int_price_C_trader, ...
                    'pS1low' , int_moments_data.b_int_price_S1_low_trader, ...
                    'pS1high' , int_moments_data.b_int_price_S1_high_trader, ...
                    'cdfS1_low' , int_moments_data.b_transcdf_S1_low_mkt, ...
                    'cdfS1_high' , int_moments_data.b_transcdf_S1_high_mkt, ...
                    'cdfC' , int_moments_data.b_transcdf_C_mkt, ...
                    'b_int_C' , int_moments_data.b_int_cdf_C_mkt, ...
                    'b_int_S1_low' , int_moments_data.b_int_cdf_S1_low_mkt, ...
                    'b_int_S1_high', int_moments_data.b_int_cdf_S1_high_mkt, ...   
                    'cdfVarCov',cdfVarCov);   
    
    %% estimation 
    [para] = D2a_general_demand_estimation(3,1e9,int_data);

    %% eta and b
    delta = para(1);
    mu = para(2);
    sigma = para(3);


    
    delta_all(bbb,1) = delta;
    mu_all(bbb,1) = mu;
    sigma_all(bbb,1) = sigma;



end

save(strcat('../../temp/bootstrap/demand_est/demand_est_data_',num2str(startB)));
