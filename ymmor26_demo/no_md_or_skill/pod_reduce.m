function [Ar, Br, Cr, Dr] = pod_reduce(A, B, C, D, r)
% pod_reduce  POD / principal-component reduction via controllability Gramian.
%
%   [Ar,Br,Cr,Dr] = pod_reduce(A,B,C,D,r)
%
%   Algorithm:
%     1. Solve  A*Wc + Wc*A' + B*B' = 0  for the controllability Gramian.
%     2. Cholesky factor  Wc = Lc*Lc'.
%     3. SVD of Lc → POD modes (energy-ranked orthonormal basis U_r).
%     4. Galerkin projection:  Ar = Ur'*A*Ur,  Br = Ur'*B,  Cr = C*Ur.
%
%   This is equivalent to POD computed from the infinite-time impulse-
%   response snapshots, capturing the r most energetic input-reachable
%   directions of the state space.

n = size(A, 1);

%-- Controllability Gramian ------------------------------------------------
Wc = solve_lyap(A, B*B');
Wc = (Wc + Wc') / 2;

%-- Regularise and Cholesky ------------------------------------------------
reg  = 1e-12;
Wreg = Wc + reg * norm(Wc, 'fro') * eye(n);
[Lc, f] = chol(Wreg, 'lower');
if f ~= 0
    error('pod_reduce: Cholesky of Wc failed even after regularisation.');
end

%-- SVD of Cholesky factor → POD modes ------------------------------------
[U, S, ~] = svd(Lc, 'econ');
sv = diag(S);
fprintf('    POD singular values [1..%d]: %.3e ... %.3e  (next: %.3e)\n', ...
    r, sv(1), sv(r), sv(min(r+1, end)));

Ur = U(:, 1:r);   % n-by-r orthonormal POD basis

%-- Galerkin projection ----------------------------------------------------
Ar = Ur' * (A * Ur);
Br = Ur' * B;
Cr = C  * Ur;
Dr = D;
end
