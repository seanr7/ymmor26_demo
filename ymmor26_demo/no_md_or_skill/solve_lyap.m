function X = solve_lyap(A, Q)
% solve_lyap  Solve continuous Lyapunov equation A*X + X*A' + Q = 0
%             via the Bartels-Stewart algorithm (no toolbox required).
%             A must be stable (all eigenvalues in the open left half-plane).
%
% Inputs:
%   A  n-by-n stable matrix
%   Q  n-by-n symmetric matrix (right-hand side)
%
% Output:
%   X  n-by-n symmetric solution

n = size(A, 1);

% Complex Schur decomposition: A = U * T * U'  (T upper triangular)
[U, T] = schur(A, 'complex');

% Transform RHS: Q_hat = U' * Q * U
Q_hat = U' * Q * U;

% Solve  T * Y + Y * T' + Q_hat = 0  column by column (back-substitution).
%
% For column j the equation becomes:
%   (T + conj(T(j,j)) * I) * y_j = -q_hat_j - Y(:,1:j-1) * conj(T(1:j-1,j))
%
% The coefficient matrix is upper-triangular (T is upper-triangular;
% adding a scalar to the diagonal preserves that).  For stable A all
% diagonal sums  T(k,k) + conj(T(j,j))  have strictly negative real
% parts, so the system is non-singular.

Y = zeros(n, n);
d = diag(T);                   % eigenvalues of A (diagonal of Schur form)

for j = 1:n
    rhs = -Q_hat(:, j);
    if j > 1
        rhs = rhs - Y(:, 1:j-1) * conj(T(1:j-1, j));
    end
    % Build shifted upper-triangular coefficient (modify diagonal only)
    Mj      = T;
    c       = conj(d(j));
    Mj(1:n+1:end) = d + c;     % vectorised diagonal update
    % Upper-triangular solve (MATLAB's \ detects triangularity)
    Y(:, j) = Mj \ rhs;
end

% Back-transform and symmetrise
X = U * Y * U';
X = real((X + X') / 2);
end
