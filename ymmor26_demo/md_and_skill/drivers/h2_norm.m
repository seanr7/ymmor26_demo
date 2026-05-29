function gamma = h2_norm(A, B, C)
%H2_NORM Compute the H2 norm of a stable LTI system (D = 0 assumed).
%
% SYNTAX:
%   gamma = h2_norm(A, B, C)
%
% DESCRIPTION:
%   Computes ||G||_2 = sqrt(trace(B'*Q*B)) = sqrt(trace(C*P*C')), where
%   P (controllability Gramian) and Q (observability Gramian) satisfy the
%   Lyapunov equations A*P + P*A' + B*B' = 0 and A'*Q + Q*A + C'*C = 0.
%   Uses the controllability Gramian formulation (cheaper when m < p).
%   Requires D = 0; if D ≠ 0 the H2 norm is infinite.
%
% INPUTS:
%   A - n x n stable state matrix
%   B - n x m input matrix
%   C - p x n output matrix
%
% OUTPUTS:
%   gamma - scalar, H2 norm of the system (nonneg)
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
% CHECK INPUTS.                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n = size(A, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SOLVE CONTROLLABILITY GRAMIAN AND COMPUTE TRACE FORMULA.               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

P     = solve_lyapunov(A, B * B');
gamma = sqrt(max(0, trace(C * P * C')));
