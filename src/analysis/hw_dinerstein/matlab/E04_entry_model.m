%% Wrapper file for estimation of MC and FC distributions

clearvars;

rng('default')
rng(2001418)

%% set parameters

% importance sampling parameters
g_mu = 3;
g_sigma = 1; 

numsimFC = 25;

options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-8,'TolFun',1E-8);


%% read in data

% read in potential entry types by market
% tells us whether to use Cournot or monopoly profits

% "potential_entrant_type": num_mkt_wk x 3

potential_entrant_data = readtable('../../temp/S2_potential_entrant_types.csv');

potential_entrant_type = [potential_entrant_data.know_any_low,...
    potential_entrant_data.know_any_med,...
    potential_entrant_data.know_any_high];

% read in moments
% moments: entry prob by offer; MC conditional on entry, by offer

moments_data = readtable('../../temp/S2_mc_fc_moments.csv');

data_moments = [moments_data.entry_prob_low, moments_data.entry_prob_med,...
    moments_data.entry_prob_high, moments_data.cost_intercept_low,...
    moments_data.cost_intercept_med, moments_data.cost_intercept_high];


% MC draws for each market-week-simulated draw
load('../../temp/S2_CF_grid','mc_grid','num_mkt_wk','simTrader','profit_0','profit_1');

% construct profits for each market-week-MC draw-potential entrant

potential_entrant_type_conform = zeros(num_mkt_wk,simTrader,3);
potential_entrant_type_conform(:,:,1) = potential_entrant_type(:,1)*ones(1,simTrader);
potential_entrant_type_conform(:,:,2) = potential_entrant_type(:,2)*ones(1,simTrader);
potential_entrant_type_conform(:,:,3) = potential_entrant_type(:,3)*ones(1,simTrader);

profit_mat = zeros(num_mkt_wk,simTrader,3);
profit_mat(:,:,1) = profit_1.*potential_entrant_type_conform(:,:,1) + ...
    profit_0.*(1-potential_entrant_type_conform(:,:,1));
profit_mat(:,:,2) = profit_1.*potential_entrant_type_conform(:,:,2) + ...
    profit_0.*(1-potential_entrant_type_conform(:,:,2));
profit_mat(:,:,3) = profit_1.*potential_entrant_type_conform(:,:,3) + ...
    profit_0.*(1-potential_entrant_type_conform(:,:,3));


%% draw simulated FC and set parameters

FC_draws = normrnd(0,1,num_mkt_wk,numsimFC);

subsidy_vec = [5000;10000;15000];  % entry subsidies

%% estimate MC and FC parameters

x0 = [g_mu;6;g_sigma;2;0];
weight_mat = eye(length(data_moments));

f = @(x) E07_gmm_MCFC(x,data_moments,g_mu,g_sigma,mc_grid,...
    profit_mat,weight_mat,FC_draws,subsidy_vec,numsimFC,...
    simTrader);

options_joint = optimoptions('fmincon','Display','off','SpecifyObjectiveGradient',false,...
    'MaxFunEvals',1E4,'MaxIter',1E4,'TolX',1E-6,'TolFun',1E-6,'StepTolerance',1E-6);
lb = [-5,-5,0.25,0.25,-1];
ub = [5,25,5,5,1];
problem = createOptimProblem('fmincon','objective',...
    f,'x0',x0,'lb',lb,'ub',ub,'options',options_joint);

ms = MultiStart('FunctionTolerance',1e-6,'XTolerance',1e-6,...
    'StartPointsToRun', 'bounds-ineqs','UseParallel',true,...
    'Display', 'iter');
[para1,fval1,exitflag1,output1] = run(ms,problem,1000);

invOmega = E08_gmm_opt_weight_nonboot(para1,g_mu,g_sigma,mc_grid,...
    profit_mat,FC_draws,subsidy_vec,numsimFC,...
    simTrader,potential_entrant_data);

f = @(x) E07_gmm_MCFC(x,data_moments,g_mu,g_sigma,mc_grid,...
    profit_mat,invOmega,FC_draws,subsidy_vec,numsimFC,...
    simTrader);

options_joint = optimoptions('fmincon','Display','off','SpecifyObjectiveGradient',false,...
    'MaxFunEvals',1E4,'MaxIter',1E4,'TolX',1E-6,'TolFun',1E-6,'StepTolerance',1E-6);
lb = [-5,-5,0.25,0.25,-1];
ub = [5,25,5,5,1];
problem = createOptimProblem('fmincon','objective',...
    f,'x0',para1,'lb',lb,'ub',ub,'options',options_joint);

ms = MultiStart('FunctionTolerance',1e-6,'XTolerance',1e-6,...
    'StartPointsToRun', 'bounds-ineqs','UseParallel',true,...
    'Display', 'iter');
[para2,fval2,exitflag2,output2] = run(ms,problem,1000);


[fc_conditional_nosub,mc_conditional_nosub] = E09_MCFC_stats(para2,g_mu,g_sigma,...
    mc_grid,profit_mat,FC_draws,[0,0,0],numsimFC,simTrader);

save('../../temp/mc_fc_estimates','para2','mc_conditional_nosub','fc_conditional_nosub');

mu_MC = para2(1);
mu_FC = para2(2);
sigma_MC = para2(3);
sigma_FC = para2(4);
rho = para2(5);
takel = moments_data.entry_prob_low(1);
takem = moments_data.entry_prob_med(1);
takeh = moments_data.entry_prob_high(1);
mcl = moments_data.cost_intercept_low(1);
mcm = moments_data.cost_intercept_med(1);
mch = moments_data.cost_intercept_high(1);

   tt = table(mu_MC,mu_FC,sigma_MC,sigma_FC,rho,takel,takem,takeh,mcl,mcm,mch, ...
        'VariableNames',{'mu_MC','mu_FC','sigma_MC','sigma_FC','rho','takel','takem','takeh','mcl','mcm','mch'});
    writetable(tt,strcat('../../temp/entry_estimates.csv'),'Delimiter',',','QuoteStrings',true)


