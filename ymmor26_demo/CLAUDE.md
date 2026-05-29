# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Worktree & Branching Workflow (default)

Unless I say otherwise, follow this for every code-changing task. This is a solo repo with no CI/CD; pushes to the remote are just backups. All review and merging happens locally.

### 1. Start in a new worktree on a new branch

- Never edit directly on `main`. Check with `git branch --show-current` first.
- Create a worktree inside `.worktrees/` with a new branch:
```
git worktree add .worktrees/<short-desc> -b claude/<short-desc> main
```
- `cd` into it and work there. One task = one worktree = one branch.
- After creating the worktree, print its path so I can find it in the VS Code explorer under `.worktrees/`.

### 2. Work and self-review

- Commit in small, focused chunks with clear messages.
- Before declaring done, run the project's tests/linters. If unclear what those are, ask.
- Then summarize for me: branch name, worktree path, `git log main..HEAD --oneline`, and `git diff main --stat`. Wait for my approval before merging.

### 3. Merge locally, then push for backup

- From the main repo directory (not the worktree):
```
git checkout main
git merge --no-ff claude/<short-desc>
git push origin main
```
- Then clean up:
```
git worktree remove .worktrees/<short-desc>
git branch -d claude/<short-desc>
```
- No PRs, no tags, no other remote actions.

### 4. Parallel tasks

If I start a second task while another worktree is still open, create a fresh worktree for it rather than reusing one.

### 5. Escape hatches

- If I say "stay on this branch", "work in place", or "quick fix", skip the worktree step.
- If the workflow is blocked (dirty `main`, worktree path exists, branch name taken), stop and tell me before improvising.

## This Project

Compare three canonical model order reduction (MOR) algorithms — Balanced Truncation (BT), Iterative Rational Krylov Algorithm (IRKA), and Proper Orthogonal Decomposition (POD) — applied to a standard LTI benchmark. The deliverable is a suite of error and timing metrics as a function of the reduced order `r`, organized into one figure per metric.

## Benchmark System

The ISS 1412 benchmark (International Space Station structural model): 1412 states, 3 inputs, 3 outputs. Data is loaded from `ymmor26_demo/iss12a.mat`, which contains the matrices `A`, `B`, `C` (and `D` if present) defining the continuous-time LTI system.

## Algorithms

All three algorithms are implemented from scratch with no assumed toolboxes:

- **BT (Balanced Truncation):** solve the controllability and observability Gramians via Lyapunov equations, compute the balanced realization via SVD, truncate to order `r`.
- **IRKA (Iterative Rational Krylov Algorithm):** iteratively update interpolation points until convergence; build projection matrices via rational Krylov subspaces.
- **POD (Proper Orthogonal Decomposition):** collect state snapshots from impulse response simulations, compute SVD, project onto leading `r` modes.

## Experimental Axes

- **Reduced order** `r = [5, 10, 20, 40, 80]`: the primary experimental axis. All metrics are reported as curves over `r`, with BT, IRKA, and POD as separate series.
- **Input signal**: a meaningful set covering qualitatively different regimes — impulse, step, and random (white noise, fixed seed). Used as a secondary axis for time-domain output error.

## Metrics and Deliverables

Five metrics, one figure each. Each figure shows all three methods as curves over `r`:

1. **Timing** — wall-clock time to compute the ROM (excludes simulation time).
2. **H∞ error** — `‖G - G_r‖_∞`, implemented via bisection on the Hamiltonian eigenvalue test.
3. **H2 error** — `‖G - G_r‖_2`, computed from the error system Gramians.
4. **Transfer function error** — `‖G(iω) - G_r(iω)‖` evaluated over a logarithmically spaced frequency grid; plot the frequency-averaged or peak relative error.
5. **Output error in time** — relative L2 error between full and reduced output trajectories, one subplot per input signal.

## Stack

- MATLAB (no toolboxes assumed unless explicitly stated; implement all linear algebra and norm computations from scratch)

## File and Directory Layout

- One function per file. File name matches the function name exactly
  (lowercase, underscores for multi-word names: `solve_lyapunov.m`).
- `drivers/` — all core algorithm implementations (`bt.m`, `irka.m`,
  `pod.m`) and helper functions (Lyapunov solvers, norm computations,
  simulation utilities).
- `runme_*.m` — orchestration scripts at the repo root; no algorithm logic.
- `results/` — all outputs: `.mat`, `.dat`, `.log`, `.pdf`, `.eps`, etc.
- `iss12a.mat` — benchmark data; load directly from the repo root.

## Code Style

- **One file per algorithm.** Each MOR method lives in its own `.m` file (`bt.m`, `irka.m`, `pod.m`) and returns the reduced system matrices. Helper routines (Lyapunov solvers, norm computations, simulation utilities) each get their own file.
- **Orchestration is separate.** `RUNME.m` loads the benchmark, loops over `r` and methods, collects results, and calls plotting functions. It does not contain algorithm logic.
- **Functions, not scripts.** Every `.m` file defines a function with explicit inputs and outputs. No bare scripts except `RUN.m`.
- **No assumed toolboxes.** Do not call `lyap`, `norm(sys, ...)`, `lsim`, `balreal`, `balred`, or any Control/Robust Control Toolbox function unless explicitly told it is available. Implement equivalents from first principles.
- **No defensive coding.** No input validation, no try/catch. `assert` for shape checks is fine.
- **Logging is `fprintf`.** Lowercase, one line, progress-oriented. E.g. `fprintf('bt: r=%d done\n', r)`.
- **Standard names:** `A`, `B`, `C`, `D` for system matrices; `Vr`, `Wr` for projection bases; `Ar`, `Br`, `Cr` for reduced matrices; `r` for reduced order; `sigma` for Hankel singular values.

## Plotting

- One figure per metric, saved to `ymmor26_demo/results/`.
- Each figure: all three methods as labeled curves over `r`; explicit axis labels, title, and legend.
- For output error in time: one subplot per input signal (impulse, step, random).
- No `jet` colormap. Use `lines` (MATLAB default) for multi-series line plots.
- Print the saved path after each figure.
