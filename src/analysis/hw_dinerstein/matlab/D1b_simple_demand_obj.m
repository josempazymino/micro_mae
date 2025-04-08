function [obj,W_out,se,VV] = D1b_simple_demand_obj(param,int_data,W)
%% objective function
% parameters
delta = param(1);
a = param(2);

% data
iv = int_data.iv;
p_prior = int_data.p_prior;
p_post = int_data.p_post;
log_dq = int_data.log_dq;

% residuals
e = log_dq - 1/delta*(log((ones(size(p_post))*a-p_post)./(ones(size(p_prior))*a-p_prior)));
% moment
mom = (1/size(iv,1))*iv' * e;
% objective function
obj = size(iv,1)*mom'*W*mom;

% Update weighting matrix
res_int = iv .* (e *ones(1,size(iv,2)) );
% demeaned residual
dres_int = res_int - ones(size(res_int,1),1)*mean(res_int,1);
% Compute Omega
Omega_int = 1/size(dres_int,1)*(dres_int'*dres_int);
Omega = Omega_int;


dmmdbeta = 1/size(p_post,1) * [ 1/(delta*delta)*(log((ones(size(p_post))*a-p_post)./(ones(size(p_prior))*a-p_prior))),...
    -1/(delta)* ((1./(ones(size(p_post))*a-p_post)) - (1./(ones(size(p_prior))*a-p_prior)) ) ]'*iv;

% moment condition
if nargout>1
    W_out = Omega\eye(size(Omega));
    VV = (dmmdbeta*W_out*dmmdbeta')\eye(size(dmmdbeta,1),size(dmmdbeta,1));
    se = sqrt(diag(VV)./size(p_post,1));
end

end
