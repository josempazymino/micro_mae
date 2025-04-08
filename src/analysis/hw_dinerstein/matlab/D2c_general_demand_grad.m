function [W_out] = D2c_general_demand_grad(para,int_data)

% parameters
delta = para(1);
mu = para(2);
sigma = para(3);

cdfVarCov = int_data.cdfVarCov;
%% data
% DW data
iv = int_data.iv;
p_prior = int_data.p_prior;
p_post = int_data.p_post;
log_dq = int_data.log_dq;
market_id= int_data.market_id;
S = int_data.S; 

    % simulate a_j
    NDdraws_r_j = S1_simulate_aj(mu, sigma, int_data);
    aj_for_i = NDdraws_r_j(market_id,:);

    % residuals
    e = mean(...
        log_dq*ones(1,S)...
        -1/delta*((log((aj_for_i-p_post*ones(1,S))./(aj_for_i-p_prior*ones(1,S)))))...
        , 2);

    

    %% Update weighting matrix
    res_int = iv .* (e *ones(1,size(iv,2)) );
    %res_int = [res_int,res_low,res_high];
    % demeaned residual
    dres_int = res_int - ones(size(res_int,1),1)*mean(res_int,1);
    % Compute Omega
    Omega_int = 1/size(dres_int,1)*(dres_int'*dres_int);
    Omega = [Omega_int,zeros(size(Omega_int,1),6);zeros(6,size(Omega_int,2)),cdfVarCov];
    
    W_out = Omega\eye(size(Omega));

end

