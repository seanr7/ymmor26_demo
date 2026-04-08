import jax
import jax.numpy as jnp


# ---------------------------------------------------------------------------
# Lorenz-96 vector field
# ---------------------------------------------------------------------------

def lorenz96(x, F=8.0):
    """dx/dt for Lorenz-96: (x_{i+1} - x_{i-2}) * x_{i-1} - x_i + F."""
    xm1 = jnp.roll(x, 1)   # x_{i-1}
    xm2 = jnp.roll(x, 2)   # x_{i-2}
    xp1 = jnp.roll(x, -1)  # x_{i+1}
    return (xp1 - xm2) * xm1 - x + F


# ---------------------------------------------------------------------------
# RK4 integrator
# ---------------------------------------------------------------------------

def rk4_step(x, dt, F=8.0):
    """Single RK4 step for Lorenz-96."""
    k1 = lorenz96(x, F)
    k2 = lorenz96(x + 0.5 * dt * k1, F)
    k3 = lorenz96(x + 0.5 * dt * k2, F)
    k4 = lorenz96(x + dt * k3, F)
    return x + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4)


def integrate(x0, dt, n_steps, F=8.0):
    """Integrate Lorenz-96 from x0 for n_steps steps, returning full trajectory.

    Returns array of shape (n_steps+1, D).
    """
    def body(x, _):
        x_next = rk4_step(x, dt, F)
        return x_next, x_next

    _, traj = jax.lax.scan(body, x0, None, length=n_steps)
    return jnp.concatenate([x0[None], traj], axis=0)  # (n_steps+1, D)


# ---------------------------------------------------------------------------
# Attractor sampling via spin-up
# ---------------------------------------------------------------------------

def spinup(x0, dt, n_steps, F=8.0):
    """Advance x0 forward n_steps steps; return final state only."""
    def body(x, _):
        return rk4_step(x, dt, F), None

    x_final, _ = jax.lax.scan(body, x0, None, length=n_steps)
    return x_final


def sample_ics(rng_key, N, D, dt, n_spinup, F=8.0):
    """Sample N initial conditions from the Lorenz-96 attractor.

    Starts from a single random IC, spins up to reach the attractor,
    then collects N ICs spaced evenly along a long continuation run.
    """
    x0 = jax.random.normal(rng_key, (D,))
    x_warm = spinup(x0, dt, n_spinup, F)

    # collect N ICs spaced n_spinup apart along a continuation trajectory
    def body(x, _):
        x_next = spinup(x, dt, n_spinup, F)
        return x_next, x_next

    _, ics = jax.lax.scan(body, x_warm, None, length=N)
    return ics  # (N, D)


# ---------------------------------------------------------------------------
# Dataset generation
# ---------------------------------------------------------------------------

def make_dataset(rng_key, N, D, dt, n_train_steps, n_spinup, F=8.0):
    """Generate N training trajectories of Lorenz-96.

    Args:
        rng_key:       JAX PRNGKey
        N:             number of trajectories
        D:             spatial dimension
        dt:            integration timestep
        n_train_steps: number of steps per trajectory (controls T_train = dt * n_train_steps)
        n_spinup:      steps used to spin up / space ICs on the attractor
        F:             forcing constant (default 8.0, chaotic regime)

    Returns:
        trajs: array of shape (N, n_train_steps+1, D)
        stats: dict with keys 'mean' and 'std', each shape (D,), computed
               from all trajectory data (used for input/target normalization)
    """
    ics = sample_ics(rng_key, N, D, dt, n_spinup, F)  # (N, D)

    integrate_batch = jax.vmap(lambda x0: integrate(x0, dt, n_train_steps, F))
    trajs = integrate_batch(ics)  # (N, n_train_steps+1, D)

    mean = trajs.mean(axis=(0, 1))       # (D,)
    std = trajs.std(axis=(0, 1)) + 1e-6  # (D,)
    stats = {"mean": mean, "std": std}

    print(
        f"dataset: N={N}, D={D}, steps={n_train_steps}, traj shape={trajs.shape}")
    return trajs, stats


# ---------------------------------------------------------------------------
# One-step pairs for training
# ---------------------------------------------------------------------------

def make_pairs(trajs, stats):
    """Extract normalized (x_t, dx_t) pairs from trajectories.

    Args:
        trajs: (N, T+1, D)
        stats: dict with 'mean' and 'std', each (D,)

    Returns:
        xs:      (N*T, D)  normalized inputs
        targets: (N*T, D)  normalized residuals  (x_{t+1} - x_t) / std
    """
    mean, std = stats["mean"], stats["std"]
    xs = (trajs[:, :-1, :] - mean) / std   # (N, T, D)
    x_next = (trajs[:, 1:, :] - mean) / std   # (N, T, D)
    targets = x_next - xs                        # normalized residual

    N, T, D = xs.shape
    return xs.reshape(N * T, D), targets.reshape(N * T, D)
