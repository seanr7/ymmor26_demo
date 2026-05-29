function [Ar, Br, Cr, Dr] = bt_reduce(A, B, C, D, r)
% bt_reduce  Balanced Truncation model reduction (no toolbox).
%
%   [Ar,Br,Cr,Dr] = bt_reduce(A,B,C,D,r)
%
%   Algorithm:
%     1. Solve controllability Gramian:  A*Wc + Wc*A' + B*B' = 0
%     2. Solve observability Gramian:    A'*Wo + Wo*A + C'*C  = 0
%     3. Cholesky factor both Gramians:  Wc = Lc*Lc',  Wo = Lo*Lo'
%     4. SVD of cross product:           Lo'*Lc = U*S*V'
%     5. Truncate to leading r singular triplets → biorthogonal transforms
%     6. Reduce:  Ar = Tl'*A*Tr,  Br = Tl'*B,  Cr = C*Tr

n = size(A, 1);

%-- Gramians ---------------------------------------------------------------
Wc = solve_lyap(A,  B*B');
Wo = solve_lyap(A', C'*C);

Wc = (Wc + Wc') / 2;
Wo = (Wo + Wo') / 2;

%-- Cholesky (regularise if near-singular) ---------------------------------
reg = 1e-12;
[Lc, f] = chol(Wc + reg*norm(Wc,'fro')*eye(n), 'lower');
if f ~= 0
    error('bt_reduce: Wc Cholesky failed even after regularisation.');
end
[Lo, f] = chol(Wo + reg*norm(Wo,'fro')*eye(n), 'lower');
if f ~= 0
    error('bt_reduce: Wo Cholesky failed even after regularisation.');
end

%-- SVD of Lo'*Lc  →  Hankel singular values ------------------------------
[U, S, V] = svd(Lo' * Lc);
hsv = diag(S);
fprintf('    HSV[1..%d]: %.3e ... %.3e  (next: %.3e)\n', ...
    r, hsv(1), hsv(r), hsv(min(r+1, end)));

Ur = U(:, 1:r);
Sr = diag(hsv(1:r));
Vr = V(:, 1:r);

%-- Biorthogonal projection matrices ---------------------------------------
% Tl' * Tr = I_r  by construction
Sr_invsqrt = diag(1 ./ sqrt(hsv(1:r)));

Tr = Lc * Vr * Sr_invsqrt;   % n-by-r  right transformation
Tl = Lo * Ur * Sr_invsqrt;   % n-by-r  left  transformation

%-- Reduced system ---------------------------------------------------------
Ar = Tl' * (A * Tr);
Br = Tl' * B;
Cr = C  * Tr;
Dr = D;
end
