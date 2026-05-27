function gamma = hinf_norm(A, B, C, D)
%HINF_NORM Compute the H-infinity norm of an LTI system via bisection.
%
% SYNTAX:
%   gamma = hinf_norm(A, B, C, D)
%
% DESCRIPTION:
%   Computes the H-infinity norm ||G||_inf = max_omega sigma_max(G(i*omega))
%   using the Boyd-Balakrishnan Hamiltonian matrix test. For a given gamma,
%   the H-infinity norm is less than gamma if and only if the 2n x 2n
%   Hamiltonian matrix
%
%     H(gamma) = [ A + B*D'*(gamma^2*I - D*D')^{-1}*C,
%                  B*(I + D'*(gamma^2*I - D*D')^{-1}*D)*B'  ;
%                 -C'*(I + D*(gamma^2*I - D*D')^{-1}*D')*C,
%                 -(A + B*D'*(gamma^2*I - D*D')^{-1}*C)'    ]
%
%   has no eigenvalues on the imaginary axis. Bisection is performed on
%   gamma starting from a rough upper bound.
%
% INPUTS:
%   A - n x n stable state matrix
%   B - n x m input matrix
%   C - p x n output matrix
%   D - p x m feedthrough matrix (pass zeros(p,m) if absent)
%
% OUTPUTS:
%   gamma - scalar, H-infinity norm of the system
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
% CHECK INPUTS AND SETUP.                                                 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

n = size(A, 1);

assert(size(A, 2) == n, 'A must be square.')
assert(size(B, 1) == n, 'B must have n rows.')
assert(size(C, 2) == n, 'C must have n columns.')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BISECTION ON HAMILTONIAN EIGENVALUE TEST.                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Rough upper bound: use the DC gain matrix norm + a scaled B/C contribution.
tmpDC = C * ((-A) \ B) + D;
gamHi = norm(tmpDC, 2) * 10 + 1;
gamHi = max(gamHi, norm(D, 2) + 1);

% Lower bound: ensure at least the D-term contribution.
gamLo = norm(D, 2);
gamLo = max(gamLo, 1e-12);

% Grow upper bound until it satisfies the Hamiltonian test.
while ~hamiltonian_stable(A, B, C, D, gamHi, n)
    gamHi = gamHi * 2;
end

% Bisect until relative tolerance 1e-8.
tol = 1e-8;
while (gamHi - gamLo) / (gamHi + eps) > tol
    gamMid = (gamLo + gamHi) / 2;
    if hamiltonian_stable(A, B, C, D, gamMid, n)
        gamHi = gamMid;
    else
        gamLo = gamMid;
    end
end

gamma = gamHi;

end % function hinf_norm

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LOCAL HELPER.                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function ok = hamiltonian_stable(A, B, C, D, gamma, n)
%HAMILTONIAN_STABLE Check whether ||G||_inf < gamma via the Hamiltonian test.
% Returns true if the Hamiltonian matrix has no imaginary-axis eigenvalues.

g2  = gamma^2;
DDt = D * D';
DtD = D' * D;
Rg  = g2 * eye(size(DDt, 1)) - DDt;   % gamma^2*I - D*D'  (p x p)
Sg  = g2 * eye(size(DtD, 1)) - DtD;   % gamma^2*I - D'*D  (m x m)

% Hamiltonian matrix (2n x 2n).
H11 =  A + B * (D' / Rg) * C;
H12 =  B / Sg * B';
H21 = -C' / Rg * C;
H22 = -(A + B * (D' / Rg) * C)';

Ham = [H11, H12; H21, H22];

ev  = eig(Ham);
% No eigenvalue should have |real part| < 1e-8 * |imaginary part|.
ok  = all(abs(real(ev)) > 1e-8 * abs(imag(ev)) + 1e-12);

end
