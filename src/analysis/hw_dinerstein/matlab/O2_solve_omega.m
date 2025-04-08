function obj = O2_solve_omega(omega,rho,delta,probvec)

valvec =  zeros(10,1);
for n=1:10
    valvec(n) = (1+(delta/n)*(1+omega*(n-1)))^(-1);
end

obj =  (rho - valvec'*probvec)^2;
