function [Ar, Br, Cr, Dr] = irka_reduce(A, B, C, D, r, varargin)
% irka_reduce  Iterative Rational Krylov Algorithm (no toolbox).
%
%   [Ar,Br,Cr,Dr] = irka_reduce(A,B,C,D,r)
%   [Ar,Br,Cr,Dr] = irka_reduce(A,B,C,D,r,'MaxIter',100,'Tol',1e-6)
%
%   Algorithm (Gugercin–Antoulas–Beattie 2008):
%     Iterate tangential Krylov projections until interpolation points
%     (= mirror images of ROM poles) converge.  Each step:
%       V(:,i) = (sigma_i*I - A) \ (B * b_i)     right Krylov vectors
%       W(:,i) = (sigma_i*I - A)' \ (C' * c_i)   left  Krylov vectors
%     Petrov-Galerkin project, extract new poles/directions from ROM.
%
%   Complex conjugate pairs of shifts are processed together so the
%   projection matrices V, W stay real throughout.

%-- parse optional args ----------------------------------------------------
p = inputParser;
addParameter(p, 'MaxIter', 100);
addParameter(p, 'Tol',     1e-6);
parse(p, varargin{:});
max_iter = p.Results.MaxIter;
tol      = p.Results.Tol;

n = size(A, 1);
m = size(B, 2);
pp = size(C, 1);   % use pp to avoid shadowing built-in p

%-- initial interpolation points ------------------------------------------
% Spread logarithmically; use positive real shifts (A is stable → safe)
sigma = logspace(-1, 2, r)';   % r-by-1, real, positive

% Initial tangential directions: identity-style (cycle through inputs/outputs)
b_tan = zeros(m, r);
c_tan = zeros(pp, r);
for i = 1:r
    b_tan(mod(i-1, m)  + 1, i) = 1;
    c_tan(mod(i-1, pp) + 1, i) = 1;
end

Ar = []; Br = []; Cr = []; Dr = D;
prev_sigma = inf(r, 1);

for iter = 1:max_iter

    %-- build real Krylov bases -------------------------------------------
    V = zeros(n, r);
    W = zeros(n, r);

    i = 1;
    while i <= r
        si = sigma(i);

        if ~isreal(si) && i < r && abs(si - conj(sigma(i+1))) < 1e-12*abs(si)
            % Complex conjugate pair: contribute two real columns
            vi = (si*eye(n) - A) \ (B * complex(b_tan(:,i), b_tan(:,i+1)));
            wi = (conj(si)*eye(n) - A') \ (C' * complex(c_tan(:,i), c_tan(:,i+1)));
            V(:, i)   = real(vi);
            V(:, i+1) = imag(vi);
            W(:, i)   = real(wi);
            W(:, i+1) = imag(wi);
            i = i + 2;
        else
            % Real shift (or unpaired)
            si = real(si);
            V(:, i) = (si*eye(n) - A) \ (B * real(b_tan(:,i)));
            W(:, i) = (si*eye(n) - A') \ (C' * real(c_tan(:,i)));
            i = i + 1;
        end
    end

    %-- QR orthonormalise --------------------------------------------------
    [V, ~] = qr(V, 0);
    [W, ~] = qr(W, 0);

    %-- Petrov-Galerkin projection -----------------------------------------
    M  = W' * V;
    AV = A * V;
    Ar = M \ (W' * AV);
    Br = M \ (W' * B);
    Cr = C * V;
    Dr = D;

    %-- eigendecomposition of ROM -----------------------------------------
    [Y, Lam] = eig(Ar);
    lam = diag(Lam);

    % Left eigenvectors:  Z(:,i) satisfies Ar'*Z(:,i) = conj(lam(i))*Z(:,i)
    Z = (Y \ eye(r))';    % columns of inv(Y)^T

    %-- update shifts and tangential directions ---------------------------
    sigma_new = -conj(lam);    % H2-optimal mirror-image condition

    b_new = zeros(m,  r);
    c_new = zeros(pp, r);
    for i = 1:r
        bi = Br' * Z(:, i);
        ci = Cr  * Y(:, i);
        % Real arithmetic: use real part (pairs handled by conjugate pairing)
        b_new(:, i) = real(bi);
        c_new(:, i) = real(ci);
        if norm(b_new(:,i)) > eps, b_new(:,i) = b_new(:,i)/norm(b_new(:,i)); end
        if norm(c_new(:,i)) > eps, c_new(:,i) = c_new(:,i)/norm(c_new(:,i)); end
    end

    %-- convergence check (shift magnitudes, sorted) ----------------------
    sn_s = sort(abs(sigma_new));
    sp_s = sort(abs(prev_sigma));
    conv_err = norm(sn_s - sp_s) / (norm(sn_s) + eps);

    sigma     = sigma_new;
    b_tan     = b_new;
    c_tan     = c_new;
    prev_sigma = sigma;

    if conv_err < tol && iter > 2
        fprintf('    IRKA converged in %d iterations (err=%.2e)\n', iter, conv_err);
        break;
    end
end

if iter == max_iter
    fprintf('    IRKA: reached max_iter=%d (final err=%.2e)\n', max_iter, conv_err);
end

% Force real (imaginary residuals from complex arithmetic are rounding noise)
Ar = real(Ar);
Br = real(Br);
Cr = real(Cr);
Dr = real(Dr);
end
