function [Ar, Br, Cr, sigma, timeBuild] = bt(A, B, C, r)
%BT Balanced Truncation model order reduction.
%
% SYNTAX:
%   [Ar, Br, Cr, sigma, timeBuild] = bt(A, B, C, r)
%
% DESCRIPTION:
%   Computes a reduced-order model of order r via balanced truncation.
%   Solves the controllability and observability Gramians via Lyapunov
%   equations, computes the Cholesky factors, forms the product L_P'*L_Q,
%   and truncates via SVD to obtain biorthogonal projection matrices Vr, Wr
%   satisfying Wr'*Vr = I_r. The reduced system is Ar=Wr'*A*Vr, Br=Wr'*B,
%   Cr=C*Vr. Only timeBuild (Lyapunov + SVD, not simulation) is returned.
%
% INPUTS:
%   A - n x n stable state matrix
%   B - n x m input matrix
%   C - p x n output matrix
%   r - positive integer, reduced order (r < n)
%
% OUTPUTS:
%   Ar        - r x r reduced state matrix
%   Br        - r x m reduced input matrix
%   Cr        - p x r reduced output matrix
%   sigma     - n x 1 vector of Hankel singular values (descending)
%   timeBuild - scalar, wall-clock build time in seconds
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

n = size(A, 1);   m = size(B, 2);   p = size(C, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')
assert(r < n,           'Reduced order r must be strictly less than full order n.')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SOLVE LYAPUNOV EQUATIONS.                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

timeTot = tic;

fprintf(1, 'BT: solving controllability Lyapunov equation (n=%d).\n', n)
fprintf(1, '------------------------------------------------------\n')
timeP = tic;
P = solve_lyapunov(A, B * B');
fprintf(1, 'BT: P solved in %.2f s\n', toc(timeP))

fprintf(1, 'BT: solving observability Lyapunov equation (n=%d).\n', n)
fprintf(1, '-----------------------------------------------------\n')
timeQ = tic;
Q = solve_lyapunov(A', C' * C);
fprintf(1, 'BT: Q solved in %.2f s\n', toc(timeQ))

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMPUTE BALANCED REALIZATION VIA SVD.                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Cholesky factors P = Lp*Lp', Q = Lq*Lq'.
% Add small diagonal perturbation to handle near-semidefinite Gramians.
eps_reg = eps * norm(P, 'fro');
Lp = chol(P + eps_reg * eye(n), 'lower');
eps_reg = eps * norm(Q, 'fro');
Lq = chol(Q + eps_reg * eye(n), 'lower');

[U, S, V] = svd(Lp' * Lq, 'econ');
sigma      = diag(S);

% Biorthogonal projection matrices (Wr'*Vr = I_r by construction).
sigmaInvHalf = diag(sigma(1:r).^(-1/2));
Vr = Lp * U(:, 1:r) * sigmaInvHalf;
Wr = Lq * V(:, 1:r) * sigmaInvHalf;

timeBuild = toc(timeTot);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BUILD REDUCED-ORDER MODEL.                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Ar = Wr' * A * Vr;
Br = Wr' * B;
Cr = C   * Vr;

fprintf(1, 'BT: r=%d done in %.2f s, HSV ratio = %.4e\n', r, timeBuild, sigma(r+1)/sigma(1))
