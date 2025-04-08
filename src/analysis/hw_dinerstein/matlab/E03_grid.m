%% construct grid of profits uner Cournot and monopoly, for use in entry model

clearvars;

rng('default')
rng(20190611)

% read in mu, sigma, delta from demand side

load('../../temp/general_demand_estimates')
clearvars -except  delta


%% preset parameters
S = 100; % number of simulations drawn for each row(transaction) 
SS = 1e5; % number of simulation pool to draw

simTrader = 25;

options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-4,'TolFun',1E-4);


% read in supply data
S2_CF_data = readtable('../../temp/S2_CF_data.csv');

ext_price = accumarray(S2_CF_data.mkt_week_index,S2_CF_data.p_cost_adj_jt,[],@max);
total_kgs = accumarray(S2_CF_data.mkt_week_index,S2_CF_data.kgs_own_adj,[],@sum);

gamma = S2_CF_data.gamma_est(1);




num_mkt_wk = length(total_kgs);



load('../../temp/S2_sim_consumers','a_all_mkts','b_all_mkts');
load('../../temp/S2_monop','monop_price');
load('../../temp/S2_Cournot','Cournot_price');


%% draw MC from lognormal importance sampling distribution

g_mu = 3;
g_sigma = 1; 

mc_grid = exp(g_mu+g_sigma*randn(num_mkt_wk,simTrader));


para_1 = zeros(20,num_mkt_wk,simTrader);
para_0 = zeros(20,num_mkt_wk,simTrader);

profit_1 = zeros(num_mkt_wk,simTrader);
profit_0 = zeros(num_mkt_wk,simTrader);


for ss=1:simTrader
    
disp('Starting new simulation')
ss

parfor j=1:num_mkt_wk

fprintf('simulation %.0f, market %0.f \n',ss,j)

% case 1: monopoly and Cournot prices exceed cost
% entry in both cases, find profits

if monop_price(j)>mc_grid(j,ss) && Cournot_price(j)>mc_grid(j,ss)
    
ind_est = j;

S2_trader = S2_CF_data.S2_trader(S2_CF_data.mkt_week_index==ind_est);


x0 = S2_CF_data.kgs_own_adj(S2_CF_data.mkt_week_index==ind_est);
x0(S2_trader==1)=[];

costs = S2_CF_data.cost_intercept(S2_CF_data.mkt_week_index==ind_est);
costs(S2_trader==1)=[];

x0 = [x0;mean(x0)];
costs = [costs;mc_grid(j,ss)];

entrant_ind = length(x0);

f = @(x) E05_FOCs(x,costs,gamma,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),1,ext_price(ind_est));
g = @(x) E05_FOCs(x,costs,gamma,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),0,ext_price(ind_est));

try

para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];

q_1 = para_1(:,j,ss);

if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end

para_0(:,j,ss) = [max(0,1000*fminsearch(g,q_1(1:entrant_ind)/1000,options)); zeros(20-length(x0),1)];

q_0 = para_0(:,j,ss);

if max(abs(q_0(1:length(x0))-x0))>10   
x0 = q_0(1:length(x0));
para_0(:,j,ss) = [max(0,1000*fminsearch(g,x0/1000,options)); zeros(20-length(x0),1)];
q_0 = para_0(:,j,ss);
end
if max(abs(q_0(1:length(x0))-x0))>10   
x0 = q_0(1:length(x0));
para_0(:,j,ss) = [max(0,1000*fminsearch(g,x0/1000,options)); zeros(20-length(x0),1)];
q_0 = para_0(:,j,ss);
end
if max(abs(q_0(1:length(x0))-x0))>10   
x0 = q_0(1:length(x0));
para_0(:,j,ss) = [max(0,1000*fminsearch(g,x0/1000,options)); zeros(20-length(x0),1)];
q_0 = para_0(:,j,ss);
end
if max(abs(q_0(1:length(x0))-x0))>10   
x0 = q_0(1:length(x0));
para_0(:,j,ss) = [max(0,1000*fminsearch(g,x0/1000,options)); zeros(20-length(x0),1)];
q_0 = para_0(:,j,ss);
end
if max(abs(q_0(1:length(x0))-x0))>10   
x0 = q_0(1:length(x0));
para_0(:,j,ss) = [max(0,1000*fminsearch(g,x0/1000,options)); zeros(20-length(x0),1)];
q_0 = para_0(:,j,ss);
end



q_1 = q_1(entrant_ind);

q_0 = para_0(:,j,ss);
q_0 = q_0(entrant_ind);

totalQ_1 = sum(para_1(:,j,ss));
totalQ_0 = sum(para_0(:,j,ss));

% find the price that corresponds to this totalQ

priceS_1 = zeros(1,S);
priceS_0 = zeros(1,S);

a_j = squeeze(a_all_mkts(:,:,ind_est));
b_j = squeeze(b_all_mkts(:,:,ind_est));


for s=1:S
h = @(x) E06_invert_demand(x,totalQ_1,delta,a_j(:,s),b_j(:,s));
priceS_1(s) = fminsearch(h,ext_price(j));

h = @(x) E06_invert_demand(x,totalQ_0,delta,a_j(:,s),b_j(:,s));
priceS_0(s) = fminsearch(h,priceS_1(s));
end

profit_1(j,ss) = mean(priceS_1).*q_1-mc_grid(j,ss)*q_1-0.5*gamma*q_1^2;
profit_0(j,ss) = mean(priceS_0).*q_0-mc_grid(j,ss)*q_0-0.5*gamma*q_0^2;

catch
    j
end

% case 2: monopoly price is less than cost -> no entry
% no entry, no profits

elseif monop_price(j)<mc_grid(j,ss)
    
    profit_1(j,ss) = 0;
    profit_0(j,ss) = 0;
    
% case 3: monopoly price is greater than cost but Cournot is not -> entry
% if connections
% solve for monopoly profits

elseif monop_price(j)>mc_grid(j,ss)
   profit_0(j,ss) = 0;
   
    ind_est = j;

    S2_trader = S2_CF_data.S2_trader(S2_CF_data.mkt_week_index==ind_est);


    x0 = S2_CF_data.kgs_own_adj(S2_CF_data.mkt_week_index==ind_est);
    x0(S2_trader==1)=[];

    costs = S2_CF_data.cost_intercept(S2_CF_data.mkt_week_index==ind_est);
    costs(S2_trader==1)=[];

    x0 = [x0;mean(x0)];
    costs = [costs;mc_grid(j,ss)];

    entrant_ind = length(x0);

    f = @(x) E05_FOCs(x,costs,gamma,delta,squeeze(a_all_mkts(:,:,ind_est)),squeeze(b_all_mkts(:,:,ind_est)),1,ext_price(ind_est));

try

para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];

q_1 = para_1(:,j,ss);
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end
if max(abs(q_1(1:length(x0))-x0))>10   
x0 = q_1(1:length(x0));
para_1(:,j,ss) = [max(0,1000*fminsearch(f,x0/1000,options)); zeros(20-length(x0),1)];
q_1 = para_1(:,j,ss);
end




q_1 = q_1(entrant_ind);

totalQ_1 = sum(para_1(:,j,ss));

% find the price that corresponds to this totalQ

priceS_1 = zeros(1,S);

a_j = squeeze(a_all_mkts(:,:,ind_est));
b_j = squeeze(b_all_mkts(:,:,ind_est));


for s=1:S

h = @(x) E06_invert_demand(x,totalQ_1,delta,a_j(:,s),b_j(:,s));
priceS_1(s) = fminsearch(h,priceS_1(s));
end

profit_1(j,ss) = mean(priceS_1).*q_1-mc_grid(j,ss)*q_1-0.5*gamma*q_1^2;

catch
    j
end
    
end

end

save('../../temp/S2_CF_grid');

end

save('../../temp/S2_CF_grid','mc_grid','num_mkt_wk','simTrader','profit_0','profit_1');





