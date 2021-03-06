function [lin_restr,nonlin_restr,tpl]=create_restrictions_and_markov_chains4(tpl)
% create_restrictions_and_markov_chains4 -- creates restrictions and
% markov chains for the SVAR model in which only the variance for the
% monetary policy equation are changing.
%
% Syntax
% -------
% ::
%
%   [lin_restr,nonlin_restr,tpl]=create_restrictions_and_markov_chains4(tpl)
%
% Inputs
% -------
%
% - **tpl** [struct]: template created for SVAR objects
%
% Outputs
% --------
%
% - **lin_restr** [cell]: two column-cell (see below). The first column
% contains COEF objects or linear combinations of COEF objects, which are
% themselves COEF objects.
%
% - **nonlin_restr** [cell]: one column-cell containing inequality or
% nonlinear restrictions
%
% - **tpl** [struct]: modified template
%
% More About
% ------------
%
% - The syntax to construct an advanced COEF object is
% a=coef(eqtn,vname,lag,chain_name,state)
%   - **eqtn** [integer|char]: integer or variable name
%   - **vname** [integer|char]: integer or variable name
%   - **lag** [integer]: integer or variable name
%   - **chain_name** [char]: name of the markov chain
%   - **state** [integer]: state number
%
% - RISE sorts the endogenous variables alphabetically and use this order
% to tag each equation in SVAR and RFVAR models.
%
% - The lag coefficients are labelled a0, a1, a2,...,ak, for a model with k
% lags. Obviously, a0 denotes the contemporaneous coefficients.
%
% - The constant terms labelled c_1_1, c_2_2,...,c_n_n, for a model with n
% endogenous variables.
%
% - The standard deviations labelled sig_1_1, sig_2_2,...,sig_n_n, for a
% model with n endogenous variables.
%
% Examples
% ---------
% coef('pi','ygap',0,'policy',1)
%
% coef(2,3,0,'policy',1)
%
% coef(2,'ygap',0,'policy',1)
%
% coef('pi',3,0,'policy',1)
%
% See also:

% We add a Markov chain to the template
%----------------------------------------
% N.B: The chain controls the parameter of the policy (RRF) equation only
last=numel(tpl.markov_chains);
tpl.markov_chains(last+1)=struct('name','mpvol',...
    'states_expected_duration',[2+1i,2+1i,2+1i],...
    'controlled_parameters',{{'sig(1)'}});

% The parameter restrictions are identical to those in the basic model
% without regime switching
[lin_restr,nonlin_restr,tpl]=create_restrictions_and_markov_chains0(tpl);

end