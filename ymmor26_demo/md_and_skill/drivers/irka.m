function [Ar, Br, Cr, timeBuild] = irka(A, B, C, r, opts)
%IRKA Iterative Rational Krylov Algorithm for model order reduction.
%
% SYNTAX:
%   [Ar, Br, Cr, timeBuild] = irka(A, B, C, r)
%   [Ar, Br, Cr, timeBuild] = irka(A, B, C, r, opts)
%
% DESCRIPTION:
%   Computes a reduced-order model of order r via IRKA (Gugercin, Antoulas,
%   Beattie 2008). At each iteration the r interpolation points sigma_k and
%   the tangential directions b_k (input, m x 1) and c_k (output, p x 1)
%   are updated from the eigenstructure of the current ROM:
%
%     sigma_k = -lambda_k(Ar),
%     b_k     = Br' * l_k,       l_k = k-th left eigenvector of Ar,
%     c_k     = Cr  * r_k,       r_k = k-th right eigenvector of Ar.
%
%   The projection bases are then rebuilt as rational Krylov vectors:
%
%     Vr(:,k) = (sigma_k * I - A )^{-1} * B  * b_k,
%     Wr(:,k) = (sigma_k * I - A')^{-1} * C' * c_k.
%
%   QR orthonormalization is applied to Vr and Wr each iteration for
%   numerical conditioning; the Petrov-Galerkin projection uses the
%   oblique projector defined by the (W,V) pair. At convergence the
%   ROM is returned as a real matrix triple.
%
% INPUTS:
%   A    - n x n stable state matrix
%   B    - n x m input matrix
%   C    - p x n output matrix
%   r    - positive integer, reduced order (r < n)
%   opts - structure, containing the following optional entries:
%   +-----------------+---------------------------------------------------+
%   |    PARAMETER    |                     MEANING                       |
%   +-----------------+---------------------------------------------------+
%   | tol             | nonneg scalar, convergence tolerance on           |
%   |                 | relative shift change (default 1e-6)              |
%   +-----------------+---------------------------------------------------+
%   | maxiter         | positive integer, maximum iterations              |
%   |                 | (default 100)                                     |
%   +-----------------+---------------------------------------------------+
%
% OUTPUTS:
%   Ar        - r x r reduced state matrix (real)
%   Br        - r x m reduced input matrix (real)
%   Cr        - p x r reduced output matrix (real)
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
% CHECK INPUTS AND SET DEFAULTS.                                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n = size(A, 1);   m = size(B, 2);   p = size(C, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')
assert(r < n,           'Reduced order r must be strictly less than full order n.')

if nargin < 5,                    opts = struct(); end
if ~isfield(opts, 'tol'),         opts.tol     = 1e-6; end
if ~isfield(opts, 'maxiter'),     opts.maxiter = 100;  end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZE INTERPOLATION POINTS AND TANGENTIAL DIRECTIONS.              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

timeBuild = tic;

% Initial shifts: mirror images of the r eigenvalues of A closest to the
% imaginary axis (most energetic modes).
eigA     = eig(A);
[~, idx] = sort(abs(real(eigA)));
shifts   = -eigA(idx(1:r));     % r x 1, right half-plane

% Initial tangential directions: unit vectors cycling through I/O channels.
bTangent = zeros(m, r);
cTangent = zeros(p, r);
for k = 1 : r
    bTangent(mod(k - 1, m) + 1, k) = 1;
    cTangent(mod(k - 1, p) + 1, k) = 1;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% IRKA ITERATION.                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'IRKA: starting iterations (r=%d, tol=%.1e, maxiter=%d).\n', ...
    r, opts.tol, opts.maxiter)
fprintf(1, '-------------------------------------------------------------\n')

In = eye(n);
Vr = zeros(n, r);
Wr = zeros(n, r);

for it = 1 : opts.maxiter

    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % BUILD RATIONAL KRYLOV BASES WITH CURRENT SHIFTS AND DIRECTIONS.    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    for k = 1 : r
        % Right Krylov: tangential interpolation of column space of G.
        Vr(:, k) = (shifts(k) * In - A)  \ (B  * bTangent(:, k));
        % Left Krylov: tangential interpolation of row space of G.
        % Uses same shift sigma_k (not its conjugate) — this enforces the
        % left tangential condition c_k' * G(sigma_k) = c_k' * Gr(sigma_k).
        Wr(:, k) = (shifts(k) * In - A') \ (C' * cTangent(:, k));
    end

    % QR for conditioning (span is preserved; tangential info is recovered
    % from the ROM eigenstructure below, not from individual columns).
    [Vr, ~] = qr(Vr, 'econ');
    [Wr, ~] = qr(Wr, 'econ');

    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % PETROV-GALERKIN PROJECTION.                                        %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    tmp = Wr' * Vr;
    Ar  = tmp \ (Wr' * A * Vr);
    Br  = tmp \ (Wr' * B);
    Cr  = C * Vr;

    %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % UPDATE SHIFTS AND TANGENTIAL DIRECTIONS FROM ROM EIGENSTRUCTURE.   %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Right eigenvectors: Ar * TR = TR * D  →  r_k = TR(:,k).
    % Left eigenvectors:  TL = inv(TR)^T    →  l_k = TL(:,k).
    % Biorthogonality: TL' * TR = I_r by construction.
    [TR, D_eig] = eig(Ar);
    TL          = inv(TR)';

    newShifts = -diag(D_eig);     % mirror images of ROM poles

    % Tangential directions from partial-fraction residues of Gr:
    %   Gr(s) = sum_k c_k * b_k' / (s - lambda_k)
    % where c_k = Cr*r_k (p x 1) and b_k = Br'*l_k (m x 1).
    for k = 1 : r
        cTangent(:, k) = Cr  * TR(:, k);
        bTangent(:, k) = Br' * TL(:, k);
    end

    % Convergence: relative shift change (shifts are sorted for comparison).
    relChange = norm(sort(newShifts) - sort(shifts)) / (norm(shifts) + eps);
    fprintf(1, 'IRKA: iter %d, relChange = %.4e\n', it, relChange)

    shifts = newShifts;

    if relChange < opts.tol
        fprintf(1, 'IRKA: converged at iter %d.\n', it)
        break
    end

end

if it == opts.maxiter
    fprintf(1, 'IRKA: WARNING — reached maxiter=%d without convergence.\n', opts.maxiter)
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RETURN REAL ROM.                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% For a real system with conjugate-symmetric shifts, imaginary parts of
% Ar, Br, Cr are near-zero at convergence; take real part to be safe.
Ar = real(Ar);
Br = real(Br);
Cr = real(Cr);

timeBuild = toc(timeBuild);
fprintf(1, 'IRKA: r=%d done in %.2f s\n', r, timeBuild)
