function [obj] = E10_gmm_opt_weight(param,g_mu,g_sigma,...
    mc_grid,profit_mat,FC_draws,subsidy_vec,numsimFC,...
    simTrader,data_moments_input)

mu1 = param(1);
mu2 = param(2);
sigma1 = param(3);
sigma2 = param(4);
rho = param(5);



% reshape MC and FC so that they conform
% MC is num_mkt_wk x simTrader
% FC is numsimFC x 1

mc_grid_conform = repmat(mc_grid,1,numsimFC);

profit_mat_conform1 = repmat(squeeze(profit_mat(:,:,1)),1,numsimFC);
profit_mat_conform2 = repmat(squeeze(profit_mat(:,:,2)),1,numsimFC);
profit_mat_conform3 = repmat(squeeze(profit_mat(:,:,3)),1,numsimFC);

FC_draws_conform = kron(FC_draws,ones(1,simTrader));

% draw FC based on MC draws, mu2, sigma2, rho
% bivariate normal:
% Y | X=x ~ N(mu_y + rho sigma_y/sigma_x (X-mu_x), sigma_y^2(1-rho^2))

log_mc_grid = log(mc_grid_conform);

mean_mat = mu2 + rho * sigma2 / g_sigma * (log_mc_grid-g_mu);
sd_mat = sigma2^2 * (1-rho^2);

log_fc_grid = mean_mat + sd_mat .* FC_draws_conform;
fc_grid_conform = exp(log_fc_grid);

% predict entry and MC conditional on entry

entry_sub1 = (profit_mat_conform1-fc_grid_conform+subsidy_vec(1)>0);
entry_sub2 = (profit_mat_conform2-fc_grid_conform+subsidy_vec(2)>0);
entry_sub3 = (profit_mat_conform3-fc_grid_conform+subsidy_vec(3)>0);

conditional_mc_sub1 = mc_grid_conform.*entry_sub1;
conditional_mc_sub2 = mc_grid_conform.*entry_sub2;
conditional_mc_sub3 = mc_grid_conform.*entry_sub3;

% construct model moments using importance sampling
% calculate weight for each point in grid
% logN distribution: 
g_grid = 1./(g_sigma*sqrt(2*pi)*mc_grid_conform) .* exp(-(log(mc_grid_conform)-g_mu).^2/(2*g_sigma^2));
f_grid = 1./(sigma1*sqrt(2*pi)*mc_grid_conform) .* exp(-(log(mc_grid_conform)-mu1).^2/(2*sigma1^2));
importance_grid = f_grid./g_grid;

entry_modmom1_ind = mean(entry_sub1.*importance_grid,2);
entry_modmom2_ind = mean(entry_sub2.*importance_grid,2);
entry_modmom3_ind = mean(entry_sub3.*importance_grid,2);

mc_modmom1_ind = mean(conditional_mc_sub1.*importance_grid,2);
mc_modmom2_ind = mean(conditional_mc_sub2.*importance_grid,2);
mc_modmom3_ind = mean(conditional_mc_sub3.*importance_grid,2);

% construct gmm obj function
gvec = [data_moments_input(1)-entry_modmom1_ind,...
    data_moments_input(2)-entry_modmom2_ind,...
    data_moments_input(3)-entry_modmom3_ind,...
    data_moments_input(4)-mc_modmom1_ind,...
    data_moments_input(5)-mc_modmom2_ind,...
    data_moments_input(6)-mc_modmom3_ind];

inner_product = gvec'*gvec/size(gvec,1);

obj = inv(inner_product);

end