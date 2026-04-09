---
name: cs-prod
description: Enforces a defensive, heavily-engineered class driven, abstraction driven Python style for code that needs to survive contact with reality — long-running training jobs, shared library code, multi-user pipelines, anything that will be rerun by someone else months later. Use when writing or editing code where silent failures, unchecked inputs, or missing logs would cost real time. Prioritizes robustness, observability, and explicit contracts over line count or mathematical brevity. Not for one-off scripts or experiments.
disable-model-invocation: true
---

# code-style-prod

For code that has to keep working when you're not watching it.
Readability matters less than catching failures early, logging
enough to debug post-hoc, and making contracts explicit. Class driven development. 
Use abstractions where possible. Do not reference or use existing code for style.

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

  ## Additional Patterns and Examples

### Explicit Resource Lifecycle Management

Encapsulate external resources (files, sockets, GPUs) in classes with
clear ownership and teardown semantics.

class FileBackedCache:
    def __init__(self, path: str) -> None:
        self._path = path
        self._fh: Optional[IO[str]] = None

    def open(self) -> None:
        if self._fh is not None:
            raise RuntimeError("File already open")
        self._fh = open(self._path, "a+")
        logger.info("Opened cache file", extra={"path": self._path})

    def write(self, key: str, value: str) -> None:
        if self._fh is None:
            raise RuntimeError("File not open")
        self._fh.write(f"{key}:{value}\n")

    def close(self) -> None:
        if self._fh:
            self._fh.close()
            self._fh = None
            logger.info("Closed cache file", extra={"path": self._path})


### Boundary Validation via Gatekeeper Classes

Do not let raw external input propagate. Normalize immediately.

class RequestValidator:
    def __init__(self, schema: dict[str, type]) -> None:
        self._schema = schema

    def validate(self, payload: dict[str, object]) -> dict[str, object]:
        missing = [k for k in self._schema if k not in payload]
        if missing:
            raise ValueError(f"Missing keys: {missing}")
        for key, expected_type in self._schema.items():
            if not isinstance(payload[key], expected_type):
                raise TypeError(f"{key} expected {expected_type}, got {type(payload[key])}")
        return payload


### Stateful Orchestrators (Not Pipelines of Functions)

Centralize execution flow in a class that owns progress, metrics, and failure handling.

class JobRunner:
    def __init__(self, steps: list[JobStep]) -> None:
        self._steps = steps
        self._current_idx = 0

    def run(self) -> None:
        for idx, step in enumerate(self._steps):
            self._current_idx = idx
            try:
                logger.info("Running step", extra={"step": step.name})
                step.execute()
            except StepError as e:
                logger.error("Step failed", extra={"step": step.name})
                raise RuntimeError(f"Job failed at step {step.name}") from e


class JobStep(Protocol):
    name: str
    def execute(self) -> None: ...


### Strongly-Typed Config with Versioning

class TrainingConfig:
    version: Literal["v1"] = "v1"

    def __init__(self, batch_size: int, lr: float) -> None:
        if batch_size <= 0:
            raise ValueError("batch_size must be positive")
        if not (0.0 < lr < 1.0):
            raise ValueError("lr out of range")
        self.batch_size = batch_size
        self.lr = lr


### Error Translation Layers

Translate low-level errors into domain-relevant failures.

class DataLoader:
    def load(self, path: str) -> bytes:
        try:
            with open(path, "rb") as f:
                return f.read()
        except OSError as e:
            logger.error("File read failed", extra={"path": path})
            raise DataAccessError(f"Failed to read {path}") from e


class DataAccessError(Exception):
    pass


### Metrics as First-Class Objects

Avoid ad-hoc logging; encapsulate metrics with lifecycle.

class MetricTracker:
    def __init__(self) -> None:
        self._values: dict[str, float] = {}

    def record(self, name: str, value: float) -> None:
        self._values[name] = value
        logger.debug("Metric recorded", extra={"metric": name, "value": value})

    def snapshot(self) -> dict[str, float]:
        return dict(self._values)


### Dependency Injection via Constructor

No hidden globals. All dependencies are explicit.

class Trainer:
    def __init__(
        self,
        model: Model,
        optimizer: Optimizer,
        metrics: MetricTracker
    ) -> None:
        self._model = model
        self._optimizer = optimizer
        self._metrics = metrics

    def train_step(self, batch: Batch) -> None:
        loss = self._model.forward(batch)
        self._optimizer.step(loss)
        self._metrics.record("loss", loss)