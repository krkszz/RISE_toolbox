function [obj,retcode,LogLik]=bvar_dsge(obj,varargin)

if isempty(obj)
    obj=struct('dsgevar_lag',4,... # lags
        'dsgevar_constant',true,... VAR admits constant
        'dsgevar_var_regime',true... use the var for irf, forecasting and simulation
        ); %
    return
end

if ~obj.is_dsge_var_model
    error('this function can only be used in the presence of a DSGE-VAR model')
end

if ~isempty(varargin)
    obj=set(obj,varargin{:});
end

if obj.markov_chains.regimes_number>1
    error([mfilename,':: dsge-var for markov switching not implemented yet'])
end
if max(obj.exogenous.shock_horizon)>1
    error([mfilename,':: dsge-var with anticipations not implemented yet'])
end

[obj,retcode]=solve(obj);

% initialize those and return if there is a problem
% note we take the negative of the penalty to maximize

LogLik=-obj.options.estim_penalty;

if ~retcode
    
    dsge_var=create_dsge_var_tank(obj);
    
    % load the elements computed in load_data, using the Schorfheide notation
    %-------------------------------------------------------------------------
    p=dsge_var.p;% the var order
    T=dsge_var.T;% the sample size
    const=dsge_var.constant; % flag for constant
    n=dsge_var.n; % number of variables
    k=const+n*p;
    
    % theoretical autocovariances
    %-----------------------------
    [A,retcode]=theoretical_autocovariances(obj,'autocov_ar',p);
    if ~retcode
        % VAR approximation of the DSGE model
        %-------------------------------------
        ids=obj.observables.state_id;
        steady_state=obj.solution.ss{1}(ids);
        [PHI_theta,SIG_theta,GXX,GYX,GXY,GYY,retcode]=var_approximation_to_the_dsge(steady_state,A(ids,ids,:),const);
        if ~retcode
            % the prior weight is given by the dsge model
            %---------------------------------------------
            lambda=obj.parameter_values(obj.dsge_prior_weight_id,1);
            if lambda*T>k+n
                % load the empirical moment matrices
                %-----------------------------------
                YY=dsge_var.YY;
                YX=dsge_var.YX;
                XX=dsge_var.XX;
                XY=dsge_var.XY;
                
                % the resulting Bayesian VAR combines prior(dsge) and the data
                % through the empirical moments
                [PHIb,SIGb,ltgxx,ltgxxi]=bvar_dsge_mode();
                
                % compute likelihood
                if nargout>2
                    LogLik=bvar_dsge_likelihood();
                end
            end
            if obj.options.debug
                disp(LogLik)
            end
            if obj.options.kf_filtering_level
                % now we filter the data, provided, the parameters
                % estimated using the dsge-var do not have a low density as
                % from the point of view of the pure dsge.
                [obj,dsge_var.dsge_log_lik,~,dsge_var.dsge_retcode]=filter(obj);
            end 
        end
    end
end

store_dsge_var();

    function store_dsge_var()
        if retcode
            dsge_var=[];
        else
            dsge_var.var_approx=struct('PHI',PHI_theta,'SIG',SIG_theta);
            dsge_var.posterior.PHI=PHIb;
            dsge_var.posterior.SIG=SIGb;
            dsge_var.posterior.ZZi=ltgxxi;
            dsge_var.posterior.inverse_wishart.df=[fix((1+lambda)*T-k),n];
        end
        obj.dsge_var=dsge_var;
    end

    function [PHIb,SIGb,ltgxx,ltgxxi]=bvar_dsge_mode()
        if isinf(lambda)
            SIGb = SIG_theta;
            PHIb = PHI_theta;
            ltgxx=[];
            ltgxxi=[];
        else
            PHIb=(lambda/(1+lambda)*GXX+1/(1+lambda)*XX/T)\...
                (lambda/(1+lambda)*GXY+1/(1+lambda)*XY/T);
            
            ltgyx=lambda*T*GYX+YX;
            ltgxx=lambda*T*GXX+XX;
            ltgxxi=ltgxx\eye(size(ltgxx));
            SIGb=lambda*T*GYY+YY-ltgyx*ltgxxi*ltgyx'; % <---  SIGb=lambda*T*GYY+YY-ltgyx*(ltgxx\ltgyx');
            SIGb=SIGb/((1+lambda)*T);
        end
        
    end

    function [PHI,SIG,GXX,GYX,GXY,GYY,rcode]=var_approximation_to_the_dsge(varobs_steady,varobs_autocov,const)
        rcode=0;
        PHI=[];SIG=[];
        GYY=varobs_autocov(:,:,1);
        const=any(varobs_steady~=0)||const;
        GXX=nan(k);
        GYX=nan(n,k);
        if const
            GXX(:,1)=[1;repmat(varobs_steady,p,1)];
            GXX(1,2:end)=transpose(GXX(2:end,1));
            GYX(:,1)=varobs_steady;
        end
        
        for ii=1:p
            rr=const+((ii-1)*n+1:ii*n);
            for jj=ii:p
                cc=const+((jj-1)*n+1:jj*n);
                if ii==jj
                    GXX(rr,cc)=GYY;
                else
                    GXX(rr,cc)=varobs_autocov(:,:,jj-ii+1);
                end
            end
            GYX(:,rr)=varobs_autocov(:,:,ii+1);
        end
        GXX=triu(GXX);
        GXX=GXX+triu(GXX,1)';
        GXY=transpose(GYX);
        Gxxi=GXX\eye(k);
        if any(any(isnan(Gxxi)))
            rcode=26;
        else
            PHI=Gxxi*GXY;
            SIG=GYY-GYX*Gxxi*GXY;
        end
    end

    function LogLik=bvar_dsge_likelihood()
        if isinf(lambda)
            LogLik = -.5*T*log(det(SIGb))...
                -.5*n*T*log(2*pi)...
                -.5*trace(SIGb\(YY-YX*PHIb-PHIb'*XY+PHIb'*XX*PHIb));
        else
            LogLik=-.5*n*log(det(ltgxx))...
                -.5*((1+lambda)*T-k)*log(det((1+lambda)*T*SIGb))...
                +.5*n*log(det(lambda*T*GXX))...
                +.5*(lambda*T-k)*log(det(lambda*T*SIG_theta))...
                -.5*n*T*log(2*pi)...
                +.5*n*T*log(2)...
                +sum(gammaln(.5*((1+lambda)*T-k+1-(1:n))))...
                -sum(gammaln(.5*(lambda*T-k+1-(1:n))));
        end
    end

end

function dsge_var=create_dsge_var_tank(obj)
data=transpose(obj.data.y(:,obj.data.start:obj.data.finish));
const=obj.options.dsgevar_constant;
n=obj.observables.number(1); % endogenous observables
p=obj.options.dsgevar_lag;
Y=data(p+1:end,:);
smpl=size(Y,1);

X=nan(smpl,const+n*p);
if const
    X(:,1)=1;
end
for ii=1:p
    X(:,const+((ii-1)*n+1:ii*n))=data(p+1-ii:end-ii,:);
end
dsge_var=struct('YY',Y'*Y,'YX',Y'*X,...
    'XX',X'*X,'XY',X'*Y,'T',smpl,...
    'n',n,'p',p,'constant',const);
end