%% find competitive equilibrium

clearvars;

rng('default')
rng(20190812)


% read in mu, sigma, delta from demand side

load('../../temp/general_demand_estimates')
clearvars -except  delta

% read in supply data
S1_CF_data = readtable('../../temp/S1_CF_data.csv');


% estimate market demand curves by market-week

load('../../temp/S1_sim_consumers','a_all_mkts','b_all_mkts');

num_mkt_week = size(a_all_mkts,3);
price_vec = (0:0.1:40);

demand_curve = zeros(num_mkt_week,length(price_vec));


for mm=1:num_mkt_week
    a_mmpp = a_all_mkts(:,:,mm);
    b_mmpp = b_all_mkts(:,:,mm);
    for pp=1:length(price_vec)
        q_save = zeros(size(a_all_mkts,2),1);
        for ss=1:size(a_all_mkts,2)
            a_positive = a_mmpp(a_mmpp(:,ss)>price_vec(pp),ss);
            b_positive = b_mmpp(a_mmpp(:,ss)>price_vec(pp),ss);
            baseline_q = ((a_positive-price_vec(pp))./b_positive).^(1/delta);
            baseline_Q = mean(sum(baseline_q,1),2);
            q_save(ss) = baseline_Q;
            
        end
        demand_curve(mm,pp) = mean(q_save);
    end
end


% estimate supply curves by market-week

gamma_est = S1_CF_data.gamma_est(1);

cost_curve = zeros(num_mkt_week,length(price_vec));
q_j_mat = zeros(20,num_mkt_week,length(price_vec));

for mm=1:num_mkt_week
   costs = S1_CF_data.cost_intercept(S1_CF_data.mkt_week_index==mm); 
   for pp=1:length(price_vec)
       clearvars q_j
        q_j = (price_vec(pp)*ones(length(costs),1)-costs)/gamma_est; 
        cost_curve(mm,pp) = sum(q_j.*(q_j>0));
        q_j_mat(1:length(q_j),mm,pp) = q_j.*(q_j>0);
   end
end


% find where demand and costs intersect

surplus_demand = demand_curve-cost_curve; 
eqm_point = zeros(num_mkt_week,1);
eqm_price = zeros(num_mkt_week,1);
eqm_qj    = zeros(num_mkt_week,20);

for mm=1:num_mkt_week
   eqm_point(mm) = find(surplus_demand(mm,:)<=0,1,'first');
   eqm_price(mm) = price_vec(eqm_point(mm));
   q_j_mat_temp =  squeeze(q_j_mat(:,mm,eqm_point(mm)));
   eqm_qj(mm,:) = q_j_mat_temp';
end

% estimate total variable surplus if pricing at cost

% estimate CS


mean_cs =  zeros(num_mkt_week,1);
for j=1:num_mkt_week
    a_j =  squeeze(a_all_mkts(:,:,j));
    b_j =  squeeze(b_all_mkts(:,:,j));
    p_j = eqm_price(j);
    q_j = ((a_j-p_j)./b_j).^(1/delta);
    q_j(a_j<=p_j) =  0;
    cs_j = delta/(1+delta) *  q_j .* (a_j-p_j);
    mean_cs(j) = mean(sum(cs_j,1),2);
end

% estimate variable profits
num_trader_mkt_week  = size(S1_CF_data.cost_intercept,1);
q_trader = zeros(num_trader_mkt_week,1);
p_trader = zeros(num_trader_mkt_week,1);
startind = 1;
for j=1:num_mkt_week
    len_j = sum(S1_CF_data.mkt_week_index==j);
    q_trader(startind:startind+len_j-1) = eqm_qj(j,1:len_j);
    p_trader(startind:startind+len_j-1) = eqm_price(j);
    startind = startind+len_j;
end  

variable_profits = (p_trader.*q_trader)-S1_CF_data.cost_intercept.*q_trader  - ...
    0.5*gamma_est*q_trader.^2;


csvwrite('../../temp/competitive_surplus.csv',[sum(mean_cs),sum(variable_profits)]);


