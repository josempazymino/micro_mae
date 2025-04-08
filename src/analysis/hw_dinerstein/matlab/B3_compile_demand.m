%% combine bootstrapped demand parameters

BB = 1000;
estimated_int_para.delta_all = nan(BB,1);
estimated_int_para.mu_all = nan(BB,1);
estimated_int_para.sigma_all = nan(BB,1);

for i = 1:BB
    estimated_int_para_part = load(strcat('../../temp/bootstrap/demand_est/demand_est_data_',num2str(i)));
    estimated_int_para.delta_all(i) = estimated_int_para_part.delta_all(i);
    estimated_int_para.mu_all(i) = estimated_int_para_part.mu_all(i);
    estimated_int_para.sigma_all(i) = estimated_int_para_part.sigma_all(i);
end

save(strcat('../../temp/bootstrap/demand_est/general_demand_bootstrap_estimates'),'estimated_int_para')

    tt = table(estimated_int_para.delta_all,estimated_int_para.mu_all,estimated_int_para.sigma_all, ...
        'VariableNames',{'delta','mu','sigma'});
    writetable(tt,strcat('../../temp/bootstrap/demand_est/general_demand_bootstrap_estimates.csv'),'Delimiter',',','QuoteStrings',true)

for bbb=1:1000
delete(strcat('../../temp/bootstrap/demand_est/demand_est_data_',num2str(bbb),'.mat'));
end