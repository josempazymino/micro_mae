% calculate Cournot equilibrium (for use in entry model)

clearvars;

rng('default')
rng(20190611)


% read in mu, sigma, delta from demand side

load('../../temp/general_demand_estimates')
clearvars -except  delta mu sigma

%% preset parameters
% pre-set simuluation of heterogeneous a 
S = 100; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw

% read in transaction data for estimating b

transaction_level_data = readtable('../../temp/transaction_analysis_data.csv');
trans_amt_kg = transaction_level_data.amt_kg_trim;
trans_price_per_kg = transaction_level_data.price_per_kg_trim;


% read in supply data
S2_CF_data = readtable('../../temp/S2_CF_data.csv');

ext_price = accumarray(S2_CF_data.mkt_week_index,S2_CF_data.p_cost_adj_jt,[],@max);
total_kgs = accumarray(S2_CF_data.mkt_week_index,S2_CF_data.kgs_own_adj,[],@sum);

gamma = S2_CF_data.gamma_est(1);


% construct market-week specific [a,b] distribution

    % random draws
    UDraws = rand(size(trans_amt_kg,1), S); % length = transaction length
    NDraws = randn(SS,1);
    NDraws = sort(NDraws);
    
    % transaction level data data
    trans_data = struct('num_a', size(trans_amt_kg,1), ...
                        'lb_price', trans_price_per_kg, ... % lower bound price = own price
                        'UDraws', UDraws, ...
                        'NDraws', NDraws, ...
                        'S', S, ...
                       'SS', SS);
    % simulate a and calculate b
    a = S1_simulate_aj(mu, sigma, trans_data);
    b = (a-trans_price_per_kg) ./ (trans_amt_kg.^delta);
    
num_mkt_wk = length(total_kgs);

ind = (1:length(a))'*ones(1,S);

a_all_mkts = zeros(size(a,1),size(a,2),num_mkt_wk);
b_all_mkts = zeros(size(b,1),size(b,2),num_mkt_wk);

max_cutoff = 0;


for j=1:num_mkt_wk
    
baseline_mkt_p = ext_price(j);
baseline_mkt_Q = total_kgs(j);

a_mkt = a;
b_mkt = b;
    
for s=1:S

    a_r = datasample(a(:,s),size(a,1));
    b_r = datasample(b(:,s),size(b,1));
    
    a_mkt(:,s) = a_r;
    b_mkt(:,s) = b_r;
    
    a_positive = a_r(a_r>baseline_mkt_p);
    b_positive = b_r(a_r>baseline_mkt_p);
    ind_positive = ind(a_r>baseline_mkt_p);

    baseline_q = ((a_positive-baseline_mkt_p)./b_positive).^(1/delta);

    baseline_cum_Q = cumsum(baseline_q);
    cutoff = find(baseline_cum_Q>baseline_mkt_Q,1);

    a_mkt(ind_positive(cutoff)+1:end,s) = 0;
    b_mkt(ind_positive(cutoff)+1:end,s) = 0;
    
    % adjust b of last draw to give exact market quantity
    if cutoff>1
    q_last = baseline_mkt_Q - baseline_cum_Q(cutoff-1);

    end
    if cutoff==1
    q_last = baseline_mkt_Q;

    end
    b_mkt(cutoff,s) = (a_positive(cutoff)-baseline_mkt_p)/q_last^delta;
    
    max_cutoff = max(max_cutoff,cutoff);
    
end

a_all_mkts(:,:,j) = a_mkt;
b_all_mkts(:,:,j) = b_mkt;

end

a_all_mkts = a_all_mkts(1:max_cutoff,:,:);

b_all_mkts = b_all_mkts(1:max_cutoff,:,:);

save('../../temp/S2_sim_consumers','a_all_mkts','b_all_mkts');


%% estimate monopoly quantities and prices, in the absence of entry

para = zeros(20,num_mkt_wk);
Cournot_price = zeros(num_mkt_wk,1);


options = optimset('MaxFunEvals',1E8,'MaxIter',1E8,'TolX',1E-4,'TolFun',1E-4);


parfor j=1:num_mkt_wk
    
fprintf('simulation %.0f, market %0.f \n',1,j)
    
ind_est = j;

S2_trader = S2_CF_data.S2_trader(S2_CF_data.mkt_week_index==ind_est);


x0 = S2_CF_data.kgs_own_adj(S2_CF_data.mkt_week_index==ind_est);
x0(S2_trader==1)=[];

costs = S2_CF_data.cost_intercept(S2_CF_data.mkt_week_index==ind_est);
costs(S2_trader==1)=[];

f = @(x) E05_FOCs(x,costs,gamma,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),0,ext_price(ind_est));
try

para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];

totalQ = sum(para(:,j));

q = para(:,j);

% iterate multiple times to avoid local equilibria

if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = para(:,j);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = para(:,j);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = para(:,j);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = para(:,j);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
para(:,j) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = para(:,j);
end

% find the price that corresponds to this totalQ

priceS = zeros(1,S);

a_j = squeeze(a_all_mkts(:,:,ind_est));
b_j = squeeze(b_all_mkts(:,:,ind_est));


for s=1:S
f = @(x) E06_invert_demand(x,totalQ,delta,a_j(:,s),b_j(:,s));
priceS(s) = fminsearch(f,ext_price(j));
end

Cournot_price(j) = mean(priceS);

catch
    j
end

end


mkt_week_index = S2_CF_data.mkt_week_index;

save('../../temp/S2_Cournot','Cournot_price','mkt_week_index');
