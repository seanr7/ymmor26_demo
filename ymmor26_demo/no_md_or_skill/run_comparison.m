% run_comparison.m
% MOR comparison suite: Balanced Truncation, IRKA, POD on ISS1412.
% Metrics: timing, H-inf error, H2 error, TF error over frequency,
%          time-domain output error (impulse / step / random).
% Saves one figure per metric.  No toolboxes required.

clear; close all; clc;

%% =========================================================================
%% 1. Load ISS1412 benchmark
%% =========================================================================
fprintf('Loading ISS1412 ...\n');
S = load('../iss12a.mat');
fn = fieldnames(S);

if isfield(S, 'A') && isfield(S, 'B') && isfield(S, 'C')
    A = full(S.A);  B = full(S.B);  C = full(S.C);
    D = zeros(size(C,1), size(B,2));
    if isfield(S,'D'), D = full(S.D); end
elseif isfield(S, 'E')
    % Descriptor form  E*dx = A*x + B*u
    A = full(S.E) \ full(S.A);
    B = full(S.E) \ full(S.B);
    C = full(S.C);
    D = zeros(size(C,1), size(B,2));
elseif numel(fn) == 1
    sys = S.(fn{1});
    A = full(sys.A); B = full(sys.B); C = full(sys.C); D = full(sys.D);
else
    error('Unrecognised .mat structure.  Fields: %s', strjoin(fn,', '));
end

n = size(A,1);  m = size(B,2);  p = size(C,1);
fprintf('System: n=%d, m=%d, p=%d\n', n, m, p);

% Stability check – shift marginally unstable modes into the LHP
ev_check = eigs(A, min(6,n), 'LR');  % a few rightmost eigenvalues
if any(real(ev_check) >= 0)
    alpha = max(real(ev_check)) + 1e-3;
    A     = A - alpha * eye(n);
    fprintf('Stability shift applied: alpha = %.4e\n', alpha);
end

%% =========================================================================
%% 2. Setup
%% =========================================================================
r_values = [5, 10, 20, 40, 80];
nr       = numel(r_values);
methods  = {'BT','IRKA','POD'};
nm       = numel(methods);

timing    = nan(nm, nr);
hinf_err  = nan(nm, nr);
h2_err    = nan(nm, nr);

% Frequency grid
nf    = 200;
omega = logspace(-4, 2, nf);

tf_err_mat = nan(nm, nr, nf);   % max singular value of error TF at each freq

% Time-domain simulation parameters
dt    = 0.5;
T_end = 300;
tvec  = (0 : dt : T_end)';
nt    = numel(tvec);

td_imp_err  = nan(nm, nr);
td_step_err = nan(nm, nr);
td_rand_err = nan(nm, nr);

%% =========================================================================
%% 3. Pre-compute full-system responses
%% =========================================================================
fprintf('\n--- Full system pre-computation ---\n');

% Frequency response of full system
fprintf('  Frequency response ...\n');
H_full = tf_freqresp(A, B, C, D, omega);  % p x m x nf

% Time-domain: precompute discrete-time matrices once
fprintf('  Discretising full system (expm) ...\n');
[Ad_f, Bd_f] = zoh_disc(A, B, dt);

rng(0);
u_rand = randn(m, nt);   % fixed random input sequence

fprintf('  Simulating full system ...\n');
[y_imp_f, y_step_f, y_rand_f] = simulate(Ad_f, Bd_f, C, D, nt, u_rand);

fprintf('  H2 norm of full system ...\n');
h2_full = h2_norm(A, B, C);
fprintf('  ||G||_H2 = %.4e\n', h2_full);

%% =========================================================================
%% 4. Sweep (method x r)
%% =========================================================================
for im = 1:nm
    meth = methods{im};
    fprintf('\n=== %s ===\n', meth);

    for ir = 1:nr
        r = r_values(ir);
        fprintf('  r = %d ... ', r);

        %-- Reduce ---------------------------------------------------------
        t0 = tic;
        switch meth
            case 'BT'
                [Ar,Br,Cr,Dr] = bt_reduce(A, B, C, D, r);
            case 'IRKA'
                [Ar,Br,Cr,Dr] = irka_reduce(A, B, C, D, r);
            case 'POD'
                [Ar,Br,Cr,Dr] = pod_reduce(A, B, C, D, r);
        end
        timing(im, ir) = toc(t0);
        fprintf('done (%.1f s)\n', timing(im,ir));

        %-- H-inf error (frequency sweep) ----------------------------------
        H_rom = tf_freqresp(Ar, Br, Cr, Dr, omega);
        for k = 1:nf
            tf_err_mat(im, ir, k) = max(svd(H_full(:,:,k) - H_rom(:,:,k)));
        end
        hinf_err(im, ir) = max(tf_err_mat(im, ir, :));

        %-- H2 error -------------------------------------------------------
        h2_err(im, ir) = h2_error(A, B, C, Ar, Br, Cr);

        %-- Time-domain error ----------------------------------------------
        [Ad_r, Bd_r] = zoh_disc(Ar, Br, dt);
        [y_imp_r, y_step_r, y_rand_r] = simulate(Ad_r, Bd_r, Cr, Dr, nt, u_rand);

        td_imp_err(im,ir)  = relerr(y_imp_f,  y_imp_r);
        td_step_err(im,ir) = relerr(y_step_f, y_step_r);
        td_rand_err(im,ir) = relerr(y_rand_f, y_rand_r);

        fprintf('    Hinf=%.2e  H2=%.2e  imp=%.2e  step=%.2e  rand=%.2e\n', ...
            hinf_err(im,ir), h2_err(im,ir), ...
            td_imp_err(im,ir), td_step_err(im,ir), td_rand_err(im,ir));
    end
end

%% =========================================================================
%% 5. Figures
%% =========================================================================
cols = {'#1f77b4','#d62728','#2ca02c'};   % blue / red / green
mrks = {'o-','s-','^-'};
lw = 1.8;  ms = 7;

%-- Fig 1: Wall-clock timing ----------------------------------------------
fig1 = figure('Position',[50 50 700 430]);
for im = 1:nm
    semilogy(r_values, timing(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('Reduced order  r');  ylabel('Wall-clock time  (s)');
title('Reduction Timing — ISS1412');
legend('Location','northwest');  grid on;
saveas(fig1, 'fig_timing.png');
fprintf('\nSaved fig_timing.png\n');

%-- Fig 2: H-infinity error -----------------------------------------------
fig2 = figure('Position',[50 50 700 430]);
for im = 1:nm
    semilogy(r_values, hinf_err(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('Reduced order  r');  ylabel('H_\infty error  \|G - G_r\|_\infty');
title('H_\infty Error — ISS1412');
legend('Location','northeast');  grid on;
saveas(fig2, 'fig_hinf_error.png');
fprintf('Saved fig_hinf_error.png\n');

%-- Fig 3: H2 error -------------------------------------------------------
fig3 = figure('Position',[50 50 700 430]);
for im = 1:nm
    semilogy(r_values, h2_err(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('Reduced order  r');  ylabel('H_2 error  \|G - G_r\|_2');
title('H_2 Error — ISS1412');
legend('Location','northeast');  grid on;
saveas(fig3, 'fig_h2_error.png');
fprintf('Saved fig_h2_error.png\n');

%-- Fig 4: TF error over frequency (all r, all methods) -------------------
fig4 = figure('Position',[50 50 950 530]);
ls_r  = {'-','--',':','-.', '-'};   % one linestyle per r
for im = 1:nm
    for ir = 1:nr
        ev = squeeze(tf_err_mat(im, ir, :))';
        h  = loglog(omega, ev, ls_r{ir}, 'Color', cols{im}, 'LineWidth', 1.2);
        hold on;
        % Label only the first r for the legend
        if ir == 1
            set(h, 'DisplayName', methods{im});
        else
            set(h, 'HandleVisibility','off');
        end
    end
end
% Annotate r values with a text arrow on the last method's curves
for ir = 1:nr
    ev = squeeze(tf_err_mat(nm, ir, :))';
    [~,ki] = max(ev);
    text(omega(ki), ev(ki)*1.5, sprintf('r=%d',r_values(ir)), ...
        'FontSize',7, 'Color', cols{nm});
end
xlabel('Frequency  \omega  (rad s^{-1})');
ylabel('\sigma_{max}(G(j\omega) - G_r(j\omega))');
title('Transfer Function Error over Frequency — ISS1412');
legend('Location','best');  grid on;
saveas(fig4, 'fig_tf_error.png');
fprintf('Saved fig_tf_error.png\n');

%-- Fig 5: Time-domain errors (3 sub-panels) ------------------------------
fig5 = figure('Position',[50 50 1100 380]);

subplot(1,3,1);
for im = 1:nm
    semilogy(r_values, td_imp_err(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('r');  ylabel('Relative output error');
title('Impulse input');  legend('Location','northeast');  grid on;

subplot(1,3,2);
for im = 1:nm
    semilogy(r_values, td_step_err(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('r');  ylabel('Relative output error');
title('Step input');  legend('Location','northeast');  grid on;

subplot(1,3,3);
for im = 1:nm
    semilogy(r_values, td_rand_err(im,:), mrks{im}, ...
        'Color',cols{im}, 'LineWidth',lw, 'MarkerSize',ms, ...
        'DisplayName', methods{im});
    hold on;
end
xlabel('r');  ylabel('Relative output error');
title('Random input');  legend('Location','northeast');  grid on;

sgtitle('Time-Domain Output Errors — ISS1412');
saveas(fig5, 'fig_timedomain_error.png');
fprintf('Saved fig_timedomain_error.png\n');

fprintf('\nDone.\n');

%% =========================================================================
%% Local functions
%% =========================================================================

% -------------------------------------------------------------------------
function H = tf_freqresp(A, B, C, D, omega)
% H(p,m,nf): transfer-function values via Schur-based evaluation.
% Cost: O(n^3) for Schur once, O(n^2*m) per frequency point.
n  = size(A,1);  m = size(B,2);  p = size(C,1);  nf = numel(omega);
H  = zeros(p, m, nf);

[U, T] = schur(A, 'complex');   % A = U*T*U', T upper triangular
UB  = U' * B;    % n-by-m  (precompute once)
CU  = C  * U;    % p-by-n

for k = 1:nf
    jw = 1j * omega(k);
    % (jwI - T) is upper triangular → backslash uses O(n^2*m) triangular solve
    X = (jw*eye(n) - T) \ UB;   % n-by-m
    H(:,:,k) = CU * X + D;
end
end

% -------------------------------------------------------------------------
function h2 = h2_norm(A, B, C)
% ||G||_H2 = sqrt( trace( C * Wc * C' ) )
Wc  = solve_lyap(A, B*B');
val = trace(C * Wc * C');
h2  = sqrt(max(real(val), 0));
end

% -------------------------------------------------------------------------
function err = h2_error(A, B, C, Ar, Br, Cr)
% ||G - Gr||_H2 via H2 norm of the combined error system.
% Error system:  Ae = blkdiag(A, Ar),  Be = [B; Br],  Ce = [C, -Cr]
Ae  = blkdiag(A, Ar);
Be  = [B; Br];
Ce  = [C, -Cr];
err = h2_norm(Ae, Be, Ce);
end

% -------------------------------------------------------------------------
function [Ad, Bd] = zoh_disc(A, B, dt)
% Zero-order-hold discretisation:  Ad = e^{A*dt},  Bd = A\(Ad - I)*B.
% Falls back to Euler if A is singular.
n  = size(A,1);
Ad = expm(A * dt);
try
    Bd = A \ ((Ad - eye(n)) * B);
catch
    Bd = dt * B;   % Euler fallback
end
end

% -------------------------------------------------------------------------
function [y_imp, y_step, y_rand] = simulate(Ad, Bd, C, D, nt, u_rand)
% Simulate three responses using discrete-time recursion.
%   Impulse : x(0) = B_continuous * 1, u = 0 for t > 0.
%             Here we approximate by: initial state = sum of Bd columns.
%   Step    : constant u = ones(m,1)
%   Random  : u = u_rand(:,k)
%
% For the impulse we start from x0 = sum(Bd,2) (unit step over one dt ≈ impulse).

n = size(Ad,1);  m = size(D,2);  p = size(C,1);

u1       = ones(m,1);
x_imp    = Bd * u1;    % approximated impulse initial state
x_step   = zeros(n,1);
x_rand   = zeros(n,1);

y_imp    = zeros(p, nt);
y_step   = zeros(p, nt);
y_rand   = zeros(p, nt);

for k = 1:nt
    uk             = u_rand(:,k);
    y_imp(:,k)     = C * x_imp;                 % impulse: no direct term after t=0
    y_step(:,k)    = C * x_step  + D * u1;
    y_rand(:,k)    = C * x_rand  + D * uk;
    if k < nt
        x_imp   = Ad * x_imp;
        x_step  = Ad * x_step  + Bd * u1;
        x_rand  = Ad * x_rand  + Bd * uk;
    end
end
end

% -------------------------------------------------------------------------
function e = relerr(y_ref, y_approx)
% Relative 2-norm output error (Frobenius over all time and outputs).
denom = norm(y_ref(:));
if denom < eps
    e = norm(y_approx(:));
else
    e = norm(y_ref(:) - y_approx(:)) / denom;
end
end
