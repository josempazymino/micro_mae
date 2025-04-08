function [para] = D2a_general_demand_estimation(NIter,ParaTol,int_data)

    % data
    iv = int_data.iv;
    W = eye(size(iv,2)+6);

    % initial
    delta0 = 3;
    mu0 = 32;
    sigma0 = 10;
    param0 = [delta0, mu0, sigma0]';

    % Variable in demand
    f=@(param) D2b_general_demand_obj(param,int_data,W); 

    i=1;
    paramold = param0;
    while (i <= NIter) || (max(abs(paramold-param0)>ParaTol)) 
        paramold = param0; 

            options_joint = optimoptions('fmincon','Display','off','SpecifyObjectiveGradient',false,...
                        'MaxFunEvals',1E4,'MaxIter',1E4,'TolX',1E-6,'TolFun',1E-6,'StepTolerance',1E-6);
            lb = [0,0, 0];
            ub = [40,90,60];

            problem = createOptimProblem('fmincon','objective',...
            f,'x0',param0,'lb',lb,'ub',ub,'options',options_joint);

            ms = MultiStart('FunctionTolerance',1e-6,'XTolerance',1e-6,...
                'StartPointsToRun', 'bounds-ineqs','UseParallel',true,...
                'Display', 'iter');
            [para,fval,exitflag,output] = run(ms,problem,100);
        
        % Updating weighting matrix
        [W00] = D2c_general_demand_grad(para,int_data);

        
        i = i+1;
        % assign new function - updated weighting matrix
        f=@(param) D2b_general_demand_obj(param,int_data,W00); 
        % loops
        param0 = para;
    end



end









