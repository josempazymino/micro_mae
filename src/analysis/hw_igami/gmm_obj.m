% Moments: The objective function to be minimized in GMM estimation
function f = gmm_obj(x)

% Data
global P P_ann c_roche Q q_roche q_takeda q_emerck q_basf q_fri iv iv_ann Num_months W

% Parameters
alpha0 = x(1);
alpha1 = x(2);
alpha2 = x(3);
gamma_roche = x(4);
gamma_takeda = x(5);
gamma_emerck = x(6);
gamma_basf = x(7);

% Relabeling
X = iv;             % Just relabeling demand shifter (monthly version)
X_ann = iv_ann;     % Just relabeling demand shifter (annual version)
dPdQ = 1 / alpha1;  % Just relabeling demand slope

% Moments 1: Demand shifter is orthogonal to cost shocks (at monthly frequency, in aggregate across firms).
% Residual demand (at monthly frequency)
resid_Q = alpha0 * ones(Num_months, 1) + alpha1 * P + alpha2 * X - q_fri;
eta_avg = (P - c_roche) - (gamma_roche + gamma_takeda + gamma_emerck + gamma_basf)/4 + dPdQ * resid_Q / 4;
mom101 = eta_avg' * iv;

% Moments 2: Demand shifter & cost (shifter) are orthogonal to demand shocks (at annual frequency).
epsilon = Q - alpha0 * ones(Num_months, 1) - alpha1 * P_ann - alpha2 * X_ann;
mom201 = epsilon' * ones(Num_months, 1);
mom202 = epsilon' * iv_ann;
mom203 = epsilon' * c_roche;

% Moments 3: Demand shifter is orthogonal to cost shocks (at annual frequency).
eta_roche = (P_ann - c_roche - gamma_roche) + dPdQ * q_roche;
eta_takeda = (P_ann - c_roche - gamma_takeda) + dPdQ * q_takeda;
eta_emerck = (P_ann - c_roche - gamma_emerck) + dPdQ * q_emerck;
eta_basf = (P_ann - c_roche - gamma_basf) + dPdQ * q_basf;
mom301 = eta_roche' * ones(Num_months, 1);
mom302 = eta_takeda' * ones(Num_months, 1);
mom303 = eta_emerck' * ones(Num_months, 1);
mom304 = eta_basf' * ones(Num_months, 1);
mom311 = eta_roche' * iv_ann;
mom312 = eta_takeda' * iv_ann;
mom313 = eta_emerck' * iv_ann;
mom314 = eta_basf' * iv_ann;

% Loading all(?) moments
%Mom = [mom201; mom202; mom301; mom302; mom303; mom304]; % Choice 01: OLS-like
%Mom = [mom201; mom202; mom203; mom301; mom302; mom303; mom304]; % Choice 02: Cost IV
%Mom = [mom201; mom202; mom301; mom302; mom303; mom304; mom311; mom312; mom313; mom314]; % Choice 03: Demand IV
%Mom = [mom201; mom202; mom203; mom301; mom302; mom303; mom304; mom311; mom312; mom313; mom314]; % Choice 04: Both IV
Mom = [mom101; mom201; mom202; mom203; mom301; mom302; mom303; mom304; mom311; mom312; mom313; mom314]; % Choice 05: All    
if isempty(W) == 1
    M = size(Mom, 1);   % Number of moment conditions
    W = eye(M);         % Weight is identity matrix in the 1st stage.
end
f = Mom' * W * Mom;
