%% Master file to calculate counterfactuals with exit

clearvars;

rng('default')
rng(20190812)


% read in mu, sigma, delta from demand side

load('../../temp/general_demand_estimates')
clearvars -except  delta


load '../../temp/mc_fc_estimates' para2

mc_mu = para2(1);
fc_mu = para2(2);
mc_sigma = para2(3);
fc_sigma = para2(4);
mc_fc_rho = para2(5);


%% preset parameters
% pre-set simuluation of heterogeneous a 
S = 100; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw

simTrader = 10;

options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-4,'TolFun',1E-4);

% read in transaction data for estimating b

% read in supply data
S1_CF_data = readtable('../../temp/S1_CF_data.csv');

ext_price = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.p_cost_adj_jt,[],@max);
total_kgs = accumarray(S1_CF_data.mkt_week_index,S1_CF_data.kgs_own_adj,[],@sum);
mkt_price = S1_CF_data.weighted_price_jt;

gamma_est = S1_CF_data.gamma_est(1);



num_mkt_wk = length(total_kgs);



load('../../temp/S1_sim_consumers','a_all_mkts','b_all_mkts');

%% calculate variable profits in joint profit max eqm

variable_profit_omega1 = (mkt_price-S1_CF_data.cost_intercept-0.5*gamma_est*S1_CF_data.kgs_own_adj).*S1_CF_data.kgs_own_adj;
profit_negative = variable_profit_omega1<=0;

%  draw fixed costs consistent with MC and positive profis
logmc = log(S1_CF_data.cost_intercept);
logmc(S1_CF_data.cost_intercept<0) = min(logmc);

mean_fc = fc_mu+mc_fc_rho*fc_sigma / mc_sigma * (logmc-mc_mu);
sd_fc = fc_sigma^2 * (1-mc_fc_rho^2);

positive_profits_omega1 =  variable_profit_omega1;
positive_profits_omega1(profit_negative) = 1;

randdraws = rand(length(mean_fc),simTrader);
profits_conform  = positive_profits_omega1*ones(1,simTrader);
mean_fc_conform  = mean_fc*ones(1,simTrader);
sd_fc_conform =  sd_fc*ones(length(mean_fc),simTrader);



logfcdraw = mean_fc_conform+sd_fc_conform .* ...
    norminv(randdraws.*(normcdf((log(profits_conform)-mean_fc_conform)./sd_fc_conform)));
fc_sim = exp(logfcdraw);



load '../../temp/S1_CF_grid' q_mat p_mat;
q_start = squeeze(q_mat(:,:,1));
p_start = squeeze(p_mat(:,:,1));

q_mat = zeros(20,num_mkt_wk,simTrader);
p_mat = zeros(1,num_mkt_wk,simTrader);

minprofit = -1*ones(num_mkt_wk,simTrader);

traders_in = ones(20,num_mkt_wk,simTrader);

full_q_mat = zeros(20,num_mkt_wk,simTrader,20);

% simulate multiple FC draws
for ss=1:simTrader
    
traders_in_ss = squeeze(traders_in(:,:,ss));
qall = ones(20,length(S1_CF_data.mkt_week_index));

disp('Starting new simulation')


% loop over up to 20 traders
% each iteration considers whether a trader exits
for jj=2:20
    
    

    
   
if jj==2
    
parfor j=1:num_mkt_wk  
    
ind_est = j;

costs = S1_CF_data.cost_intercept(S1_CF_data.mkt_week_index==ind_est);
qjj = q_start(1:length(costs),j);

traders_injj = traders_in_ss(:,j);
traders_injj = traders_injj(1:length(costs));

% calculate  profits 
profits = (p_start(1,j)-costs-0.5*gamma_est*qjj).*qjj;
net_profits  = profits-fc_sim(S1_CF_data.mkt_week_index==ind_est,ss);

% choose the least profitable to exit
minprofit(j,ss) = min(net_profits);
minind = find(net_profits==min(net_profits),1,'first');

if minprofit(j,ss)<0
traders_injj(minind) =  0;
traders_in_ss(:,j)  = [traders_injj;zeros(20-length(costs),1)];
end


q_mat(:,j,ss) = [qjj;zeros(20-length(costs),1)];
p_mat(1,j,ss) = p_start(1,j);
full_q_mat(:,j,ss,1) = [qjj;zeros(20-length(costs),1)];

    
end
end

q_mat_jj = squeeze(full_q_mat(:,:,ss,jj-1));
    
parfor j=1:num_mkt_wk
    

if minprofit(j,ss)<0

fprintf('simulation %.0f, iteration %0.f, market %0.f \n',ss,jj,j)


ind_est = j;


x0 = q_start(:,j);

costs = S1_CF_data.cost_intercept(S1_CF_data.mkt_week_index==ind_est);

x0 = x0(1:length(costs));



try
% determine which traders are in the market

% keep costs of remaining traders

traders_injj = traders_in_ss(:,j);
traders_injj = traders_injj(1:length(costs));

costs_remaining = costs(traders_injj==1); 
x0_remaining = x0(traders_injj==1);

if jj>1
    x0_remaining = q_mat_jj(1:length(costs),j);
    x0_remaining = x0_remaining(traders_injj==1);
end
if jj==1 && ss>1
    x0_remaining = q_mat_jj(1:length(costs),j);
    x0_remaining = x0_remaining(traders_injj==1);
end
    
f = @(x) E05_FOCs(x,costs_remaining,gamma_est,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),0,ext_price(ind_est));

q = max(0,1000*fminsearch(f,x0_remaining/1000,options));

% iterate several times in solving for equilibrium to avoid local
% equilibria

if max(abs(q-x0_remaining))>10   
x0_remaining = q;
q = max(0,1000*fminsearch(f,x0_remaining/1000,options));
end
if max(abs(q-x0_remaining))>10   
x0_remaining = q;
q = max(0,1000*fminsearch(f,x0_remaining/1000,options));
end
if max(abs(q-x0_remaining))>10   
x0_remaining = q;
q = max(0,1000*fminsearch(f,x0_remaining/1000,options));
end
if max(abs(q-x0_remaining))>10   
x0_remaining = q;
q = max(0,1000*fminsearch(f,x0_remaining/1000,options));
end
if max(abs(q-x0_remaining))>10   
x0_remaining = q;
q = max(0,1000*fminsearch(f,x0_remaining/1000,options));
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

% put quantities back into full vector
qjj  = zeros(size(costs));
qjj(traders_injj==1) = q;

% calculate  profits 
profits = (mean(priceS)-costs-0.5*gamma_est*qjj).*qjj;
net_profits  = profits-fc_sim(S1_CF_data.mkt_week_index==ind_est,ss);

% choose the least profitable to exit
minprofit(j,ss) = min(net_profits(traders_injj==1));
minind = find(net_profits==min(net_profits(traders_injj==1)),1,'first');

if sum(traders_injj)==0
   minprofit(j,ss) = 100000000; 
end

if minprofit(j,ss)<0
traders_injj(minind) =  0;
traders_in_ss(:,j)  = [traders_injj;zeros(20-length(x0),1)];
end

q_mat(:,j,ss) = [qjj;zeros(20-length(x0),1)];
p_mat(1,j,ss) = mean(priceS);
full_q_mat(:,j,ss,jj) = [qjj;zeros(20-length(x0),1)];

catch
    j

end

end



end


save('../../temp/S1_CF_grid_exit');

end

traders_in(:,:,ss) = traders_in_ss;
    
end


save('../../temp/S1_CF_grid_exit');




