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

% Bootstrap ICCs

% Load data & estimates
load([indata_path,'/','data']);          % Basic data = (P, c_Roche, q_i's, q_fri, Q, I_cartel, year)
load([results_path,'/','result_theta']); % Parameter estimates (main + bootstrap re-samples)
load([results_path,'/','result_ICC']);   % ICC estimates

% Basics
B = size(Theta_bs, 2);              % Number of bootstrap re-samples
T = 228;
T_cartelstart = 133;                % Vitamin C cartel's first month = Jan 1991
T_cartelend = 188;                  % Vitamin C cartel's final month = Aug 1995
T_qb = T_cartelstart - 24;          % Vitamin C cartel's "quota-basis" year starts = Jan 1989
N = 4;                              % Number of (cartel) firms

% Prepare storage 
X_bs = zeros(T, B);
MC_bs = zeros(T, N, B);
P_nash_bs = zeros(T, B);
P_mono_bs = zeros(T, B);
ICC_indiv_bs = zeros(T, N, B);
ICC_collect_bs = zeros(T, B);

% Show progress of 'parfor' loop
fprintf('Progress:\n');
fprintf(['\n' repmat('.',1,B) '\n\n']);

parfor b = 1:B
    
    fprintf('\b|\n');
    %fprintf('Bootstrap ICC #%4.0f... ', b);
    %tic
    
%% Pick/estimate/set "primitives"    

% Parameter estimates
alpha0 = Theta_bs(1, b);
alpha1 = Theta_bs(2, b);
alpha2 = Theta_bs(3, b);
dPdQ = 1 / alpha1;
dPdQ_year = 0;
gamma_roche = Theta_bs(4, b);
gamma_takeda = Theta_bs(5, b);
gamma_emerck = Theta_bs(6, b);
gamma_basf = Theta_bs(7, b);

% Demand
Alpha = ones(T,1) ./ (dPdQ + dPdQ_year * year);     % Demand slope [T x 1]
X = Q - Alpha .* P;                                 % Demand intercept (effective) [T x 1]
W = [ones(T,1), year];                              % Regressor = const & year
W_coeff = ((W' * W)^(-1)) * (W' * X);               % OLS estimate
%X(T) = [1, year(T) + 2] * W_coeff;  
%Alpha(T) = 1 / (dPdQ + dPdQ_year * (year(T) + 2));

% Costs
c_takeda = c_roche + gamma_takeda * ones(T,1);
c_emerck = c_roche + gamma_emerck * ones(T,1);
c_basf = c_roche + gamma_basf * ones(T,1);
c_roche2 = c_roche + gamma_roche * ones(T,1);
MC = [c_roche2, c_takeda, c_emerck, c_basf];         % Cartel firms' MCs [T x N]

% Fringe supply in future period 'tau'
% ...in cartel firms' expectations as of current period 't'
Q_fri = zeros(T, T);                                % (tau, t)
for t = 1:(T-1)
    Q_fri(1:t, t) = q_fri(1:t);                     % past = actual
    Q_fri((t+1):T, t) = q_fri(t) * ones((T-t),1);   % future = current
end
Q_fri(:, T) = q_fri;                                % no future at t = T

%% Calculate outcomes under Nash & monopoly

% Prepare temporary storage
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

for t = 1:T        
    for tau = t:T
        
        % Pick up variables at (tau | t)
        x = X(tau);                             % Demand intercept [scalar]
        dpdq = dPdQ + dPdQ_year * year(tau);    % Demand slope [scalar]
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
        dpdq = dPdQ + dPdQ_year * year(tau);    % Demand slope [scalar]
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
beta_annual = .80;              % Anuual discount factor
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
Beta = zeros(T100, 1);                              % Its vector for all 'tau'
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

% Storing key objects at each `b'
X_bs(:, b) = single(X);
MC_bs(:, :, b) = single(MC);
P_nash_bs(:, b) = single(P_nash_actual);
P_mono_bs(:, b) = single(P_mono_actual);
ICC_indiv_bs(:, :, b) = single(ICC_indiv);
ICC_collect_bs(:, b) = single(ICC_collect);

%toc
end         % for b = 1:B

%% Check the integrity of bootstrap results & clean

% Sanity check: "P_mono > P_nash" must hold at all time.
P_gap_bs = (P_mono_bs - P_nash_bs);         % [T x B]: Take the differences.
P_gap_min = min(P_gap_bs);                  % [1 x B]: Check the lowest values.
I_insane = P_gap_min < 0;                   % [1 x B]: Flag crazy re-samples.
B_insane = sum(I_insane);                   % Number of (invalid) re-samples
B_sane = B - B_insane;                      % Number of (valid) re-samples

% Drop invalid re-samples, starting from the last re-sample (to preserve the same column index)
for b = B:(-1):1
    
    if I_insane(1, b) == 1
        
        % If re-sample `b' is flagged invalid, drop it.
        X_bs(:, b) = [];
        MC_bs(:, :, b) = [];
        P_nash_bs(:, b) = [];
        P_mono_bs(:, b) = [];
        ICC_indiv_bs(:, :, b) = [];
        ICC_collect_bs(:, b) = [];
        
    end
    
end

% Collect bootstrap mean & stdev
X_mean = sum(X_bs, 2) ./ B_sane;
X_stdev = sum((X_bs - repmat(X_mean, [1, B_sane])) .^2, 2) ./ (B_sane - 1);
X_05pct = prctile(X_bs, 5, 2);
X_95pct = prctile(X_bs, 95, 2);
MC_mean = sum(MC_bs, 3) ./ B_sane;
MC_stdev = sum((MC_bs - repmat(MC_mean, [1, 1, B_sane])) .^2, 3) ./ (B_sane - 1);
MC_05pct = prctile(MC_bs, 5, 3);
MC_95pct = prctile(MC_bs, 95, 3);
P_nash_mean = sum(P_nash_bs, 2) ./ B_sane;
P_nash_stdev = sum((P_nash_bs - repmat(P_nash_mean, [1, B_sane])) .^2, 2) ./ (B_sane - 1);
P_nash_05pct = prctile(P_nash_bs, 5, 2);
P_nash_95pct = prctile(P_nash_bs, 95, 2);
P_mono_mean = sum(P_mono_bs, 2) ./ B_sane;
P_mono_stdev = sum((P_mono_bs - repmat(P_mono_mean, [1, B_sane])) .^2, 2) ./ (B_sane - 1);
P_mono_05pct = prctile(P_mono_bs, 5, 2);
P_mono_95pct = prctile(P_mono_bs, 95, 2);
ICC_indiv_mean = sum(ICC_indiv_bs, 3) ./ B_sane;
ICC_indiv_stdev = sum((ICC_indiv_bs - repmat(ICC_indiv_mean, [1, 1, B_sane])) .^2, 3) ./ (B_sane - 1);
ICC_indiv_005pct = prctile(ICC_indiv_bs, 0.5, 3);
ICC_indiv_025pct = prctile(ICC_indiv_bs, 2.5, 3);
ICC_indiv_050pct = prctile(ICC_indiv_bs, 5, 3);
ICC_indiv_950pct = prctile(ICC_indiv_bs, 95, 3);
ICC_indiv_975pct = prctile(ICC_indiv_bs, 97.5, 3);
ICC_indiv_995pct = prctile(ICC_indiv_bs, 99.5, 3);
ICC_collect_mean = sum(ICC_collect_bs, 2) ./ B_sane;
ICC_collect_stdev = sum((ICC_collect_bs - repmat(ICC_collect_mean, [1, B_sane])) .^2, 2) ./ (B_sane - 1);
ICC_collect_005pct = prctile(ICC_collect_bs, 0.5, 2);
ICC_collect_025pct = prctile(ICC_collect_bs, 2.5, 2);
ICC_collect_050pct = prctile(ICC_collect_bs, 5, 2);
ICC_collect_950pct = prctile(ICC_collect_bs, 95, 2);
ICC_collect_975pct = prctile(ICC_collect_bs, 97.5, 2);
ICC_collect_995pct = prctile(ICC_collect_bs, 99.5, 2);

% Collect X, MC, P_nash, P_mono (estimates & bootstrap standard errors)
X_estcomp = [X_est, (X_est - X_stdev), (X_est + X_stdev)];
MC_estcomp = [MC_est, (MC_est - MC_stdev), (MC_est + MC_stdev)];
P_nash_estcomp = [P_nash_est, (P_nash_est - P_nash_stdev), (P_nash_est + P_nash_stdev)];
P_mono_estcomp = [P_mono_est, (P_mono_est - P_mono_stdev), (P_mono_est + P_mono_stdev)];
P_all_estcomp = [P, P_nash_estcomp, P_mono_estcomp];

% Collect X, MC, P_nash, P_mono (bootstrap mean, standard error, & 95/05-percentiles)
X_bscomp = [X_mean, (X_mean - X_stdev), (X_mean + X_stdev), X_05pct, X_95pct];
MC_bscomp = [MC_mean, (MC_mean - MC_stdev), (MC_mean + MC_stdev), MC_05pct, MC_95pct];
P_nash_bscomp = [P_nash_mean, (P_nash_mean - P_nash_stdev), (P_nash_mean + P_nash_stdev), P_nash_05pct, P_nash_95pct];
P_mono_bscomp = [P_mono_mean, (P_mono_mean - P_mono_stdev), (P_mono_mean + P_mono_stdev), P_mono_05pct, P_mono_95pct];
P_all_bscomp = [P, P_nash_bscomp, P_mono_bscomp];

% Pick firm-specific ICCs (estimates & bootstrap standard errors)
ICC_roche_estcomp = [ICC_indiv_est(:, 1), zeros(T, 1), ICC_indiv_est(:, 1) - squeeze(ICC_indiv_stdev(:, 1, :)), ICC_indiv_est(:, 1) + squeeze(ICC_indiv_stdev(:, 1, :))];
ICC_takeda_estcomp = [ICC_indiv_est(:, 2), zeros(T, 1), ICC_indiv_est(:, 2) - squeeze(ICC_indiv_stdev(:, 2, :)), ICC_indiv_est(:, 2) + squeeze(ICC_indiv_stdev(:, 2, :))];
ICC_emerck_estcomp = [ICC_indiv_est(:, 3), zeros(T, 1), ICC_indiv_est(:, 3) - squeeze(ICC_indiv_stdev(:, 3, :)), ICC_indiv_est(:, 3) + squeeze(ICC_indiv_stdev(:, 3, :))];
ICC_basf_estcomp = [ICC_indiv_est(:, 4), zeros(T, 1), ICC_indiv_est(:, 4) - squeeze(ICC_indiv_stdev(:, 4, :)), ICC_indiv_est(:, 4) + squeeze(ICC_indiv_stdev(:, 4, :))];
ICC_collect_estcomp = [ICC_collect_est, zeros(T, 1), ICC_collect_est - ICC_collect_stdev, ICC_collect_est + ICC_collect_stdev];

% Pick firm-specific ICCs (bootstrap mean, standard error, & 95/05-percentiles)
ICC_roche_bscomp = [zeros(T, 1), ICC_indiv_005pct(:, 1), ICC_indiv_025pct(:, 1), ICC_indiv_050pct(:, 1), squeeze(ICC_indiv_mean(:, 1, :) - ICC_indiv_stdev(:, 1, :)), squeeze(ICC_indiv_mean(:, 1, :)), squeeze(ICC_indiv_mean(:, 1, :) + ICC_indiv_stdev(:, 1, :)), ICC_indiv_950pct(:, 1), ICC_indiv_975pct(:, 1), ICC_indiv_995pct(:, 1)];
ICC_takeda_bscomp = [zeros(T, 1), ICC_indiv_005pct(:, 2), ICC_indiv_025pct(:, 2),ICC_indiv_050pct(:, 2), squeeze(ICC_indiv_mean(:, 2, :) - ICC_indiv_stdev(:, 2, :)), squeeze(ICC_indiv_mean(:, 2, :)), squeeze(ICC_indiv_mean(:, 2, :) + ICC_indiv_stdev(:, 2, :)), ICC_indiv_950pct(:, 2), ICC_indiv_975pct(:, 2), ICC_indiv_995pct(:, 2)];
ICC_emerck_bscomp = [zeros(T, 1), ICC_indiv_005pct(:, 3), ICC_indiv_025pct(:, 3),ICC_indiv_050pct(:, 3), squeeze(ICC_indiv_mean(:, 3, :) - ICC_indiv_stdev(:, 3, :)), squeeze(ICC_indiv_mean(:, 3, :)), squeeze(ICC_indiv_mean(:, 3, :) + ICC_indiv_stdev(:, 3, :)), ICC_indiv_950pct(:, 3), ICC_indiv_975pct(:, 3), ICC_indiv_995pct(:, 3)];
ICC_basf_bscomp = [zeros(T, 1), ICC_indiv_005pct(:, 4), ICC_indiv_025pct(:, 4),ICC_indiv_050pct(:, 4), squeeze(ICC_indiv_mean(:, 4, :) - ICC_indiv_stdev(:, 4, :)), squeeze(ICC_indiv_mean(:, 4, :)), squeeze(ICC_indiv_mean(:, 4, :) + ICC_indiv_stdev(:, 4, :)), ICC_indiv_950pct(:, 4), ICC_indiv_975pct(:, 4), ICC_indiv_995pct(:, 4)];
ICC_collect_bscomp = [zeros(T, 1), ICC_collect_005pct(:, 1), ICC_collect_025pct(:, 1),ICC_collect_050pct, (ICC_collect_mean - ICC_collect_stdev), ICC_collect_mean, (ICC_collect_mean + ICC_collect_stdev), ICC_collect_950pct, ICC_collect_975pct, ICC_collect_995pct];

%% Save key pieces
save([results_path,'/','result_ICC_bs'], 'X_bs', 'X_mean', 'X_stdev', ...
     'MC_bs', 'MC_mean', 'MC_stdev', 'P_nash_bs', 'P_nash_mean', 'P_nash_stdev', ...
     'P_mono_bs', 'P_mono_mean', 'P_mono_stdev', ...
     'ICC_indiv_bs', 'ICC_collect_bs', ...
     'X_estcomp', 'X_bscomp', 'MC_estcomp', 'MC_bscomp', ...
     'P_nash_estcomp', 'P_nash_bscomp', 'P_mono_estcomp', 'P_mono_bscomp', 'P_all_estcomp', 'P_all_bscomp', ...
     'ICC_roche_estcomp', 'ICC_takeda_estcomp', 'ICC_emerck_estcomp', 'ICC_basf_estcomp', ...
     'ICC_collect_estcomp', 'ICC_roche_bscomp', 'ICC_takeda_bscomp', 'ICC_emerck_bscomp', ...
     'ICC_basf_bscomp', 'ICC_collect_bscomp','-v7.3');
