---
name: my-code-style
description: Enforces a math-forward MATLAB code style for personal numerical/MOR research code. Use when writing, editing, or refactoring any .m file in this repo — algorithm implementations, helper utilities, driver scripts, and RUNME.m. Covers function headers (including opts table format for optional args), section structure, logging, variable naming, and linear algebra conventions. Prioritizes mathematical clarity and reproducibility over defensive coding.
---

# matlab-research-code-style

Apply this style to all MATLAB code in this repo. It is personal numerical
MOR research code. Optimize for mathematical clarity and readability. No
toolboxes assumed unless explicitly stated.

## Core rules

- Functions over scripts. Every `.m` file defines a function with explicit
  inputs and outputs. The only exceptions are `runme_*.m` scripts.
- No toolboxes. Do not call `lyap`, `lsim`, `balreal`, `balred`,
  `norm(sys, ...)`, or any Control/Robust Control Toolbox function. Implement
  equivalents from first principles.
- No defensive coding. No try/catch for robustness. Use `assert` for shape
  and argument checks at function entry — with a descriptive error string.
- Logging is `fprintf(1, ...)`. One line, progress-oriented. Pair
  section-start and section-end messages and always time major blocks
  with `tic`/`toc`.
- Pre-allocate all arrays before loops with `zeros(...)`.
- String comparison uses `strcmp(...)`, never `==`.
- Don't reformat or reorganize code unrelated to the requested change.

## Function header format

Every function file begins with the function signature, then an immediately
following comment block. The comment block has this exact structure — no
deviations in ordering or capitalization:

```matlab
function [OUT1, OUT2] = my_function(input1, input2, input3)
%MY_FUNCTION Brief one-line description of what the function does.
% Optional continuation of the brief description on the next line.
%
% SYNTAX:
%   [OUT1, OUT2] = my_function(input1, input2, input3)
%   out1_only    = my_function(input1, input2)
%
% DESCRIPTION:
%   Detailed explanation of the function's purpose and algorithm.
%   Mathematical context and references to companion papers are included
%   here. Cross-reference equation numbers from the paper as (eq. N).
%
% INPUTS:
%   input1 - n x n state matrix of the system
%   input2 - n x m input matrix of the system
%   input3 - positive integer, order of the reduced model
%   input4 - string indicating the method to use; options are 'Foo' and
%             'Bar' (default 'Foo')
%
% OUTPUTS:
%   OUT1 - r x r reduced state matrix
%   OUT2 - r x m reduced input matrix; if input2 is zero then OUT2 is
%          zeros(r, m)
% 

%
% This file is part of the archive Code, Data and Results for Numerical 
% Experiments in "<Paper title here>"
% Copyright (c) <YEAR> <Author names>
% All rights reserved.
% License: BSD 2-Clause license (see COPYING)
%
% Last editied: M/D/YYYY
%
```

Key rules for the header:
- The function name on the `%FUNCTION_NAME` line is **all caps**.
- Input and output descriptions are **right-aligned** so that the `-` dashes
  line up with the longest parameter name.
- Multi-line descriptions for a single parameter are indented to align with
  the text of the first line (not the `-`).
- There is a **blank `%` line** between the OUTPUTS block and the closing `% `.
- The copyright/license block is separated from the OUTPUTS block by a blank
  line, and the block itself is surrounded by blank lines above and below.
- "Last editied" — preserve this exact spelling (consistent throughout).
- `runme_*.m` scripts use a simplified header: `%% RUNME_NAME` as the first
  line, a one-line description, and the copyright block only — no
  SYNTAX/INPUTS/OUTPUTS.

## Optional arguments (opts struct) — tabular format

When a function accepts an `opts` struct with optional fields, document each
field in an ASCII table inside the INPUTS block. The table immediately follows
the `opts` line. The fields below are illustrative — use whatever fields the
function actually accepts:

```matlab
%   opts - structure, containing the following optional entries:
%   +-----------------+---------------------------------------------------+
%   |    PARAMETER    |                     MEANING                       |
%   +-----------------+---------------------------------------------------+
%   | tol             | nonnegative scalar, convergence tolerance         |
%   |                 | (default 1e-6)                                    |
%   +-----------------+---------------------------------------------------+
%   | maxiter         | positive integer, maximum number of iterations    |
%   |                 | (default 100)                                     |
%   +-----------------+---------------------------------------------------+
%   | param3          | description of what param3 controls; if it has   |
%   |                 | multiple lines of description they go here        |
%   |                 | (default <value>)                                 |
%   +-----------------+---------------------------------------------------+
```

Rules for the table:
- Left column is 17 characters wide (including the `|` borders and padding).
- Right column is 51 characters wide (including the `|` borders and padding).
- Continuation lines in the right column: `|` + 16 spaces + `|` + text.
- Default values go on their own continuation line as `(default <value>)`.
- Output `info` structs use the identical table format in the OUTPUTS block.

## Section separators

Major sections within a function body use a bordered box comment, preceded
by a `%%` line for MATLAB cell folding:

```matlab
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SECTION TITLE IN ALL CAPS.                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```

The box is always 76 characters wide (including the leading `%`). Use these
for: `CHECK INPUTS.`, `SOLVE LYAPUNOV EQUATIONS.`, `COMPUTE BALANCED REALIZATION.`,
`BUILD REDUCED-ORDER MODEL.`, `EVALUATE METRICS.`, `COLLECT SNAPSHOTS.`, etc.

Minor inline comments use a plain `%` on the same line or immediately above.
Describe *why*, not *what*: `% Rayleigh damping coefficients.` not
`% extract alpha and beta`.

## Variable naming

**System matrices:** `A`, `B`, `C`, `D` for the full-order LTI system.
Reduced-order matrices: `Ar`, `Br`, `Cr`. Projection bases: `Vr` (right),
`Wr` (left). Gramians: `P` (controllability), `Q` (observability).
Hankel singular values: `sigma`.

**Error system:** `Ae`, `Be`, `Ce` when forming `G - Gr` explicitly.

**Dimensions:** `n` (full state), `r` (reduced order), `p` (number of
outputs), `m` (number of inputs).

**Loop indices:** `i`, `j`, `k` for tight math loops; `ir` for loops over
reduced orders; `it` for iteration counters. Never bare single-letter indices
outside tight math blocks.

**Temporaries:** `tmp`, `tmpL`, `tmpR` for intermediate matrix expressions.
Identity matrices: `In`, `Ir` (sized by subscript).

**Boolean flags in scripts:** full descriptive names —
`recomputeROM`, `plotResponse`, `saveResults`. Place them at the top of the
relevant script section with a commented-out alternate value beneath.

**camelCase** for all multi-word variable names.

**snake_case** for all function and script file names (e.g. `solve_lyapunov.m`,
`hinf_norm.m`), except `runme_*.m` scripts which follow the `runme_` prefix
convention.

## Logging and timing

```matlab
fprintf(1, 'BUILDING LOEWNER MATRICES (myAlgorithm).\n')
fprintf(1, '-----------------------------------------\n')
timeLoewner = tic;

% ... computation ...

fprintf(1, 'CONSTRUCTION FINISHED IN %.2f s\n', toc(timeLoewner))
fprintf(1, '-------------------------------\n')
```

- Always `fprintf(1, ...)` — never `disp` or bare `fprintf`.
- Section-start and section-end messages are paired, with a separator line of
  dashes matching the width of the message text.
- Timing: assign `tic` to a named variable (`timeLoewner = tic`), report with
  `toc(timeLoewner)` and format `%.2f s`.
- Iteration counters: `fprintf(1, 'IRKA: iter %d of %d.\n', it, maxiter)`.
- Numerical errors/residuals: `%.4e` format.

## Script structure (`runme_*.m`)

```matlab
%% RUNME_FOO
% One-line description.
%
% <copyright block>

clc;
clear all;
close all;

% Get and set all paths.
[rootpath, filename, ~] = fileparts(mfilename('fullpath'));
loadname = [rootpath filesep() 'data'    filesep() filename];
savename = [rootpath filesep() 'results' filesep() filename];

addpath([rootpath, '/drivers'])

% Write .log file.
if exist([savename '.log'], 'file') == 2
    delete([savename '.log']);
end
outname = [savename '.log']';
diary(outname)
diary on;

fprintf(1, ['SCRIPT: ' upper(filename) '\n']);
fprintf(1, ['========' repmat('=', 1, length(filename)) '\n']);
fprintf(1, '\n');
```

Always start `runme_*.m` scripts with `clc; clear all; close all;`, the
path/diary boilerplate above, and the script-name banner. Results go in
`results/`, log files alongside them.

## Math and linear algebra

**Linear solves:** backslash operator. Always group the solve expression
clearly with parentheses even when not strictly required:

```matlab
X = (A - s*eye(n)) \ B;
```

**Powers:** `s^2`, not `s.^2`, for scalar variables.

**Imaginary unit:** always `1i`, never `i` or `1j`.

**Block indexing:** `((k - 1)*p + 1:k*p, :)` — spaces around `-` and `+`,
no spaces inside the colon range.

**Norms:** `norm(X, 'fro')` for Frobenius; `norm(X, 2)` for spectral;
`max(svd(X))` when the spectral norm needs an explicit SVD.

**Pre-allocation before loops:**

```matlab
hinfErr = zeros(length(rVals), nMethods);
snapshots = zeros(n, nSteps);
```

**Scalar pre-computation:** pull loop-invariant scalars into temporaries
before applying to matrix blocks:

```matlab
tmpScale = norm(yFull, 2);
relErr   = norm(yFull - yRed, 2) / tmpScale;
```

**Complex conjugate pairs:** `conj(flipud(nodes))` — explicit, never implicit.

## Assertions

Use `assert` with a descriptive string at function entry for argument checks:

```matlab
assert(r < n, 'Reduced order r must be strictly less than full order n.')
assert(size(A, 1) == size(A, 2), 'A must be square.')
```

No other input validation. No try/catch.

## Good example — function body

```matlab
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHECK INPUTS.                                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[n, m] = size(B);   p = size(C, 1);

assert(r < n, 'Reduced order r must be strictly less than full order n.')
assert(size(A, 1) == size(A, 2), 'A must be square.')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SOLVE LYAPUNOV EQUATIONS.                                               %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fprintf(1, 'BT: solving controllability Lyapunov equation.\n')
fprintf(1, '-----------------------------------------------\n')
timeP = tic;
P = solve_lyapunov(A, B*B');
fprintf(1, 'BT: P solved in %.2f s\n', toc(timeP))

fprintf(1, 'BT: solving observability Lyapunov equation.\n')
fprintf(1, '--------------------------------------------\n')
timeQ = tic;
Q = solve_lyapunov(A', C'*C);
fprintf(1, 'BT: Q solved in %.2f s\n', toc(timeQ))

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMPUTE BALANCED REALIZATION.                                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Lp = chol(P, 'lower');
Lq = chol(Q, 'lower');

[U, S, V] = svd(Lp' * Lq, 'econ');
sigma      = diag(S);

Vr = Lp * U(:, 1:r) * diag(sigma(1:r).^(-1/2));
Wr = Lq * V(:, 1:r) * diag(sigma(1:r).^(-1/2));

Ar = Wr' * A * Vr;
Br = Wr' * B;
Cr = C   * Vr;

fprintf(1, 'BT: r=%d done, leading HSV ratio = %.4e\n', r, sigma(r)/sigma(1))
```

Why it's good: named timers, paired log messages with matching separator
widths, explicit SVD truncation with standard variable names, no toolbox calls,
pre-checked inputs with descriptive assert strings.

## Bad example — do not write code like this

```matlab
function ROM = reduceModel(sys, r)
    try
        [~, ~, ~, ~] = balreal(sys);   % uses Control Toolbox
        ROM = balred(sys, r);
    catch e
        warning('balred failed: %s', e.message);
        ROM = sys;
    end
end
```

Why it's bad: calls toolbox functions (`balreal`, `balred`), uses try/catch
for robustness, silent fallback hides failure, no logging, no pre-allocation,
no section structure.
