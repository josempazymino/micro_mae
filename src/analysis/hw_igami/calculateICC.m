clear all
close all
close hidden
warning off all
clc

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%
mode_pc = 1;%%%
%%%%%%%%%%%%%%%

os_ind  = computer;

if mode_pc==1
    pwd_main = pwd;
    code_path    = [pwd,'/'];
    results_path = [pwd_main(1:end-22),'/','bld/', 'out/', 'analysis/igami/'];
    %logs_path    = [pwd_main(1:end-22),'/', 'bld/', 'out/' ,'analysis/', 'log/'];
    indata_path    = [pwd_main(1:end-22),'/','src/', 'original_data/', 'data_hw_igami/'];
else
    mkdir(project_paths('OUT_ANALYSIS','log'));
    results_path = project_paths('OUT_ANALYSIS_IGAMI');
    %logs_path    = project_paths('OUT_ANALYSIS');
    indata_path    = project_paths('IN_DATA_IGAMI');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Calculate model-based outputs, prices, profits, & ICCs.

load([indata_path,'/','data']);          % Basic data = (P, c_Roche, q_i's, q_fri, Q, I_cartel, year)
load([results_path,'/','result_theta']); % Parameter estimates (GMM)
T = 228;
T_cartelstart = 133;                % Vitamin C cartel's first month = Jan 1991
T_cartelend = 188;                  % Vitamin C cartel's final month = Aug 1995
T_qb = T_cartelstart - 24;          % Vitamin C cartel's "quota-basis" year starts = Jan 1989
N = 4;                              % Number of (cartel) firms

% Prepare storage 
Q_data = [q_roche, q_takeda, q_emerck, q_basf, q_fri];
P_data = P;

Q_nash_sum = zeros(T, T);           % (tau, t)
P_nash = zeros(T, T);               % (tau, t)
Q_nash = zeros(T, N, T);            % (tau, i, t)
Pi_nash = zeros(T, N, T);           % (tau, i, t)

Q_mono = zeros(T, T);
Q_mono_sum = zeros(T, T);
P_mono = zeros(T, T);

Q_cheat = zeros(T, N, T);      
Q_cheat_total = zeros(T, N, T);
P_cheat = zeros(T, N, T);      
Pi_cheat = zeros(T, N, T);     

% Pick parameters (from the main estimates)
alpha0 = Theta(1);
alpha1 = Theta(2);
alpha2 = Theta(3);
dPdQ = 1 / alpha1;
gamma_roche = Theta(4);
gamma_takeda = Theta(5);
gamma_emerck = Theta(6);
gamma_basf = Theta(7);

% Demand
Alpha = ones(T,1) * alpha1;                         % Demand slope [T x 1]
X = Q - Alpha .* P;                                 % Demand intercept (effective) [T x 1]

% Costs
c_takeda = c_roche + gamma_takeda * ones(T,1);
c_emerck = c_roche + gamma_emerck * ones(T,1);
c_basf = c_roche + gamma_basf * ones(T,1);
c_roche = c_roche + gamma_roche * ones(T,1);
MC = [c_roche, c_takeda, c_emerck, c_basf];         % Cartel firms' MCs [T x N]

% Fringe supply in future period 'tau'
% ...in cartel firms' expectations as of current period 't'
Q_fri = zeros(T, T);                                % (tau, t)
for t = 1:(T-1)
    Q_fri(1:t, t) = q_fri(1:t);                     % past = actual
    Q_fri((t+1):T, t) = q_fri(t) * ones((T-t),1);   % future = current
end
Q_fri(:, T) = q_fri;                                % no future at t = T

%% Calculate outcomes under Nash & monopoly

for t = 1:T        
    for tau = t:T
        
        % Pick up variables at (tau | t)
        x = X(tau);                             % Demand intercept [scalar]
        dpdq = dPdQ;                            % Demand slope [scalar]
        mc = MC(tau, :);                        % Marginal costs of N firms [1 x N]
        eqfri = Q_fri(tau, t);                  % Expected fringe supply [scalar]
        p0 = -dpdq * (x - eqfri);               % Y-intercept of the inverse demand, given fringe (choke price)
        
        % Nash equilibrium outcomes
        q_cartel = (N/(N+1)) * (p0/abs(dpdq)) - sum(mc) / (abs(dpdq) * (N+1));  % Cartel's total Q
        q_sum = q_cartel + eqfri;               % World output
        p = dpdq * (q_sum - x);                 % Price in Nash equilibrium
        Q_nash_sum(tau, t) = q_sum;             % Book-keeping
        P_nash(tau, t) = p;                     % Book-keeping
        
        for i = 1:N   
            
            q = (p0 - mc(i)) / abs(dpdq) - q_cartel;    % Firm i's Nash output
            pi = (p - mc(i)) * q;                       % Firm i's Nash profit
            Q_nash(tau, i, t) = q;                      % Book-keeping
            Pi_nash(tau, i, t) = pi;                    % Book-keeping
            
        end
        
        % Monopoly P & Q, based on Roche's cost
        alpha = Alpha(tau);                             % Price-coefficient of demand
        c = mc(1);                                      % Roche's MC
        q = (1/2) * alpha * c + (1/2) * (x - eqfri);    % Monopoly output
        p = dpdq * (q + eqfri - x);                     % Monopoly price
        Q_mono(tau, t) = q;                             % Book-keeping
        Q_mono_sum(tau, t) = q + eqfri;                 % Book-keeping
        P_mono(tau, t) = p;                             % Book-keeping
        
    end    
end

%% Calculate HHI as of December 1990, based on Q_nash from 'calculateICC.m'.

% Look at 4 cartel firms' & fringe's outputs, as well as their total.
Q_nash_Dec1990 = [Q_nash(132,:,132), Q_fri(132,132), sum(Q_nash(132,:,132),2) + Q_fri(132,132)];

% Calculate HHI
Q_nash_Dec1990_hhi = sum((Q_nash_Dec1990(1:5) ./ Q_nash_Dec1990(6)).^2);

%% Calculate profits under cartel (quotas)

% Adjust dimensions of (Q_mono, P_mono, MC)
Q_mono_expanded = repmat(Q_mono,[1,1,N]);               % Expand Q_mono from [TxTx1] to [TxTxN]
Q_mono_expanded = permute(Q_mono_expanded,[1 3 2]);     % Rearrange dimensions to [TxNxT]
P_mono_expanded = repmat(P_mono,[1,1,N]);
P_mono_expanded = permute(P_mono_expanded,[1 3 2]);
MC_expanded = repmat(MC,[1,1,T]);                       % MC is now [TxNxT]

% Calculate quota based on pre-cartel Nash
Quota = sum( Q_nash(T_qb:(T_qb+11), 1:N, T_qb), 1) ./ ...
    repmat( sum( sum( Q_nash(T_qb:(T_qb+11), 1:N, T_qb), 1), 2), [1, N, 1]);
Quota = repmat( Quota, [T, 1, T]);

% Split monopoly output by quota & calculate profits under this perfect cartel
Q_quota = Quota .* Q_mono_expanded;
Pi_quota = (P_mono_expanded - MC_expanded) .* Q_quota;

%% Calculate profits under unilateral deviations from the quotas

for t = T_cartelstart:T   
    for tau = t:T
        
        % Pick up variables at (tau | t)
        x = X(tau);                             % Demand intercept [scalar]
        dpdq = dPdQ;                            % Demand slope [scalar]
        eqfri = Q_fri(tau, t);                  % Expected fringe supply [scalar]
        p0 = -dpdq * (x - eqfri);               % Y-intercept of the inverse demand, given fringe (choke price)
        
        for i = 1:N

            % Given other cartel members' quota outputs
            Qj = Q_mono(tau, t) - Q_quota(tau, i, t);
            mc = MC(tau, i);
            
            % Calculate the optimal unilateral-deviation output
            q = .5 * (p0/abs(dpdq) - Qj - mc/abs(dpdq));
            p = dpdq * (Qj + q + eqfri - x);
            pi = (p - mc) * q;
            Q_cheat(tau, i, t) = q;
            Q_cheat_total(tau, i, t) = Qj + q;
            P_cheat(tau, i, t) = p;
            Pi_cheat(tau, i, t) = pi;
            
        end
    end
end    

% Collect actual (tau = t) series, for "sanity check"
P_nash_actual = diag(P_nash);
P_mono_actual = diag(P_mono);
P_cheat_actual_roche = diag(squeeze(P_cheat(:, 1, :)));
P_cheat_actual_takeda = diag(squeeze(P_cheat(:, 2, :)));
P_cheat_actual_emerck = diag(squeeze(P_cheat(:, 3, :)));
P_cheat_actual_basf = diag(squeeze(P_cheat(:, 4, :)));

P_compare = [P, P_nash_actual, P_mono_actual, ...
    P_cheat_actual_roche, P_cheat_actual_takeda, ...
    P_cheat_actual_emerck, P_cheat_actual_basf];

%% Prepare longer versions of profits

% Longer time horizons (to incorporate post-sample periods)
T100 = 12 * 100;            % 100-year horizon
T120 = 12 * 120;            % 120-year horizon (from 1980 to 2099)

% Extending profits
Pi_nash_120 = zeros(T120, N, T);
Pi_quota_120 = zeros(T120, N, T);
Pi_cheat_120 = zeros(T120, N, T);
Pi_nash_120(1:T, :, :) = Pi_nash;
Pi_quota_120(1:T, :, :) = Pi_quota;
Pi_cheat_120(1:T, :, :) = Pi_cheat;
Pi_nash_120((T+1):T120, :, :) = repmat(Pi_nash(T, :, :), [(T120-T), 1, 1]);
Pi_quota_120((T+1):T120, :, :) = repmat(Pi_quota(T, :, :), [(T120-T), 1, 1]);
Pi_cheat_120((T+1):T120, :, :) = repmat(Pi_cheat(T, :, :), [(T120-T), 1, 1]);

%% Calculate PDV of profit streams & ICCs

% Initialize some parameters & variables
L = 3;                          % Monitoring lag
beta_annual = .80;              % Annual discount factor
Pi_c = zeros(T100, 1);          % Profit streams from cooperation
Pi_d = zeros(T100, 1);          % Profit streams from defection
V_c = zeros(T100, N, T);        % PDV associated with cooperation
V_d = zeros(T100, N, T);        % PDV associated with defection
V_1 = zeros(T100, N, T);        % On-path continuation value (after L months)
V_2 = zeros(T100, N, T);        % Punishment continuation value (after L months)
V_3 = zeros(T100, N, T);        % Deviation gain (gross, for L months)
V_4 = zeros(T100, N, T);        % Forgone on-path gain (for L months)
ICC_indiv = zeros(T, N);   % ICC at each t for each i
ICC_collect = zeros(T, 1);   % ICC at each t for the cartel

% Calculate PDVs
beta_monthly = beta_annual ^ (1/12);    % Monthly discount factor
Beta = zeros(T100, 1);                  % Its vector for all 'tau'
for tau = 1:T100
    Beta(tau) = beta_monthly ^ (tau - 1);
end

for t = T_cartelstart:T
    for tau = t:T
        for i = 1:N

            % Cartel/quota profits vs. cheater-and-Nash profits
            Pi_c(:, 1) = Pi_quota_120(tau:(tau+T100-1), i, t);
            Pi_d(1:L, 1) = Pi_cheat_120(tau:(tau+L-1), i, t);
            Pi_d((L+1):T100, 1) = Pi_nash_120((tau+L):(tau+T100-1), i, t);

            % Present values as of 'tau' (in expectation as of 't')
            V_c(tau, i, t) = Beta' * Pi_c;
            V_d(tau, i, t) = Beta' * Pi_d;

            % Four components of ICC: (V1 - V2) > (V3 - V4)
            V_1(tau, i, t) = Beta((L+1):T100,1)' * Pi_c((L+1):T100,1);
            V_2(tau, i, t) = Beta((L+1):T100,1)' * Pi_d((L+1):T100,1);
            V_3(tau, i, t) = Beta(1:L,1)' * Pi_d(1:L,1);             
            V_4(tau, i, t) = Beta(1:L,1)' * Pi_c(1:L,1);             

        end
    end
end

% Difference between PDVs (normalized as avg. per-period payoff)
V_delta = (1 - beta_monthly) * (V_c - V_d);

% Store individual ICCs & collective ICC
for t = T_cartelstart:T        
    for i = 1:N            
        % Each firm's lowest point across 'tau' (given info at each t)
        ICC_indiv(t, i) = min(V_delta(t:T, i, t));
    end        
    % Lowest of the individual ICCs at each 't'
    ICC_collect(t, 1) = min(ICC_indiv(t, :));
end

% Re-label key results (for comparison with bootstrap ICCs later)
X_est = X;
MC_est = MC;
P_nash_est = diag(P_nash);
P_mono_est = diag(P_mono);
ICC_indiv_est = ICC_indiv;
ICC_collect_est = ICC_collect;

% For visual inspection...
ICC_roche = ICC_indiv(:, 1);
ICC_takeda = ICC_indiv(:, 2);
ICC_emerck = ICC_indiv(:, 3);
ICC_basf = ICC_indiv(:, 4);
ICC_plot = [zeros(T,1), ICC_indiv];
V_delta_roche = squeeze(V_delta(T_cartelstart:T, 1, T_cartelstart:T));
V_delta_takeda = squeeze(V_delta(T_cartelstart:T, 2, T_cartelstart:T));
V_delta_emerck = squeeze(V_delta(T_cartelstart:T, 3, T_cartelstart:T));
V_delta_basf = squeeze(V_delta(T_cartelstart:T, 4, T_cartelstart:T));
V_1_roche = squeeze(V_1(T_cartelstart:T, 1, T_cartelstart:T));
V_2_roche = squeeze(V_2(T_cartelstart:T, 1, T_cartelstart:T));
V_3_roche = squeeze(V_3(T_cartelstart:T, 1, T_cartelstart:T));
V_4_roche = squeeze(V_4(T_cartelstart:T, 1, T_cartelstart:T));

save([results_path,'/','result_ICC']);

