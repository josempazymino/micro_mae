%% Master file to calculate counterfactuals

clearvars;

rng('default')
rng(20190812)


% read in mu, sigma, delta from demand side

load('../../temp/general_demand_estimates')
clearvars -except  delta mu sigma


%% preset parameters
% pre-set simuluation of heterogeneous a 
S = 100; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw

    options = optimset('MaxFunEvals',1E8,'MaxIter',1E8,'TolX',1E-10,'TolFun',1E-10);

% read in transaction data for estimating b

transaction_level_data = readtable('../../temp/transaction_analysis_data.csv');
trans_amt_kg = transaction_level_data.amt_kg_trim;
trans_price_per_kg = transaction_level_data.price_per_kg_trim;


% read in supply data
S1_CF_data = readtable('../../temp/S1_CF_data.csv');

ext_price = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.p_cost_adj_jt,[],@max);
total_kgs = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.kgs_own_adj,[],@sum);


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

% loop over market-weeks
% simulate demand (consumers) in each market

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

save('../../temp/S1_sim_consumers','a_all_mkts','b_all_mkts');

%% preset parameters
% pre-set simuluation of heterogeneous a 
S = 100; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw


options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-4,'TolFun',1E-4);

% read in supply data
S1_CF_data = readtable('../../temp/S1_CF_data.csv');


ext_price = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.p_cost_adj_jt,[],@max);
total_kgs = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.kgs_own_adj,[],@sum);

gamma_est = S1_CF_data.gamma_est(1);



num_mkt_wk = length(total_kgs);



load('../../temp/S1_sim_consumers','a_all_mkts','b_all_mkts');



omega_grid_points = 11;



q_mat = zeros(20,num_mkt_wk,omega_grid_points);
p_mat = zeros(1,num_mkt_wk,omega_grid_points);

for ss=1:omega_grid_points

disp('Starting new simulation')

parfor j=1:num_mkt_wk

fprintf('simulation %.0f, market %0.f \n',ss,j)

% for each market-week, find equilibrium prices and quantities


ind_est = j;


x0 = S1_CF_data.kgs_own_adj(S1_CF_data.mkt_week_index==ind_est);

costs = S1_CF_data.cost_intercept(S1_CF_data.mkt_week_index==ind_est);

f = @(x) E05_FOCs(x,costs,gamma_est,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),(ss-1)/(omega_grid_points-1),ext_price(ind_est));

try

q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];

q = q_mat(:,j,ss);

% iterate several times in solving for equilibrium to avoid local
% equilibria

if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = q_mat(:,j,ss);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = q_mat(:,j,ss);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = q_mat(:,j,ss);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = q_mat(:,j,ss);
end
if max(abs(q(1:length(x0))-x0))>10   
x0 = q(1:length(x0));
q_mat(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q = q_mat(:,j,ss);
end

totalQ = sum(q);

% find the price that corresponds to this totalQ

priceS = zeros(1,S);
a_j = squeeze(a_all_mkts(:,:,ind_est));
b_j = squeeze(b_all_mkts(:,:,ind_est));


for s=1:S
h = @(x) E06_invert_demand(x,totalQ,delta,a_j(:,s),b_j(:,s));
priceS(s) = fminsearch(h,ext_price(j));

end

p_mat(1,j,ss) = mean(priceS);

catch
    j
end


    
end

end

save('../../temp/S1_CF_grid');


