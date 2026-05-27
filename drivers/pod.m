function [Ar, Br, Cr, timeBuild] = pod(A, B, C, r, opts)
%POD Proper Orthogonal Decomposition model order reduction.
%
% SYNTAX:
%   [Ar, Br, Cr, timeBuild] = pod(A, B, C, r)
%   [Ar, Br, Cr, timeBuild] = pod(A, B, C, r, opts)
%
% DESCRIPTION:
%   Collects state snapshots from an impulse response simulation (one
%   impulse per input column of B, each run for tEnd seconds with nSteps
%   time steps via the matrix exponential). Forms the snapshot matrix X,
%   computes its SVD, and projects onto the leading r left singular
%   vectors (the POD basis Vr). The reduced system uses a Galerkin
%   projection: Ar=Vr'*A*Vr, Br=Vr'*B, Cr=C*Vr. Only timeBuild (snapshot
%   collection + SVD) is returned; simulation time is included.
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
%   | tEnd            | positive scalar, simulation end time in seconds   |
%   |                 | (default 5)                                       |
%   +-----------------+---------------------------------------------------+
%   | nSteps          | positive integer, number of time steps            |
%   |                 | (default 500)                                     |
%   +-----------------+---------------------------------------------------+
%
% OUTPUTS:
%   Ar        - r x r reduced state matrix
%   Br        - r x m reduced input matrix
%   Cr        - p x r reduced output matrix
%   timeBuild - scalar, wall-clock build time in seconds (includes simulation)
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

if nargin < 5,          opts = struct();       end
if ~isfield(opts, 'tEnd'),   opts.tEnd   = 5;    end
if ~isfield(opts, 'nSteps'), opts.nSteps = 500;  end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COLLECT SNAPSHOTS FROM IMPULSE RESPONSES.                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

timeBuild = tic;

fprintf(1, 'POD: collecting snapshots (n=%d, m=%d, nSteps=%d).\n', n, m, opts.nSteps)
fprintf(1, '----------------------------------------------------------\n')

dt        = opts.tEnd / opts.nSteps;
snapshots = zeros(n, m * opts.nSteps);   % pre-allocate full snapshot matrix

% Matrix exponential propagator (computed once for all inputs).
timeProp = tic;
eAdt = expm(A * dt);
fprintf(1, 'POD: expm computed in %.2f s\n', toc(timeProp))

for j = 1 : m
    x = B(:, j);   % impulse initial condition x0 = B*e_j
    colOffset = (j - 1) * opts.nSteps;
    for k = 1 : opts.nSteps
        x = eAdt * x;
        snapshots(:, colOffset + k) = x;
    end
    fprintf(1, 'POD: input %d of %d done.\n', j, m)
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SVD OF SNAPSHOT MATRIX AND POD BASIS.                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'POD: computing SVD of snapshot matrix (%d x %d).\n', n, m * opts.nSteps)
fprintf(1, '---------------------------------------------------\n')
timeSvd = tic;
[Vr, ~, ~] = svd(snapshots, 'econ');
Vr         = Vr(:, 1:r);
fprintf(1, 'POD: SVD done in %.2f s\n', toc(timeSvd))

timeBuild = toc(timeBuild);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BUILD REDUCED-ORDER MODEL (GALERKIN PROJECTION).                       %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Ar = Vr' * A * Vr;
Br = Vr' * B;
Cr = C   * Vr;

fprintf(1, 'POD: r=%d done in %.2f s\n', r, timeBuild)
