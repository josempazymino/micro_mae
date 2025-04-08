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

% Joint estimation of demand & cost parameters by 1-step GMM w/ bootstrap std. err.
global P P_ann c_roche Q q_roche q_takeda q_emerck q_basf q_fri  iv iv_ann Num_months W

% Load data
load([indata_path,'/','data']);
load([indata_path,'/','worldbank_hic2']);     % Population & GDP data (annual)

% Choose IV (demand shifter) and make it monthly. Default is log population (in High-Income Countries)
Num_months = size(P, 1);         
Num_years = Num_months / 12;     
iv = zeros(Num_months, 1);  % Monthly IV
iv_ann = zeros(Num_months, 1);
for y = 1:Num_years
    month_begin = (y - 1) * 12 + 1;
    month_end = (y - 1) * 12 + 12;    
    for m = month_begin:month_end        
        % Make monthly demand shifter by interpolation
        weight1 = (5 - (m - month_begin)) / 12;   
        weight2 = (7 + (m - month_begin)) / 12;
        weight3 = (17 - (m - month_begin)) / 12;
        weight4 = (-5 + (m - month_begin)) / 12;        
        if m < (month_begin + month_end) / 2    % From January to June
            iv(m, 1) = weight1 * ln_pop_hic(y, 1) + weight2 * ln_pop_hic(y+1, 1);
        else    % From July to December
            iv(m, 1) = weight3 * ln_pop_hic(y+1, 1) + weight4 * ln_pop_hic(y+2, 1);
        end        
        % Also prepare annual-average version
        iv_ann(month_begin:month_end, 1) = ln_pop_hic(y, 1);    
    end
end

% Make annual (average) version from monthly prices.
P_ann = P;
for y = 1:Num_years
    month_begin = (y - 1) * 12 + 1;
    month_end = (y - 1) * 12 + 12;   
    P_ann(month_begin:month_end, 1) = ones(12,1) * (sum(P(month_begin:month_end, 1), 1)/12);
end    

% Use only "non-cartel" months
P = P(I_cartel == 0);
P_ann = P_ann(I_cartel == 0);
Q = Q(I_cartel == 0);
c_roche = c_roche(I_cartel == 0);
q_roche = q_roche(I_cartel == 0);
q_takeda = q_takeda(I_cartel == 0);
q_emerck = q_emerck(I_cartel == 0);
q_basf = q_basf(I_cartel == 0);
q_fri = q_fri(I_cartel == 0);
year = year(I_cartel == 0);
iv = iv(I_cartel == 0);
iv_ann = iv_ann(I_cartel == 0);

% Avoid using the first 24 months (1980-1981) in vitamin C, because q_basf = 0.
T_new = size(P, 1);
P = P(25:T_new, 1);
P_ann = P_ann(25:T_new, 1);
Q = Q(25:T_new, 1);
c_roche = c_roche(25:T_new, 1);
q_roche = q_roche(25:T_new, 1);
q_takeda = q_takeda(25:T_new, 1);
q_emerck = q_emerck(25:T_new, 1);
q_basf = q_basf(25:T_new, 1);
q_data = [q_roche, q_takeda, q_emerck, q_basf]; % Store equal-split q's as data
q_fri = q_fri(25:T_new, 1);
year = year(25:T_new, 1);
iv = iv(25:T_new, 1);
iv_ann = iv_ann(25:T_new, 1);
Num_months = size(P, 1);   % Eventual sample size for estimation
Num_years = Num_months / 12;                    % Eventual number of years

% Estimation by GMM (1st stage)
x0 = [0; 1/-2.828; 0; 0; 3.547; 4.552; 4.933]; % Initial parameter values (= 2020 ver.)
W = []; % Obj. fun. will automatically set W to be identity matrix in the 1st stage.
options = optimset('Display','off','TolFun',1e-8,'TolX',1e-6,'MaxIter',10000,'MaxFunEvals',10000);
fprintf('\n Estimation by GMM (1st stage)');
Theta = fminsearch(@gmm_obj,x0,options);

fprintf('\n -------------------------------------------------------------------------------');
fprintf('\n Parameter:     alpha0     alpha1     alpha2    gam_Roche    gam_Takeda  gam_Emerck  gam_Basf');
fprintf('\n Coefficient:   %4.4f    %4.4f    %4.4f    %4.4f       %4.4f      %4.4f      %4.4f', Theta');
fprintf('\n');
fprintf('\n Note: dP/dQ = 1 / alpha1 = %4.4f', 1/Theta(2)');
fprintf('\n -------------------------------------------------------------------------------\n');
fprintf('\n');

%% Bootstrap standard errors

% Store the main data in one place, for easy resampling.
Data_main = [P, P_ann, Q, c_roche, q_data, q_fri, year, iv, iv_ann];
Num_var = size(Data_main, 2);           % Number of variables

% Prepare B = 1000 re-samples & estimate-holder.
B = 1000;   % The number of bootstraps
Data_bs = zeros(Num_months, Num_var, B);% Dimension = T periods, 12 variables, B resamples
Num_para = size(Theta, 1);              % Number of parameters
Theta_bs = zeros(Num_para, B);          % Dimension = 6 parameters, B resamples

% Generate random numbers.
seed = 645456;                          % Seed for random draws
rng(seed);                              % Set seed
U = single(rand(Num_years, B));         % Draws from U(0,1) = Num_years blocks, B resamples
Picker = zeros(size(U));                % Indicator of the block (year) to pick

for b = 1:B
    
    fprintf('\n ');
    fprintf('\n Resampling #%4.0f of %4.0f', b, B);
        
    for y = 1:Num_years
        
        % Convert random numbers into the ID# of blocks.
        u = U(y, b);            % The random draw for (year, resample) = (y, b)
        Picker(y, b) = (u < (1/Num_years)) * 1 ...
            + ((u >= (1/Num_years)) && (u < (2/Num_years))) * 2 ...
            + ((u >= (2/Num_years)) && (u < (3/Num_years))) * 3 ...
            + ((u >= (3/Num_years)) && (u < (4/Num_years))) * 4 ...
            + ((u >= (4/Num_years)) && (u < (5/Num_years))) * 5 ...
            + ((u >= (5/Num_years)) && (u < (6/Num_years))) * 6 ...
            + ((u >= (6/Num_years)) && (u < (7/Num_years))) * 7; ...
%             + ((u >= (7/Num_years)) && (u < (8/Num_years))) * 8 ...
%             + ((u >= (8/Num_years)) && (u < (9/Num_years))) * 9;

        % Copy the designated (1 year = 12 months x Num_var) block of Data_main.
        month_begin = (y - 1) * 12 + 1;
        month_end = (y - 1) * 12 + 12;
        y_pick = Picker(y, b);
        m_pick_begin = (y_pick - 1) * 12 + 1;
        m_pick_end = (y_pick - 1) * 12 + 12;
        Data_bs(month_begin:month_end, :, b) = Data_main(m_pick_begin:m_pick_end, :);
        
    end
    
    % Using resample 'b'
    P = Data_bs(:, 1, b);
    P_ann = Data_bs(:, 2, b);
    Q = Data_bs(:, 3, b);
    c_roche = Data_bs(:, 4, b);
    q_roche = Data_bs(:, 5, b);
    q_takeda = Data_bs(:, 6, b);
    q_emerck = Data_bs(:, 7, b);
    q_basf = Data_bs(:, 8, b);
    q_fri = Data_bs(:, 9, b);
    year = Data_bs(:, 10, b);
    iv = Data_bs(:, 11, b);
    iv_ann = Data_bs(:, 12, b);
    
    % Estimation by 1-step GMM
    Theta_temp = fminsearch(@gmm_obj,x0,options);
    fprintf('\n Parameter:     alpha0     alpha1     alpha2    gam_Roche   gam_Takeda  gam_Emerck  gam_Basf');
    fprintf('\n Coefficient:   %4.4f    %4.4f    %4.4f    %4.4f      %4.4f      %4.4f      %4.4f', Theta_temp');
    
    % Record each bootstrap estimate
    Theta_bs(:, b) = Theta_temp;
end
   
% Mean & stdev of parameters across B resamples
Theta_mean = sum(Theta_bs, 2) / B;
Theta_stdev = sum((Theta_bs - repmat(Theta_mean, [1 B])) .^ 2, 2) / (B - 1);

% Display estimates
fprintf('\n');
fprintf('\n -------------------------------------------------------------------------------');
fprintf('\n Parameter:     alpha0     alpha1     alpha2    gam_Roche    gam_Takeda  gam_Emerck  gam_Basf');
fprintf('\n Coefficient:   %4.4f    %4.4f    %4.4f    %4.4f       %4.4f      %4.4f      %4.4f', Theta');
fprintf('\n B.S. mean:     %4.4f    %4.4f    %4.4f    %4.4f       %4.4f      %4.4f      %4.4f', Theta_mean');
fprintf('\n B.S. stdev:     %4.4f    %4.4f    %4.4f    %4.4f       %4.4f      %4.4f      %4.4f', Theta_stdev');
fprintf('\n');
fprintf('\n Note: dP/dQ = 1 / alpha1 = %4.4f', 1/Theta(2));
fprintf('\n Mean of dP/dQ = %4.4f', 1/Theta_mean(2));
fprintf('\n Stdev of dP/dQ = %4.4f', abs((1 / (Theta(2) + Theta_stdev(2))) - (1/ Theta(2))));
fprintf('\n -------------------------------------------------------------------------------\n');
fprintf('\n');

save([results_path,'/','result_theta'], 'Theta', 'Theta_bs', 'Theta_mean', 'Theta_stdev', '-v7.3');
