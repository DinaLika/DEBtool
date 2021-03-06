%% filter_data_8
% filters allowable parameters for standard DEB model with acceleration

%%
function [filter flag] = filter_data_8(data, fixed_par, chem_par)
  % created 2015/01/19 by Bas Kooijman
  
  %% Syntax
  % [filter flag] = <../filter_data_8.m *filter_data_8*>(data, fixed_par, chem_par)
  
  %% Description
  % Filters data values for possible conversion to parameters 
  %    of standard DEB model with acceleration.
  % Meant to run prior to get_pars_8
  %
  % Input
  %
  % * data: 8-vector with zero-variate data
  %
  %    d_V, g/cm^3 specific density of structure
  %    a_b, d, age at birth
  %    a_p, d, age at puberty
  %    a_m, d, age at death due to ageing
  %    W_b, g, wet weight at birth
  %    W_p, g, wet weight at puberty
  %    W_m, g,  maximum wet weight
  %    R_m, #/d, maximum reproduction rate
  %
  % * fixed_par: optional 4 vector with k_J, s_G, kap_R, kap_G
  % * chem_par: optional 4 vector with w_V, w_E, mu_V, mu_E
  %  
  % Output
  %
  % * filter: 0 for hold, 1 for pass
  % * flag: indicator for reason for holding
  %
  %   0: filter passes data
  %   1: some data is negative
  %   2: ages do not increase during life cycle
  %   3: weights do not increase during life cycle
  %   4: age at birth is too large or too small
  %   5: age at puberty is too large
  %   6: age at puberty is too small
  
  %% Remarks
  %  The theory behind get_pars_9 is discussed in 
  %    <http://www.bio.vu.nl/thb/research/bib/LikaAugu2014.html LikaAugu2014>.
  %
  %% Example of use
  % See <../mydata_get_pars_8.m *mydata_get_pars_8*>
  
  %  assumptions:
  %  abundant food (f=1)
  %  p_T = 0;         % J/d.cm^2, {p_T}, surface-spec som maint cost
  if exist('fixed_par','var') == 0
     k_J = 0.002;          % 1/d, maturity maintenance rate coefficient
     s_G = 1e-4;           % -, Gopertz stress coefficient (= small)
     kap_R = 0.95;         % -, reproduction efficiency
     kap_G = 0.80;         % -, growth efficiency
  else
     k_J   = fixed_par(1); % 1/d, maturity maintenance rate coefficient
     s_G   = fixed_par(2); % -, Gopertz stress coefficient (= small)
     kap_R = fixed_par(3); % -, reproduction efficiency
     kap_G = fixed_par(4); % -, growth efficiency
  end
  if exist('chem_par', 'var') == 0
  %  C:H:O:N = 1:1.8:0.5:0.15
     w_V = 23.9;   % g/C-mol, molecular weight of structure
     w_E = 23.9;   % g/C-mol, molecular weight of reserve
     mu_V = 5E5;   % J/C-mol, chemical potential of structure
     mu_E = 5.5E5; % J/C-mol, chemical potential of reserve
  else
     w_V = chem_par(1); w_E = chem_par(2); mu_V = chem_par(3); mu_E = chem_par(4);
  end

  % unpack data
  d_V = data(1); % g/cm^3 specific density of structure
  a_b = data(2); % d, age at birth
  a_p = data(3); % d, age at puberty
  a_m = data(4); % d, age at death due to ageing
  W_b = data(5); % g, wet weight at birth
  W_p = data(6); % g, wet weight at puberty
  W_m = data(7); % g,  maximum wet weight
  R_m = data(8); % #/d, maximum reproduction rate
  
  filter = 1; flag = 0; % default setting of filter and flag

  if sum(data > 0) ~= 8
    filter = 0;
    flag = 1;
    return
  elseif a_b > a_p || a_p > a_m
    filter = 0;
    flag = 2;
    return
  elseif W_b > W_p || W_p > W_m
    filter = 0;
    flag = 3;
    return
  end

  l_b = (W_b/ W_m)^(1/3);  % -, scaled length at birth
  l_p = (W_p/ W_m)^(1/3);  % -, scaled length at puberty

  E_G = d_V * mu_V/ kap_G/ w_V;                % J/cm^3, [E_G] costs for structure
  r_B = log((1 - l_b)/(1 - l_p))/ (a_p - a_b); % 1/d, von Bertalanffy growth rate

  if r_B * a_b > l_b * (1 + l_b/ 4) || r_B * a_b < 1.93e-6 * l_b % 1/d, somatic maintenance rate coefficient
    filter = 0;
    flag = 4; % age at birth is too large or too small
    return
  end
  t_Em = a_b/ 3.7/ l_b;          % d, max reserve residence time
  p_M = 3 * r_B * E_G/ (1 - 3 * r_B * t_Em);   % J/d.cm^3, spec somatic maintenance
  k_M = p_M/ E_G;                % 1/d, somatic maintenance rate coefficient
  k_M = fzero(@fnget_kM, k_M, [], l_b, a_b, r_B); % 1/d, somatic maintenance rate coefficient
  p_M = E_G * k_M;  % J/d.cm^3, spec somatic maintenance
  g = r_B/ (k_M/ 3 - r_B); % -, energy investment ratio
  t_Em = 1/ g/ k_M;        % d, max reserve residence time

  if  fnget_kap(0, w_E, d_V, mu_E, g, E_G, l_b, l_p, W_m, t_Em, p_M, k_J, kap_R, R_m) >= 0;
    filter = 0;
    flag = 5;
  elseif fnget_kap(1, w_E, d_V, mu_E, g, E_G, l_b, l_p, W_m, t_Em, p_M, k_J, kap_R, R_m) <= 0;
    filter = 0;
    flag = 6;
  end

end

%% subfunctions

function f = fnget_kM(k_M, l_b, a_b, r_B)
  k_M = max(k_M, 3 * r_B + 1e-10); % prevent fzero to get g < 0
  g = r_B/ (k_M/ 3 - r_B); % -, energy investment ratio
  f = a_b - get_tb(g, 1, l_b)/ k_M; % set f to zero
end

function f = fnget_kap(kap, w_E, d_V, mu_E, g, E_G, l_b, l_p, W_m, t_Em, p_M, k_J, kap_R, R_m)
  kap = max(1e-8, min(1-1e-8, kap));
  k_M = p_M/ E_G;          % 1/d, somatatic maintenance rate coefficient
  E_m = E_G/ kap/ g;       % J/cm^3, (max) reserve capacity 
  w = E_m * w_E/ d_V/ mu_E;% -, contribution of reserve to weight

  L_m = (W_m/ (1 + w))^(1/3); % cm, maximum structural length
  v = L_m/ t_Em;           % cm/d, energy conductance

  L_b = l_b * L_m;         % cm, structural length at birth
  L_p = l_p * L_m;         % cm, structural length at puberty

  x_b = g/ (1 + g);        % -, see Tab 2.1 of DEB3
  alpha_b = 3 * g * x_b^(1/3)/ l_b; % -, see Tab 2.1 of DEB3
  uE0 = (3 * g/ (alpha_b - beta0(0, x_b)))^3; % -, see (2.42) of DEB3
  E_0 = uE0 * L_m^3 * E_G/ kap; % J, initial reserve

  options = odeset('RelTol', 1e-10);
  [L HE] = ode45(@dget_HE, [1e-8; L_b; L_p], [0; E_0], options, L_b, E_m, v, p_M, E_G, kap, k_J);
  E_Hp = HE(3,1); % J, maturity at puberty
  % set f to zero
  f = R_m - kap_R * (L_m^3 * k_M * E_G * (1 - kap)/ kap - k_J * E_Hp)/ E_0;
end

function dHE = dget_HE(L, EH, L_b, E_m, v, p_M, E_G, kap, k_J)
  % forward integration of E_H and E from L = 0 to L_p, with acceleration
  % unpack states
  E_H = EH(1); % J, maturity
  E = EH(2);   % J, reserve
  
  V = L^3; % cm^3, structural volume
  if L < L_b % embryo
    r = (E * v/ L - p_M * V/ kap)/ (E + E_G * V/ kap); % 1/d, specific growth rate
    p_C = E * (v/ L - r); % J/d, mobilisation rate
    dE_H = (1 - kap) * p_C - k_J * E_H; % J/d, d/dt E_H, change in maturity
    dE = - p_C;     % J/d, d/dt E, change in reserve
    dL = L * r/ 3;  % cm/d, d/dt L, change in length
  else % juvenile, post metam
    r = (E * v/ L - p_M * V/ kap)/ (E + E_G * V/ kap); % 1/d, specific growth rate
    p_C = E * (v/ L - r); % J/d, mobilisation rate
    dE_H = (1 - kap) * p_C - k_J * E_H;% J/d, d/dt E_H, change in maturity
    dL = L * r/ 3;  % cm/d, d/dt L, change in length  
    dE = E_m * 3 * L^2 * dL;  % J/d, d/dt E, change in reserve
  end
  
  dHE = [dE_H; dE]/ dL; % J/cm, change in maturity and reserve
end

