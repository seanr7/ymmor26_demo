---
name: code-walk
description: This skill should be used when the user asks to explain, walk through, or understand a piece of code or a codebase. Triggers on phrases like "explain this", "walk me through", "how does this work", "what does this do", "help me understand", or when the user pastes code without a specific edit request. Optimized for academic and research code — prioritizes mathematical intuition, design intent, and data/shape flow over surface-level line-by-line narration.
---

# code-walkthrough

Produce explanations that build genuine understanding, not just
surface narration. The audience is a researcher or technically
sophisticated reader who can follow math and wants to know *why*,
not just *what*.

## Core philosophy

The goal is to transfer a working mental model, not to describe
syntax. A good walkthrough lets the reader close the file and
correctly predict what would happen if they changed something.

Three layers every explanation must hit:

1. **Intent** — what problem is this solving and why this approach?
2. **Mechanics** — how does it actually work, concretely?
3. **Gotchas** — what's non-obvious, fragile, or easy to misread?

Never do pure line-by-line narration. That's just reading the code
aloud. Narration without insight adds noise.

## Structure

Start with the big picture before touching any code. The reader
needs a map before they can follow a route.

### 1. One-sentence purpose

Lead with what this code *does*, stated plainly. Not what it *is*
(a function, a class, a module) — what it *accomplishes*.

### 2. Mathematical or conceptual framing

Before showing code, state the underlying idea in math or plain
English. If the code implements an algorithm, write out the key
equation or recurrence first. If it's a data transformation, describe
the mapping. The code should feel like a *translation* of something
the reader already understands, not the first thing they encounter.

Example structure:
```
This implements Balanced Truncation, which reduces an n-state LTI
system G(s) = C(sI − A)^{-1}B to order r by:

  1. Solving the controllability and observability Gramians P, Q
     from  AP + PA' + BB' = 0  and  A'Q + QA + C'C = 0.
  2. Computing the Hankel singular values σ_i = sqrt(λ_i(PQ)).
  3. Projecting onto the r-dimensional balanced subspace via Vr, Wr.

The truncation error is bounded:  ‖G − G_r‖_∞ ≤ 2 Σ_{i=r+1}^n σ_i.
The code below solves the two Lyapunov equations, forms the
balanced bases, and assembles Ar, Br, Cr.
```

### 3. ASCII diagram (when structure or flow is non-trivial)

Use ASCII art to show:
- Data flow (shapes through a pipeline)
- Execution order (especially when it's non-linear or parallel)
- Object relationships (e.g. what calls what, what owns what)
- Tensor shapes at key stages

Keep diagrams tight. Label shapes explicitly — `(B, T, D)` not
"batch of sequences". Show transformations between stages.

Example:
```
A (n×n), B (n×m), C (p×n)
        │
  solve_lyapunov(A, B*B')  →  P (n×n)
  solve_lyapunov(A', C'*C) →  Q (n×n)
        │
  svd(chol(P)' * chol(Q))  →  U, S, V
  sigma = diag(S)           →  Hankel singular values (n×1)
        │
  Vr = Lp * U(:,1:r) * diag(sigma(1:r).^(-1/2))   (n×r)
  Wr = Lq * V(:,1:r) * diag(sigma(1:r).^(-1/2))   (n×r)
        │
  Ar = Wr'*A*Vr  (r×r)
  Br = Wr'*B     (r×m)
  Cr = C*Vr      (p×r)
```

### 4. Walk through the code in logical units

Group lines into meaningful chunks — not one comment per line.
Each chunk should correspond to a step in the conceptual story.
Name the chunks. For each:

- State what's happening and why (not just what)
- Call out any non-obvious choices or constraints
- If a shape changes, say so: `# (B, T, D) → (B, T, 1)`

Prefer annotated code blocks over prose when the code is short
enough to show inline:

```matlab
% Cholesky factors of the Gramians — needed for numerically stable SVD.
% Direct svd(P*Q) would lose half the precision on ill-conditioned systems.
Lp = chol(P, 'lower');   % n×n lower-triangular
Lq = chol(Q, 'lower');   % n×n lower-triangular

% Cross-Gramian product in the Cholesky factor space.
% Singular values of Lp'*Lq equal the Hankel singular values of G.
[U, S, V] = svd(Lp' * Lq, 'econ');
sigma = diag(S);          % n×1, σ_i in decreasing order

% Build biorthogonal projection bases scaled so Wr'*Vr = Ir.
Vr = Lp * U(:, 1:r) * diag(sigma(1:r).^(-1/2));   % n×r
Wr = Lq * V(:, 1:r) * diag(sigma(1:r).^(-1/2));   % n×r
```

### 5. Highlight one or two key design decisions

Pick the choices that matter most — things the reader might
question, might want to change, or might stumble on later:

- Why this parameterization over alternatives?
- Why this numerical trick?
- What invariant does this code rely on that isn't stated?
- What would break first if you scaled this up?

These should be labeled clearly:

> **Design choice:** The SVD is taken on `Lp' * Lq` rather than `P * Q`
> directly. Both share the same singular values, but the Cholesky-factor
> form is far better conditioned: squaring the condition number of `P`
> (implicit in `P*Q`) loses up to half the significant digits on
> large-scale systems.

### 6. Gotcha / non-obvious behavior

End each major section (or the whole walkthrough for short code)
with what's most likely to bite the reader:

- Silent shape broadcasting that masks bugs
- An assumption baked into the math that the code doesn't check
- A performance trap that's invisible until scale
- Behavior that differs from what the name implies

## Calibrate to scope

**Single function:** lead with purpose + math, annotate the body,
one gotcha. Skip the diagram unless data flow is complex.

**Module or file:** overview diagram first, then walk each
component in dependency order (leaves before roots). Call out the
public interface explicitly.

**Whole codebase:** start with the execution entry point and the
main data structures. Describe the "spine" — the critical path
from input to output. Don't try to cover everything; map the
territory and let the reader explore.

## Tone and style

- Write as a knowledgeable colleague explaining at a whiteboard,
  not as documentation.
- Use math when it's cleaner than prose. Don't shy away from
  notation — the reader can handle it.
- Be direct about what's good, fragile, or surprising.
  "This is a standard trick for..." and "This will silently
  misbehave if..." are both useful.
- Skip hedging and filler. No "essentially", "basically", or
  "as you can see".
- Match the depth to the question. "What does this do?" gets a
  paragraph. "Walk me through everything" gets the full structure.

## What not to do

- Don't restate the code in English word-for-word.
- Don't explain language features the reader obviously knows
  (backslash solves, colon indexing, `end`, etc.).
- Don't add false confidence — if a design choice is unclear or
  looks like it might be a bug, say so.
- Don't pad with background the reader didn't ask for.
- Don't skip the math to seem more accessible. The math is
  the point.
