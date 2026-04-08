---
name: cs-raw
description: Enforces a maximally minimal, math-first style for raw prototype scripts where a single idea is being implemented standalone. Use when writing or editing throwaway research scripts, single-file experiments, algorithm sketches, or "does this idea even work" code in JAX/NumPy/PyTorch. Optimizes for mathematical clarity and minimum line count over any engineering concern. Not for code that will be reused, configured, or run more than a handful of times.
---

# code-style-raw

For single-file prototypes implementing one idea. The goal is that a
reader can see the math at a glance. Engineering is actively
discouraged.

## Rules

- One file. No package structure, no imports from sibling files.
- Functions only. No classes except `flax.nn.Module` (or torch
  equivalent) when unavoidable.
- No config system. Hyperparameters are module-level constants in
  ALL_CAPS at the top of the file. No argparse, no Hydra, no dicts.
- No type hints. None. Not even on dataclass fields (there are no
  dataclasses).
- No docstrings. A one-line `#` comment above a function is fine if
  the math isn't obvious from the body.
- No defensive code. No validation, no try/except, no `if x is None`
  guards. Let it crash.
- No logging framework. `print(f"step {i}  loss {loss:.4f}")` and
  nothing else.
- No abstractions for reuse. Inline things. Duplicate two lines
  rather than make a helper. Only extract a function when the same
  block appears 3+ times *and* naming it actually clarifies the math.
- No CLI, no `if __name__ == "__main__"` ceremony unless the file is
  meant to be importable (it isn't). Top-level code is fine.
- Variable names match the math. `x`, `y`, `z`, `mu`, `sigma`, `t`,
  `eps`, `K`, `N` are all good. Match the paper's notation when
  implementing a paper.
- Keep `loss_fn` and `step` to a handful of lines each. If they grow,
  the abstraction is wrong, not the line count.

## Good example

```python
import jax, jax.numpy as jnp
from jax import grad, jit, random

N = 512
LR = 1e-3
STEPS = 5000
SIGMA = 0.1

def model(params, x):
    W1, b1, W2, b2 = params
    h = jnp.tanh(x @ W1 + b1)
    return h @ W2 + b2

def loss(params, x, y):
    return jnp.mean((model(params, x) - y) ** 2)

key = random.PRNGKey(0)
k1, k2, k3 = random.split(key, 3)
x = random.normal(k1, (N, 1))
y = jnp.sin(3 * x) + SIGMA * random.normal(k2, (N, 1))

params = [
    random.normal(k3, (1, 64)) * 0.1, jnp.zeros(64),
    random.normal(k3, (64, 1)) * 0.1, jnp.zeros(1),
]

@jit
def step(params, x, y):
    g = grad(loss)(params, x, y)
    return [p - LR * gi for p, gi in zip(params, g)]

for i in range(STEPS):
    params = step(params, x, y)
    if i % 500 == 0:
        print(f"step {i}  loss {loss(params, x, y):.5f}")

print(f"final {loss(params, x, y):.5f}")
```

Why it's good: constants at top, no config object, no train_state
wrapper, params is just a list, the math is the code.

## Bad example

Anything with: a `Trainer` class, a `Config` dataclass, argparse,
typing imports, `Optional`, `logging.getLogger`, helper functions
called once, separate files for "model" and "data", or
`assert isinstance(...)` checks. If you're reaching for any of those,
you want the `code-style` skill instead.
