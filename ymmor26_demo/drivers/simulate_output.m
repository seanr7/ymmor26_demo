function [y, t] = simulate_output(A, B, C, D, tEnd, nSteps, inputType, seed)
%SIMULATE_OUTPUT Simulate the output of an LTI system for a given input signal.
%
% SYNTAX:
%   [y, t] = simulate_output(A, B, C, D, tEnd, nSteps, inputType)
%   [y, t] = simulate_output(A, B, C, D, tEnd, nSteps, inputType, seed)
%
% DESCRIPTION:
%   Simulates y(t) = C*x(t) + D*u(t) for the system x'=A*x+B*u with zero
%   initial conditions. Time integration uses the zero-order-hold (ZOH)
%   exact discretization: x(k+1) = eAdt*x(k) + Ad*u(k), where eAdt =
%   expm(A*dt) and Ad = A\(eAdt - I)*B (computed via the augmented expm
%   trick). Supported input types: 'impulse' (u = delta at t=0, i.e.,
%   x(0) = B*ones(m,1)/dt, u = 0 for t > 0), 'step' (u(t) = ones(m,1)),
%   'random' (white noise, unit variance, fixed seed).
%
% INPUTS:
%   A         - n x n stable state matrix
%   B         - n x m input matrix
%   C         - p x n output matrix
%   D         - p x m feedthrough matrix
%   tEnd      - positive scalar, simulation end time
%   nSteps    - positive integer, number of time steps
%   inputType - string; one of 'impulse', 'step', 'random'
%   seed      - nonneg integer, RNG seed for 'random' (default 0)
%
% OUTPUTS:
%   y - p x nSteps output trajectory
%   t - 1 x nSteps time vector
%

%
% This file is part of the archive Code, Data and Results for Numerical
% Experiments in "MOR Comparison Suite — ISS 1412 Benchmark"
% Copyright (c) 2026 seanr7
% All rights reserved.
% License: BSD 2-Clause license (see COPYING)
%
% Last editied: 5/26/2026
%

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHECK INPUTS AND SET DEFAULTS.                                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n = size(A, 1);   m = size(B, 2);   p = size(C, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')
assert(strcmp(inputType, 'impulse') || strcmp(inputType, 'step') || ...
    strcmp(inputType, 'random'), ...
    'inputType must be ''impulse'', ''step'', or ''random''.')

if nargin < 8,   seed = 0;   end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMPUTE ZOH DISCRETIZATION.                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dt = tEnd / nSteps;
t  = (1:nSteps) * dt;

% Augmented matrix expm trick for exact ZOH: expm([A B; 0 0]*dt).
nm    = n + m;
Maug  = [A, B; zeros(m, n + m)];
eMaug = expm(Maug * dt);
eAdt  = eMaug(1:n, 1:n);
Ad    = eMaug(1:n, n+1:nm);   % = A^{-1}*(eAdt - I)*B

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GENERATE INPUT SIGNAL.                                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch inputType
    case 'impulse'
        % Model impulse as x0 = B*ones(m,1), u = 0 for all k.
        u = zeros(m, nSteps);
        x = B * ones(m, 1);
    case 'step'
        u = ones(m, nSteps);
        x = zeros(n, 1);
    case 'random'
        rng(seed);
        u = randn(m, nSteps);
        x = zeros(n, 1);
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SIMULATE OUTPUT TRAJECTORY.                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

y = zeros(p, nSteps);
for k = 1 : nSteps
    y(:, k) = C * x + D * u(:, k);
    x        = eAdt * x + Ad * u(:, k);
end
