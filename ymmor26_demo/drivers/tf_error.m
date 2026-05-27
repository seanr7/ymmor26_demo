function [freqAvgErr, freqPeakErr, omega] = tf_error(A, B, C, D, Ar, Br, Cr, Dr)
%TF_ERROR Frequency-domain transfer function error between full and reduced systems.
%
% SYNTAX:
%   [freqAvgErr, freqPeakErr, omega] = tf_error(A, B, C, D, Ar, Br, Cr, Dr)
%
% DESCRIPTION:
%   Evaluates the relative transfer function error ||G(i*omega) - Gr(i*omega)||_2 /
%   ||G(i*omega)||_2 over a logarithmically spaced frequency grid, then
%   returns the frequency-averaged and peak relative errors. The 2-norm of
%   a matrix at each frequency is its largest singular value.
%
% INPUTS:
%   A  - n x n full-order state matrix
%   B  - n x m full-order input matrix
%   C  - p x n full-order output matrix
%   D  - p x m full-order feedthrough matrix
%   Ar - r x r reduced state matrix
%   Br - r x m reduced input matrix
%   Cr - p x r reduced output matrix
%   Dr - p x m reduced feedthrough matrix
%
% OUTPUTS:
%   freqAvgErr  - scalar, frequency-averaged relative error (mean over grid)
%   freqPeakErr - scalar, peak relative error (max over grid)
%   omega       - 1 x nFreq frequency grid (rad/s)
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
% CHECK INPUTS AND BUILD FREQUENCY GRID.                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n = size(A, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')

% Frequency grid: span several decades around the dominant dynamics.
% Use imaginary parts of eigenvalues to anchor the grid.
eigImag  = abs(imag(eig(A)));
eigImag  = eigImag(eigImag > 1e-10);
omegaMin = max(1e-3, min(eigImag) / 10);
omegaMax = min(1e6,  max(eigImag) * 10);
omegaMin = min(omegaMin, omegaMax / 1e6);   % ensure at least 6 decades

nFreq = 300;
omega = logspace(log10(omegaMin), log10(omegaMax), nFreq);

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EVALUATE TRANSFER FUNCTION ERROR OVER FREQUENCY GRID.                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

In = eye(n);
Ir = eye(size(Ar, 1));

relErr = zeros(1, nFreq);
for k = 1 : nFreq
    iw   = 1i * omega(k);
    G    = C  * ((iw * In - A)  \ B)  + D;
    Gr   = Cr * ((iw * Ir - Ar) \ Br) + Dr;
    GErr = G - Gr;

    normG   = max(svd(G));
    normErr = max(svd(GErr));
    relErr(k) = normErr / (normG + eps);
end

freqAvgErr  = mean(relErr);
freqPeakErr = max(relErr);
