function [obj] = E05_FOCs(q,costs,gamma,delta,a,b,omega,price0)

% calculate price and demand derivative at this q

q = q*1000;

q(q<0)=0;

S = size(a,2);

totalQ = sum(q);

% find the price that corresponds to this totalQ

priceS = zeros(1,S);

    options = optimset('MaxFunEvals',1E5,'MaxIter',1E5,'TolX',1E-6,'TolFun',1E-6);

for s=1:S
f = @(x) E06_invert_demand(x,totalQ,delta,a(:,s),b(:,s));
priceS(s) = fminsearch(f,price0,options);
end

priceS = ones(length(a),1)*priceS;

foc_err = zeros(size(costs,1),S);

for s=1:S
    
temp = (a(:,s)-priceS(:,s));
a_positive = a(temp>0,s);
b_positive = b(temp>0,s);
qS = ((a_positive-priceS(1,s))./b_positive).^(1/delta);
totalderiv = sum((-1/delta) * qS ./ (a_positive-priceS(1,s)));
invdQdp_int_sim =  1 / totalderiv;


foc_err(:,s) = priceS(1,s)*ones(length(costs),1) - costs - gamma*q + invdQdp_int_sim*q + omega*invdQdp_int_sim*(totalQ*ones(length(costs),1)-q);

end

mean_foc = zeros(size(foc_err,1),1);
for jj=1:size(foc_err,1)
    foc_temp = foc_err(jj,:);
    foc_temp(isinf(foc_temp))=[];
    foc_temp(isnan(foc_temp))=[];
    mean_foc(jj) = mean(foc_temp);

end
obj = sum(mean_foc.^2,1);

end
