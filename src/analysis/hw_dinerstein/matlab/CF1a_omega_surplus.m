load('../../temp/S1_CF_grid')

% calculate consumer surplus
mean_cs =  zeros(num_mkt_wk,omega_grid_points);
for oo=1:omega_grid_points
for j=1:num_mkt_wk
    a_j =  squeeze(a_all_mkts(:,:,j));
    b_j =  squeeze(b_all_mkts(:,:,j));
    p_j = p_mat(1,j,oo);
    q_j = ((a_j-p_j)./b_j).^(1/delta);
    q_j(a_j<p_j) =  0;
    cs_j = delta/(1+delta) *  q_j .* (a_j-p_j);
    mean_cs(j,oo) = mean(sum(cs_j,1),2);
    if p_j<=0
       mean_cs(j,oo)=0; 
    end
end
end


% estimate variable profits
num_trader_mkt_week  = size(S1_CF_data.cost_intercept,1);
q_trader = zeros(num_trader_mkt_week,omega_grid_points);
p_trader = zeros(num_trader_mkt_week,omega_grid_points);

for oo=1:omega_grid_points
    startind = 1;
for j=1:num_mkt_wk
    len_j = sum(S1_CF_data.mkt_week_index==j);
    q_trader(startind:startind+len_j-1,oo) = q_mat(1:len_j,j,oo);
    p_trader(startind:startind+len_j-1,oo) = p_mat(1,j,oo);
    if p_j<=0
       q_trader(startind:startind+len_j-1,oo)=0; 
    end
    startind = startind+len_j;
end  
end


variable_profits = (p_trader.*q_trader)-(S1_CF_data.cost_intercept*ones(1,omega_grid_points)).*q_trader  - ...
    0.5*gamma_est*q_trader.^2;

csvwrite('../../temp/omega_surplus.csv',[sum(mean_cs,1);sum(variable_profits,1)]);
