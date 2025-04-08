%% estimate simple demand model

clear all;


rng(08022019)

%% data
intensivetdata = readtable('../../temp/demand_exp_analysis_data.csv');
selection = logical(intensivetdata.p0 >-10000);
p_prior = intensivetdata.p0(selection);
p_post = intensivetdata.p1(selection);
q_prior = intensivetdata.q0(selection);
q_post = intensivetdata.q1(selection);
log_dq = log(q_post) - log(q_prior);
subsidy = intensivetdata.subsidy(selection);

sub_id = dummyvar(grp2idx(intensivetdata.subsidy(selection)));

%% Variable 
iv = sub_id(:,1:end); % iv for endogeneous regressors
% input variables
int_data.iv = iv;
int_data.p_prior = p_prior;
int_data.p_post = p_post;
int_data.log_dq =log_dq;
%% estimation 
[para,se,VV] = D1a_simple_demand_estimation(2,1e9,int_data);

%% eta and b
delta = para(1);
a = para(2);

delta_se = se(1);
a_se = se(2);


    tt = table(delta,a,delta_se,a_se, ...
        'VariableNames',{'delta','a','delta_se','a_se'});
    writetable(tt,strcat('../../temp/simple_demand_estimates.csv'),'Delimiter',',','QuoteStrings',true)


% create bootstrap versions
boot = mvnrnd(para,VV./size(p_post,1),1000);

csvwrite('../../temp/simple_demand_bootstrap.csv',boot);



    