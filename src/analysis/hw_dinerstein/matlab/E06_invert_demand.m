function [obj] = E06_invert_demand(price,totalQ,delta,a,b)

if price<0
    obj = 1e100;
else

a_positive = a(a>price);
b_positive = b(a>price);

q = 0;

if ~isempty(a_positive) 

q = ((a_positive-price)./b_positive).^(1/delta);

end

obj = (totalQ-sum(q))^2;

end