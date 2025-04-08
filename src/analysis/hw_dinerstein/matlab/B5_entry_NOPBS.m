%% bootstrap entry model

clearvars;

rng('default')
rng(2001418)

startB = 1;
endB = 1000;


%% set parameters

% importance sampling parameters
g_mu = 3;
g_sigma = 1; 

numsimFC = 25;

options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-8,'TolFun',1E-8);


%% read in data

for bbb = startB : endB
    
    %% extensive moments - bootstrap
    boot_data = readtable(strcat('../../temp/bootstrap/resample_data/S2_model_boot_',num2str(bbb),'.csv'));% gen by MS02
    %% bootstrap intensive data
    rng(2001418+bbb)

index_boot =  boot_data.mkt_week_index; 
    
potential_entrant_data = readtable('../../temp/S2_potential_entrant_types.csv');

potential_entrant_type = [potential_entrant_data.know_any_low,...
    potential_entrant_data.know_any_med,...
    potential_entrant_data.know_any_high];

data_moments_input = [potential_entrant_data.S2_low,...
    potential_entrant_data.S2_med,...
    potential_entrant_data.S2_high,...
    potential_entrant_data.cost_intercept_low,...
    potential_entrant_data.cost_intercept_med,...
    potential_entrant_data.cost_intercept_high];
data_moments_input = data_moments_input(index_boot,:);

data_moments = mean(data_moments_input,1);

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

profit_mat =  profit_mat(index_boot,:,:);

mc_grid = mc_grid(index_boot,:);

num_mkt_wk_boot = length(index_boot);

%% draw simulated FC and set parameters

FC_draws = normrnd(0,1,num_mkt_wk_boot,numsimFC);

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
[para1,fval1,exitflag1,output1] = run(ms,problem,100);

% estimate second time with new weighting matrix

invOmega = E10_gmm_opt_weight(para1,g_mu,g_sigma,mc_grid,...
    profit_mat,FC_draws,subsidy_vec,numsimFC,...
    simTrader,data_moments_input);

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

try 
[para2,fval2,exitflag2,output2] = run(ms,problem,100);

catch
    para2  = -1000*ones(size(para1));
end

save(strcat('../../temp/bootstrap/s2/entry_boot_',num2str(bbb)));

end




