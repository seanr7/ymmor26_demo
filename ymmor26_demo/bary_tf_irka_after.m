function [bf, poles] = bary_tf_irka(z_init, H, Hp, opts)
%BARY_TF_IRKA Barycentric TF-IRKA for L^{2}-optimal rational approximation.
%
% SYNTAX:
%   [bf, poles] = bary_tf_irka(z_init, H, Hp)
%   [bf, poles] = bary_tf_irka(z_init, H, Hp, opts)
%
% DESCRIPTION:
%   Computes a type (m, m) rational approximation to a function H using
%   IRKA in barycentric form. At each iteration, a Hermite interpolant is
%   constructed at the current interpolation points and a fixed point at
%   the origin; new interpolation points are computed by reflecting the
%   poles of the interpolant across the unit circle:
%
%       z_new = 1./conj(poles)
%
%   The algorithm terminates after opts.maxIter iterations and returns the
%   final barycentric form approximation and the full pole history.
%
%   A good initial choice for z_init is the reciprocals of the poles from
%   an AAA approximation to H.
%
% INPUTS:
%   z_init - m x 1 vector of initial interpolation points
%        H - function handle for the function to approximate
%       Hp - function handle for the derivative of H
%     opts - structure, containing the following optional entries:
%   +-----------------+---------------------------------------------------+
%   |    PARAMETER    |                     MEANING                       |
%   +-----------------+---------------------------------------------------+
%   | maxIter         | positive integer, maximum number of iterations    |
%   |                 | (default 20)                                      |
%   +-----------------+---------------------------------------------------+
%
% OUTPUTS:
%       bf - BarycentricForm object containing the final L^{2}-optimal
%            rational approximation; use bf.eval(z) to evaluate
%    poles - m x (maxIter + 1) matrix of pole history across all
%            iterations; poles(:, end) gives the final poles
%

%
% This file is part of the archive Code, Data and Results for Numerical
% Experiments in "Barycentric TF-IRKA"
% Copyright (c) 2026 Michael S. Ackermann, Sean Reiter, Lloyd N. Trefethen.
% All rights reserved.
% License: BSD 2-Clause license (see COPYING)
%
% Last editied: 5/27/2026
%

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHECK INPUTS.                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

m = length(z_init);
z = reshape(z_init, [m, 1]);

if (nargin < 4)
    opts = struct();
end

if ~isfield(opts, 'maxIter')
    opts.maxIter = 20;
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% INITIALIZATION.                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Hz  = nan(m, 1);
Hpz = nan(m, 1);
for i = 1:m
    Hz(i)  = H(z(i));
    Hpz(i) = Hp(z(i));
end

poles = nan(m, opts.maxIter + 1);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ITERATION.                                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for k = 1:opts.maxIter
    bf = HermiteBary([z; 0], [Hz; H(0)], Hpz);
    eg = bf.poles;
    poles(:, k) = eg;
    z = 1./conj(eg);
    for i = 1:m
        Hz(i)  = H(z(i));
        Hpz(i) = Hp(z(i));
    end
end

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TERMINATION.                                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

eg = bf.poles;
poles(1:m, end) = eg;

end


function bf = HermiteBary(lam, h, d)
%HERMITEBARY Construct a Hermite interpolant in barycentric form.
%
% SYNTAX:
%   bf = HermiteBary(lam, h, d)
%
% DESCRIPTION:
%   Forms the (n-1) x n Loewner matrix from the interpolation data, takes
%   the last right singular vector as barycentric weights, and returns the
%   interpolant as a BarycentricForm object.
%
% INPUTS:
%   lam - n x 1 vector of interpolation points
%     h - n x 1 vector of function values at interpolation points
%     d - (n-1) x 1 vector of derivative values at interpolation points
%
% OUTPUTS:
%    bf - BarycentricForm object representing the Hermite interpolant
%

n = length(lam);

% Off-diagonal entries are divided differences; diagonal entries use
% derivative values (Hermite confluent limit of the divided difference).
L = nan(n - 1, n);
for i = 1:(n - 1)
    for j = 1:n
        if i == j
            L(i, j) = -d(i);
        else
            L(i, j) = (h(j) - h(i))/(lam(i) - lam(j));
        end
    end
end

[~, ~, V] = svd(L);
w = V(:, end);

bf = BarycentricForm(lam, h.*w, w);

end
