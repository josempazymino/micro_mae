%% Calculate demand derivatives aggregated from transaction level
clear all;

rng('default')
rng(20190123)

%% estimated intensive parameters

load('../../temp/general_demand_estimates')
clearvars -except  delta mu sigma
delta_all = delta;
mu_all = mu;
sigma_all = sigma;
%% transaction level data
transaction_level_data = readtable('../../temp/transaction_analysis_data.csv');
trans_amt_kg = transaction_level_data.amt_kg_trim;
trans_price_per_kg = transaction_level_data.price_per_kg_trim;

%% preset parameters
% pre-set simuluation of heterogeneous a 
S = 1; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw
BBB = 100; % number of bootstraps
numS = 100; % number of simulations of a and b to calculate derivatives 
%% calculate draws over each 

for bbb = 1 : 1
    %% extensive data
    extensivetdata = readtable('../../temp/market_analysis_data_trim.csv');
    total_kgs = extensivetdata.total_kgs_mkt;
    % own price
    ext_price = extensivetdata.weighted_price_jt;

    %%  draw a and calc b 
    rng(20190123+bbb)
    % estimated parameters
    delta = delta_all(bbb);
    mu = mu_all(bbb);
    sigma = sigma_all(bbb);

    % random draws
    UDraws = rand(size(trans_amt_kg,1), S); 
    NDraws = randn(SS,1);
    NDraws = sort(NDraws);
    
    % transaction level data data
    trans_data = struct('num_a', size(trans_amt_kg,1), ...
                        'lb_price', trans_price_per_kg, ... 
                        'UDraws', UDraws, ...
                        'NDraws', NDraws, ...
                        'S', S, ...
                       'SS', SS);
    % simulate a and calculate b
    a = S1_simulate_aj(mu, sigma, trans_data);
    b = (a-trans_price_per_kg) ./ (trans_amt_kg.^delta);
    %% compute derivatives
    % number of simulations to eval derivatives
    temp_store = nan(size(ext_price,1),numS);
    for s = 1:numS
        % resample a and b
        a_r = datasample(a,size(a,1));
        b_r = datasample(b,size(b,1));
        % for each extensive week-market, aggregate derivative at trans level
        for t = 1:size(ext_price,1)
            % predicted trans level quanity
            temp = (a_r-ext_price(t));
            a_r_positive = a_r(temp>0,:); % only keep as > market level market price
            b_r_positive = b_r(temp>0,:); % only keep as > market level market price
            qS = ((a_r_positive-ext_price(t))./b_r_positive).^(1/delta); % predicted trans level quantity
            qS = qS(~any(ismissing(qS),2),:);
            % market level quantity
            gap = total_kgs(t);
            iter = 1;
            store = 0;
            maxiter = size(qS, 1);
            % adds up trans level derivatives
            while  gap > 0 && maxiter > 0
                gap = gap - qS(iter);
                if gap >= 0 
                    store = store + (-1/delta) * qS(iter) / (a_r_positive(iter)-ext_price(t));
                elseif gap <0
                    store = store + (-1/delta) * (gap +  qS(iter)) / (a_r_positive(iter)-ext_price(t));
                end
                iter = iter + 1;
                if iter > maxiter
                    iter = 1;
                end
            end
            temp_store(t,s) = store;
        end
    end

    %% mean derivatives across simulations
    invdQdp_int_sim = mean( 1 ./ temp_store , 2);
    tt = table(extensivetdata.market_name, extensivetdata.week, invdQdp_int_sim, ...
        'VariableNames',{'market_name','week','invdQdp_int_sim'});
    writetable(tt,strcat('../../temp/mkt_week_derivatives','.csv'),'Delimiter',',','QuoteStrings',true)
end

