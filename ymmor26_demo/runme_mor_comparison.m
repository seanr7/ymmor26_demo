%% RUNME_MOR_COMPARISON
% Compare BT, IRKA, and POD on the ISS 1412 benchmark over r = [5,10,20,40,80].
%
% This file is part of the archive Code, Data and Results for Numerical
% Experiments in "MOR Comparison Suite — ISS 1412 Benchmark"
% Copyright (c) 2026 seanr7
% All rights reserved.
% License: BSD 2-Clause license (see COPYING)
%
% Last editied: 5/26/2026
%

clc;
clear all;
close all;

% Get and set all paths.
[rootpath, filename, ~] = fileparts(mfilename('fullpath'));
savename = [rootpath filesep() 'results' filesep() filename];

addpath([rootpath filesep() 'drivers'])

% Write .log file.
if exist([savename '.log'], 'file') == 2
    delete([savename '.log']);
end
diary([savename '.log'])
diary on;

fprintf(1, ['SCRIPT: ' upper(filename) '\n']);
fprintf(1, ['========' repmat('=', 1, length(filename)) '\n']);
fprintf(1, '\n');

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CONFIGURATION FLAGS.                                                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rVals    = [5, 10, 20, 40, 80];
nR       = length(rVals);
nMethods = 3;   % BT, IRKA, POD

% Simulation settings for time-domain metrics.
tEnd   = 10;
nSteps = 1000;

% Plot settings.
methodNames  = {'BT', 'IRKA', 'POD'};
inputNames   = {'impulse', 'step', 'random'};
nInputs      = length(inputNames);
colorOrder   = lines(nMethods);
markerOrder  = {'o', 's', '^'};

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LOAD BENCHMARK SYSTEM.                                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'LOADING ISS 1412 BENCHMARK.\n')
fprintf(1, '---------------------------\n')
timeLoad = tic;
data = load([rootpath filesep() 'iss12a.mat']);
A = data.A;
B = data.B;
C = data.C;
if isfield(data, 'D')
    D = data.D;
else
    D = zeros(size(C, 1), size(B, 2));
end
n = size(A, 1);   m = size(B, 2);   p = size(C, 1);
fprintf(1, 'Loaded: n=%d, m=%d, p=%d in %.2f s\n', n, m, p, toc(timeLoad))
fprintf(1, '\n')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PRE-ALLOCATE RESULT MATRICES.                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

timingData  = zeros(nR, nMethods);
hinfErrData = zeros(nR, nMethods);
h2ErrData   = zeros(nR, nMethods);
tfAvgData   = zeros(nR, nMethods);
tfPeakData  = zeros(nR, nMethods);
% Output error: nR x nMethods x nInputs.
outputErrData = zeros(nR, nMethods, nInputs);

% Full-system norms (computed once).
fprintf(1, 'COMPUTING FULL-SYSTEM NORMS.\n')
fprintf(1, '----------------------------\n')
timeNorms = tic;
hinfFull = hinf_norm(A, B, C, D);
fprintf(1, '  ||G||_inf = %.6e\n', hinfFull)
h2Full   = h2_norm(A, B, C);
fprintf(1, '  ||G||_2   = %.6e\n', h2Full)
fprintf(1, 'Full norms in %.2f s\n', toc(timeNorms))
fprintf(1, '\n')

% Full-system output trajectories for each input (computed once).
fprintf(1, 'SIMULATING FULL-SYSTEM TRAJECTORIES.\n')
fprintf(1, '------------------------------------\n')
yFull = cell(nInputs, 1);
for ii = 1 : nInputs
    fprintf(1, '  Input: %s\n', inputNames{ii})
    [yFull{ii}, tSim] = simulate_output(A, B, C, D, tEnd, nSteps, inputNames{ii});
end
fprintf(1, '\n')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN SWEEP OVER REDUCED ORDER AND METHOD.                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for ir = 1 : nR
    r = rVals(ir);
    fprintf(1, '\n')
    fprintf(1, '=================================================\n')
    fprintf(1, '  REDUCED ORDER r = %d\n', r)
    fprintf(1, '=================================================\n')

    % ---- BT ----
    fprintf(1, '\n--- BT ---\n')
    [Ar_bt, Br_bt, Cr_bt, ~, tBuild] = bt(A, B, C, r);
    Dr_bt = D;
    timingData(ir, 1) = tBuild;

    % Error system for BT: form (Ae, Be, Ce) = diag(A, Ar_bt), etc.
    Ae_bt = blkdiag(A, Ar_bt);
    Be_bt = [B; Br_bt];
    Ce_bt = [C, -Cr_bt];
    De_bt = zeros(p, m);
    hinfErrData(ir, 1) = hinf_norm(Ae_bt, Be_bt, Ce_bt, De_bt);
    h2ErrData(ir, 1)   = h2_norm(Ae_bt, Be_bt, Ce_bt);
    [tfAvgData(ir, 1), tfPeakData(ir, 1)] = ...
        tf_error(A, B, C, D, Ar_bt, Br_bt, Cr_bt, Dr_bt);

    for ii = 1 : nInputs
        [yr, ~] = simulate_output(Ar_bt, Br_bt, Cr_bt, Dr_bt, tEnd, nSteps, inputNames{ii});
        tmpNorm = norm(yFull{ii}(:), 2);
        outputErrData(ir, 1, ii) = norm(yFull{ii}(:) - yr(:), 2) / (tmpNorm + eps);
    end
    fprintf(1, 'BT r=%d: Hinf=%.4e, H2=%.4e\n', r, hinfErrData(ir,1), h2ErrData(ir,1))

    % ---- IRKA ----
    fprintf(1, '\n--- IRKA ---\n')
    [Ar_irka, Br_irka, Cr_irka, tBuild] = irka(A, B, C, r);
    Dr_irka = D;
    timingData(ir, 2) = tBuild;

    Ae_irka = blkdiag(A, Ar_irka);
    Be_irka = [B; Br_irka];
    Ce_irka = [C, -Cr_irka];
    De_irka = zeros(p, m);
    hinfErrData(ir, 2) = hinf_norm(Ae_irka, Be_irka, Ce_irka, De_irka);
    h2ErrData(ir, 2)   = h2_norm(Ae_irka, Be_irka, Ce_irka);
    [tfAvgData(ir, 2), tfPeakData(ir, 2)] = ...
        tf_error(A, B, C, D, Ar_irka, Br_irka, Cr_irka, Dr_irka);

    for ii = 1 : nInputs
        [yr, ~] = simulate_output(Ar_irka, Br_irka, Cr_irka, Dr_irka, tEnd, nSteps, inputNames{ii});
        tmpNorm = norm(yFull{ii}(:), 2);
        outputErrData(ir, 2, ii) = norm(yFull{ii}(:) - yr(:), 2) / (tmpNorm + eps);
    end
    fprintf(1, 'IRKA r=%d: Hinf=%.4e, H2=%.4e\n', r, hinfErrData(ir,2), h2ErrData(ir,2))

    % ---- POD ----
    fprintf(1, '\n--- POD ---\n')
    [Ar_pod, Br_pod, Cr_pod, tBuild] = pod(A, B, C, r);
    Dr_pod = D;
    timingData(ir, 3) = tBuild;

    Ae_pod = blkdiag(A, Ar_pod);
    Be_pod = [B; Br_pod];
    Ce_pod = [C, -Cr_pod];
    De_pod = zeros(p, m);
    hinfErrData(ir, 3) = hinf_norm(Ae_pod, Be_pod, Ce_pod, De_pod);
    h2ErrData(ir, 3)   = h2_norm(Ae_pod, Be_pod, Ce_pod);
    [tfAvgData(ir, 3), tfPeakData(ir, 3)] = ...
        tf_error(A, B, C, D, Ar_pod, Br_pod, Cr_pod, Dr_pod);

    for ii = 1 : nInputs
        [yr, ~] = simulate_output(Ar_pod, Br_pod, Cr_pod, Dr_pod, tEnd, nSteps, inputNames{ii});
        tmpNorm = norm(yFull{ii}(:), 2);
        outputErrData(ir, 3, ii) = norm(yFull{ii}(:) - yr(:), 2) / (tmpNorm + eps);
    end
    fprintf(1, 'POD r=%d: Hinf=%.4e, H2=%.4e\n', r, hinfErrData(ir,3), h2ErrData(ir,3))
end

% Save results.
save([savename '.mat'], 'rVals', 'timingData', 'hinfErrData', 'h2ErrData', ...
    'tfAvgData', 'tfPeakData', 'outputErrData', 'hinfFull', 'h2Full')
fprintf(1, '\nResults saved to %s.mat\n', savename)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIGURE 1: WALL-CLOCK TIMING.                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fig1 = figure('Name', 'Timing', 'Visible', 'off');
hold on
for im = 1 : nMethods
    semilogy(rVals, timingData(:, im), ...
        '-', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
        'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', methodNames{im})
end
hold off
xlabel('Reduced order r')
ylabel('Wall-clock time (s)')
title('ROM Build Time vs Reduced Order')
legend('Location', 'northwest')
grid on
set(gca, 'XTick', rVals, 'YScale', 'log')
saveas(fig1, [savename '_timing.pdf'])
fprintf(1, 'Figure saved: %s_timing.pdf\n', savename)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIGURE 2: H-INFINITY ERROR.                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fig2 = figure('Name', 'Hinf Error', 'Visible', 'off');
hold on
for im = 1 : nMethods
    semilogy(rVals, hinfErrData(:, im), ...
        '-', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
        'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', methodNames{im})
end
hold off
xlabel('Reduced order r')
ylabel('||G - G_r||_\infty')
title('H\infty Error vs Reduced Order')
legend('Location', 'northeast')
grid on
set(gca, 'XTick', rVals, 'YScale', 'log')
saveas(fig2, [savename '_hinf_error.pdf'])
fprintf(1, 'Figure saved: %s_hinf_error.pdf\n', savename)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIGURE 3: H2 ERROR.                                                     %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fig3 = figure('Name', 'H2 Error', 'Visible', 'off');
hold on
for im = 1 : nMethods
    semilogy(rVals, h2ErrData(:, im), ...
        '-', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
        'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', methodNames{im})
end
hold off
xlabel('Reduced order r')
ylabel('||G - G_r||_2')
title('H2 Error vs Reduced Order')
legend('Location', 'northeast')
grid on
set(gca, 'XTick', rVals, 'YScale', 'log')
saveas(fig3, [savename '_h2_error.pdf'])
fprintf(1, 'Figure saved: %s_h2_error.pdf\n', savename)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIGURE 4: TRANSFER FUNCTION ERROR.                                      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fig4 = figure('Name', 'TF Error', 'Visible', 'off');
hold on
for im = 1 : nMethods
    semilogy(rVals, tfAvgData(:, im), ...
        '-', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
        'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', [methodNames{im} ' (avg)'])
    semilogy(rVals, tfPeakData(:, im), ...
        '--', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
        'LineWidth', 1.0, 'MarkerSize', 5, 'DisplayName', [methodNames{im} ' (peak)'])
end
hold off
xlabel('Reduced order r')
ylabel('Relative error ||G(i\omega) - G_r(i\omega)||_2 / ||G(i\omega)||_2')
title('Transfer Function Error vs Reduced Order')
legend('Location', 'northeast', 'NumColumns', 2)
grid on
set(gca, 'XTick', rVals, 'YScale', 'log')
saveas(fig4, [savename '_tf_error.pdf'])
fprintf(1, 'Figure saved: %s_tf_error.pdf\n', savename)

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FIGURE 5: OUTPUT ERROR IN TIME (ONE SUBPLOT PER INPUT SIGNAL).         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fig5 = figure('Name', 'Output Error', 'Visible', 'off');
for ii = 1 : nInputs
    subplot(1, nInputs, ii)
    hold on
    for im = 1 : nMethods
        semilogy(rVals, outputErrData(:, im, ii), ...
            '-', 'Marker', markerOrder{im}, 'Color', colorOrder(im, :), ...
            'LineWidth', 1.5, 'MarkerSize', 7, 'DisplayName', methodNames{im})
    end
    hold off
    xlabel('Reduced order r')
    ylabel('Relative L2 output error')
    title([inputNames{ii}, ' input'])
    if ii == 1
        legend('Location', 'northeast')
    end
    grid on
    set(gca, 'XTick', rVals, 'YScale', 'log')
end
sgtitle('Time-Domain Output Error vs Reduced Order')
set(fig5, 'Position', [100, 100, 1200, 400])
saveas(fig5, [savename '_output_error.pdf'])
fprintf(1, 'Figure saved: %s_output_error.pdf\n', savename)

fprintf(1, '\nSCRIPT COMPLETE.\n')
diary off
