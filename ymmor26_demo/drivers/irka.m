function [Ar, Br, Cr, timeBuild] = irka(A, B, C, r, opts)
%IRKA Iterative Rational Krylov Algorithm for model order reduction.
%
% SYNTAX:
%   [Ar, Br, Cr, timeBuild] = irka(A, B, C, r)
%   [Ar, Br, Cr, timeBuild] = irka(A, B, C, r, opts)
%
% DESCRIPTION:
%   Computes a reduced-order model of order r via IRKA. Starting from an
%   initial set of r interpolation points (mirror images of r eigenvalues
%   of A), the algorithm iteratively updates the projection bases Vr and Wr
%   via rational Krylov subspace solves until the interpolation points
%   converge. Each iteration solves 2*r linear systems of size n. The
%   reduced matrices are extracted from the projected system at convergence.
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
%   Ar        - r x r reduced state matrix
%   Br        - r x m reduced input matrix
%   Cr        - p x r reduced output matrix
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

if nargin < 5,       opts = struct();          end
if ~isfield(opts, 'tol'),     opts.tol     = 1e-6;  end
if ~isfield(opts, 'maxiter'), opts.maxiter = 100;    end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZE INTERPOLATION POINTS.                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

timeBuild = tic;

% Use r eigenvalues of A with smallest absolute real part as initial shifts
% (mirrored to right half-plane so that A - sigma*I is nonsingular).
eigA   = eig(A);
[~, idx] = sort(abs(real(eigA)));
shifts = -eigA(idx(1:r));   % mirror images: stable → right half-plane

% Ensure complex conjugate pairs are consecutive and complete.
shifts = cplxpair(shifts);

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

    % Build projection bases column by column.
    % Vr(:,k) = (A - shifts(k)*I) \ B * b_k  (right Krylov vector)
    % Wr(:,k) = (A - shifts(k)*I)' \ C' * c_k (left  Krylov vector)
    % For MIMO: use unit right/left vectors cycling through inputs/outputs.
    for k = 1 : r
        ik = mod(k - 1, m) + 1;   % cycle through inputs
        ok = mod(k - 1, p) + 1;   % cycle through outputs
        Vr(:, k) = (A - shifts(k) * In) \ B(:, ik);
        Wr(:, k) = (A - conj(shifts(k)) * In)' \ C(ok, :)';
    end

    % Orthonormalize (improves numerical conditioning).
    [Vr, ~] = qr(Vr, 'econ');
    [Wr, ~] = qr(Wr, 'econ');

    % Project system.
    tmp  = Wr' * Vr;
    Ar   = tmp \ (Wr' * A * Vr);
    Br   = tmp \ (Wr' * B);
    Cr   = C * Vr;

    % New shifts = mirror images of eigenvalues of Ar.
    newShifts = cplxpair(-eig(Ar));

    % Convergence check: relative change in shifts.
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

timeBuild = toc(timeBuild);
fprintf(1, 'IRKA: r=%d done in %.2f s\n', r, timeBuild)
