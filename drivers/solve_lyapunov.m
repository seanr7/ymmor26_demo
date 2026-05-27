function X = solve_lyapunov(A, Q)
%SOLVE_LYAPUNOV Solve the continuous-time Lyapunov equation A*X + X*A' + Q = 0.
%
% SYNTAX:
%   X = solve_lyapunov(A, Q)
%
% DESCRIPTION:
%   Solves A*X + X*A' + Q = 0 via the Bartels-Stewart algorithm. Reduces
%   A to complex Schur form (strictly upper triangular factor T), transforms
%   Q, then solves T*Xhat + Xhat*T^H = -Qhat column by column from right
%   to left. Each column j requires solving the upper triangular system
%   (T + conj(T(j,j))*I)*x = rhs, which is nonsingular whenever A is
%   stable (all eigenvalues of A have negative real part).
%
% INPUTS:
%   A - n x n stable state matrix (all eigenvalues in the open left half-plane)
%   Q - n x n right-hand side (symmetric; typically B*B' or C'*C)
%
% OUTPUTS:
%   X - n x n solution matrix (symmetric positive semidefinite)
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

assert(size(A, 2) == n,                        'A must be square.')
assert(size(Q, 1) == n && size(Q, 2) == n,    'Q must be n x n.')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BARTELS-STEWART: COMPLEX SCHUR + COLUMN-BY-COLUMN SOLVE.               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% A = Z * T * Z^H, T strictly upper triangular (diagonal = eigenvalues).
[Z, T] = schur(A, 'complex');

% Transform RHS: Qhat = Z^H * Q * Z.
Qhat = Z' * Q * Z;

% Solve T * Xhat + Xhat * T^H + Qhat = 0 column j = n:-1:1.
%
% Column j equation after splitting:
%   (T + conj(T(j,j))*I) * Xhat(:,j) = -Qhat(:,j)
%                                       - Xhat(:,j+1:n) * conj(T(j,j+1:n))'
%
% The coefficient matrix is upper triangular + scalar*I, nonsingular for
% stable A because Re(T(k,k)) + Re(T(j,j)) < 0 for all k,j.
Xhat = zeros(n, n);
for j = n : -1 : 1
    rhs = -Qhat(:, j);
    if j < n
        % Contribution from already-solved columns j+1:n.
        % T^H(i,j) = conj(T(j,i)) for i = j+1:n.
        rhs = rhs - Xhat(:, j+1:n) * conj(T(j, j+1:n))';
    end
    Xhat(:, j) = (T + conj(T(j, j)) * eye(n)) \ rhs;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BACK-TRANSFORM AND SYMMETRIZE.                                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

X = Z * Xhat * Z';
X = real((X + X') / 2);
