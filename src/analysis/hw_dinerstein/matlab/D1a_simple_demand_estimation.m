function [para,se,V] = D1a_simple_demand_estimation(NIter,ParaTol,int_data)

    iv = int_data.iv;
    p_prior = int_data.p_prior;

    W = inv(1/size(p_prior,1)*iv'*iv);

    % initial
    delta0 = 3;
    a0 = max(p_prior(:))+0.5;
    param0 = [delta0, a0]';

    % Variable in intensive demand
    f=@(param) D1b_simple_demand_obj(param,int_data,W); 

    i=1;
    paramold = param0;
    while (i <= NIter) || (max(abs(paramold-param0)>ParaTol))
        paramold = param0;


            options_joint = optimoptions('fmincon','Display','off','SpecifyObjectiveGradient',false,...
                        'MaxFunEvals',1E4,'MaxIter',1E4,'TolX',1E-6,'TolFun',1E-6,'StepTolerance',1E-6);
            lb = [0,max(p_prior(:))];
            ub = [Inf,Inf];
            problem = createOptimProblem('fmincon','objective',...
            f,'x0',param0,'lb',lb,'ub',ub,'options',options_joint);
            ms = MultiStart('FunctionTolerance',1e-6,'XTolerance',1e-6,...
                'StartPointsToRun', 'bounds-ineqs','UseParallel',true,...
                'Display', 'iter');
            [para,fval,exitflag,output] = run(ms,problem,1000)
            

        % Updating weighting matrix
        [obj00,W00,se00,V00] = f(para);
       
        
        i = i+1;
        % assign new function - updated weighting matrix
        f=@(param) D1b_simple_demand_obj(param,int_data,W00); 
        param0 = para;
    end

    if nargout>1    
        se = se00;
        V = V00;
    end

end









