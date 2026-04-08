---
name: cs-prod
description: Enforces a defensive, heavily-engineered Python style for code that needs to survive contact with reality — long-running training jobs, shared library code, multi-user pipelines, anything that will be rerun by someone else months later. Use when writing or editing code where silent failures, unchecked inputs, or missing logs would cost real time. Prioritizes robustness, observability, and explicit contracts over line count or mathematical brevity. Not for one-off scripts or experiments.
---

# code-style-prod

For code that has to keep working when you're not watching it.
Readability matters less than catching failures early, logging
enough to debug post-hoc, and making contracts explicit.

## Rules

- Type hints on every function signature and dataclass field. Use
  `from __future__ import annotations`. Reach for `Protocol`,
  `TypedDict`, `Literal`, and `Generic` when they tighten a contract.
  Run `mypy --strict` clean.
- Validate inputs at every public boundary. Check shapes, dtypes,
  ranges, key presence. Raise specific exceptions (`ShapeError`,
  `ConfigError`, ...) with messages that name the offending value.
- No bare `except`. Catch the narrowest exception that makes sense,
  log it with context, and either re-raise or convert to a domain
  exception with `raise ... from e`.
- Use the `logging` module, not `print`. Module-level
  `logger = logging.getLogger(__name__)`. Log levels matter: `DEBUG`
  for shape/step traces, `INFO` for milestones, `WARNING` for
  recoverable oddities, `ERROR` for failures. Include structured
  context (step, batch idx, shapes) in every message.
- Classes are fine and often correct. Use them to bundle state with
  the operations on it (`Trainer`, `Checkpointer`, `MetricLogger`).
  Prefer composition over inheritance, but inheritance is allowed
  when it models a real is-a.
- Separate concerns into modules: `models/`, `data/`, `training/`,
  `evaluation/`, `config/`, `utils/`. Each module has a clear public
  API in `__init__.py`. Internal helpers are `_prefixed`.
- Configs are versioned dataclasses with validation in
  `__post_init__`. Reject unknown fields. Serialize the resolved
  config alongside every run artifact.
- Checkpoint everything: model params, optimizer state, RNG state,
  step counter, config hash. Make runs resumable. Assume the job
  will be preempted.
- Tests for anything non-trivial. Unit tests for pure functions,
  integration tests for train_step on a toy batch, regression tests
  with golden values for loss functions. Use `pytest` with fixtures.
- Document public functions with full docstrings: summary, `Args`,
  `Returns`, `Raises`, and a usage example for anything non-obvious.
  Google or NumPy style, pick one and stick to it.
- Pin dependencies. Use `pyproject.toml` with exact versions or
  compatible-release specifiers. Lock with `uv` or `pip-tools`.
- No magic numbers in function bodies. Hoist them to named constants
  or config fields with a comment explaining the choice.

## Good example

```python
from __future__ import annotations

import logging
from dataclasses import dataclass

import jax
import jax.numpy as jnp
from flax.training.train_state import TrainState

logger = logging.getLogger(__name__)


class ShapeError(ValueError):
    """Raised when an array has an unexpected shape."""


@dataclass(frozen=True)
class LossConfig:
    reduction: Literal["mean", "sum"] = "mean"
    label_smoothing: float = 0.0

    def __post_init__(self) -> None:
        if not 0.0 <= self.label_smoothing < 1.0:
            raise ConfigError(
                f"label_smoothing must be in [0, 1), got {self.label_smoothing}"
            )


def cross_entropy_loss(
    logits: jax.Array,
    labels: jax.Array,
    cfg: LossConfig,
) -> jax.Array:
    """Compute cross-entropy loss with optional label smoothing.

    Args:
        logits: Unnormalized predictions, shape ``(B, C)``.
        labels: Integer class labels, shape ``(B,)``, values in ``[0, C)``.
        cfg: Loss configuration.

    Returns:
        Scalar loss array.

    Raises:
        ShapeError: If ``logits`` and ``labels`` have incompatible shapes.
    """
    if logits.ndim != 2:
        raise ShapeError(f"logits must be 2D, got shape {logits.shape}")
    if labels.shape != (logits.shape[0],):
        raise ShapeError(
            f"labels shape {labels.shape} incompatible with logits {logits.shape}"
        )

    num_classes = logits.shape[-1]
    targets = jax.nn.one_hot(labels, num_classes)
    if cfg.label_smoothing > 0.0:
        targets = targets * (1.0 - cfg.label_smoothing) + (
            cfg.label_smoothing / num_classes
        )

    log_probs = jax.nn.log_softmax(logits, axis=-1)
    per_example = -jnp.sum(targets * log_probs, axis=-1)

    if cfg.reduction == "mean":
        return jnp.mean(per_example)
    return jnp.sum(per_example)


def train_step(
    state: TrainState,
    batch: dict[str, jax.Array],
    cfg: LossConfig,
    step: int,
) -> tuple[TrainState, dict[str, float]]:
    """Single optimization step. Logs metrics, validates batch keys."""
    required = {"inputs", "labels"}
    missing = required - batch.keys()
    if missing:
        raise KeyError(f"batch missing required keys: {missing}")

    def loss_fn(params: dict) -> jax.Array:
        logits = state.apply_fn(params, batch["inputs"])
        return cross_entropy_loss(logits, batch["labels"], cfg)

    loss, grads = jax.value_and_grad(loss_fn)(state.params)
    grad_norm = jnp.sqrt(sum(jnp.sum(g**2) for g in jax.tree.leaves(grads)))

    if not jnp.isfinite(loss):
        logger.error("non-finite loss at step %d: %s", step, float(loss))
        raise RuntimeError(f"non-finite loss at step {step}")

    new_state = state.apply_gradients(grads=grads)
    metrics = {"loss": float(loss), "grad_norm": float(grad_norm)}
    logger.debug("step %d  loss %.5f  grad_norm %.5f", step, *metrics.values())
    return new_state, metrics
```

Why it's good: every input is checked, every failure mode is named,
every value that could explode is logged with context, the loss
function has a docstring future-you can actually read, and the
config rejects bad values at construction time instead of producing
NaNs three hours into training.

## Bad example

```python
def step(p, b):
    g = grad(loss)(p, b)
    return [pi - 1e-3 * gi for pi, gi in zip(p, g)]

for i in range(10000):
    p = step(p, next(it))
    if i % 500 == 0: print(loss(p, b))
```

Why it's bad in this context: no types, no validation, no logging
infrastructure, no checkpointing, no config, hardcoded LR, silently
trains through NaNs, can't be resumed, can't be debugged from logs
alone, can't be tested. Fine for a notebook, unacceptable for code
that runs unattended. If you want this style, use `code-style-raw`.

## When to reach for this skill vs the others

- `code-style-raw`: one file, one idea, you're the only reader, the
  run finishes in minutes.
- `code-style`: personal research code, multiple files, Hydra
  configs, you'll rerun it for weeks but you're still the only user.
- `code-style-prod`: shared code, long jobs, anything where a silent
  failure costs more than rewriting the file would.
