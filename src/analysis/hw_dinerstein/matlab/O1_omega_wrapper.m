%% Estimate omega in simple model

clearvars;

%% data

% read in simple demand estimates
demand = readtable('../../temp/simple_demand_estimates.csv');
delta_bar = demand.delta; 

% read in pass-through rate
rhodata = readtable('../../temp/rho_est.csv');
rho_bar = rhodata.rho(1);

% read in bootstrapped demand and number of traders
bootdata = readtable('../../temp/boot_est.csv');
bootreps = 1000;

% read in baseline number of traders
tradercount = readtable('../../temp/num_traders.csv');
pctN = accumarray(tradercount.num_traders_hetero,ones(size(tradercount.num_traders_hetero)),[],@sum)/length(tradercount.num_traders_hetero);

% starting value
omega0 = 0.5;


% estimate omega
f = @(x) O2_solve_omega(x,rho_bar,delta_bar,pctN);

omegahat = fminsearch(f,omega0);

omega_boot = zeros(bootreps,1);


for bb=1:bootreps
    
probvec = [bootdata.pctN1(bb);...
    bootdata.pctN2(bb);...
    bootdata.pctN3(bb);...
    bootdata.pctN4(bb);...
    bootdata.pctN5(bb);...
    bootdata.pctN6(bb);...
    bootdata.pctN7(bb);...
    bootdata.pctN8(bb);...
    bootdata.pctN9(bb);...
    bootdata.pctN10(bb)];
omega0 = 0.5;

rho = bootdata.rho(bb);
delta = bootdata.delta(bb);

f = @(x) O2_solve_omega(x,rho,delta,probvec);

omega_boot(bb) = fminsearch(f,omega0);

end

csvwrite('../../temp/omega_baseline.csv',[omegahat]);
csvwrite('../../temp/omega_boot.csv',[omega_boot]);
