function [bf, poles] = bary_tf_irka(z_init, H, Hp, opts)
%BARY_TF_IRKA Barycentric-form IRKA for rational interpolation of a scalar
% transfer function.
%
% SYNTAX:
%   [bf, poles] = bary_tf_irka(z_init, H, Hp)
%   [bf, poles] = bary_tf_irka(z_init, H, Hp, opts)
%
% DESCRIPTION:
%   Implements a scalar variant of the Iterative Rational Krylov Algorithm
%   (IRKA) in barycentric form. Starting from m initial interpolation
%   points z_init, each iteration builds a Hermite barycentric interpolant
%   through the current nodes (with the origin appended as a value-only
%   node), extracts its poles, and updates the interpolation points as
%   the reciprocal conjugates of those poles (z <- 1/conj(poles)).
%
% INPUTS:
%   z_init - m x 1 vector, initial interpolation points (complex)
%        H - function handle; H(s) returns the scalar transfer function
%            value at s
%       Hp - function handle; Hp(s) returns the derivative H'(s) at s
%     opts - structure, optional settings:
%   +-----------------+---------------------------------------------------+
%   |    PARAMETER    |                     MEANING                       |
%   +-----------------+---------------------------------------------------+
%   | maxIter         | positive integer, maximum number of IRKA          |
%   |                 | iterations (default 20)                           |
%   +-----------------+---------------------------------------------------+
%
% OUTPUTS:
%      bf - BarycentricForm object, final Hermite barycentric interpolant
%           built at the last set of interpolation points
%   poles - m x (maxIter + 1) matrix; column k holds the poles of the
%           barycentric interpolant after iteration k; the last column
%           repeats the final poles
%

%
% This file is part of the archive Code, Data and Results for Numerical
% Experiments in "<Paper title here>"
% Copyright (c) 2026 <Author names>
% All rights reserved.
% License: BSD 2-Clause license (see COPYING)
%
% Last editied: 5/27/2026
%
m = length(z_init);
z = reshape(z_init, [m, 1]);

if (nargin < 4)
    opts = struct();
end

if ~isfield(opts, 'maxIter')
    opts.maxIter = 20;
end

Hz  = nan(m, 1);
Hpz = nan(m, 1);
for i = 1:m
    Hz(i)  = H(z(i));
    Hpz(i) = Hp(z(i));
end

poles = nan(m, opts.maxIter + 1);

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

eg = bf.poles;
poles(1:m, end) = eg;

end


function bf = HermiteBary(lam, h, d)
%HERMITEBARY Build a Hermite barycentric interpolant from nodes, values,
% and derivatives.
%
% SYNTAX:
%   bf = HermiteBary(lam, h, d)
%
% DESCRIPTION:
%   Given n interpolation nodes lam, n function values h, and n-1
%   derivative values d, constructs a rational interpolant in barycentric
%   form satisfying Hermite conditions at the first n-1 nodes and a
%   value-only condition at the last node.
%
%   Barycentric weights are the entries of the null vector of the
%   (n-1) x n Loewner-type matrix L defined by
%
%       L(i,j) = -d(i)                                   if i == j,
%       L(i,j) = (h(j) - h(i)) / (lam(i) - lam(j))      otherwise.
%
%   The null vector is extracted from the last column of V in the economy
%   SVD of L, then passed to BarycentricForm with numerator weights h.*w
%   and denominator weights w.
%
% INPUTS:
%   lam - n x 1 vector, interpolation nodes (complex)
%     h - n x 1 vector, function values at lam
%     d - (n-1) x 1 vector, derivative values at lam(1:n-1)
%
% OUTPUTS:
%   bf - BarycentricForm object encoding the rational interpolant with
%        nodes lam, numerator weights h.*w, and denominator weights w
%

n = length(lam);

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
