import jax
import jax.numpy as jnp
import optax
from flax.training import train_state


def loss_fn(params, batch, apply_fn):
    xs, targets = batch
    preds = apply_fn({"params": params}, xs)
    return jnp.mean((preds - targets) ** 2)


@jax.jit
def train_step(state, batch):
    loss, grads = jax.value_and_grad(loss_fn)(state.params, batch, state.apply_fn)
    state = state.apply_gradients(grads=grads)
    return state, loss


def make_state(model, params, lr):
    tx = optax.adam(lr)
    return train_state.TrainState.create(apply_fn=model.apply, params=params, tx=tx)


def train(model, params, xs, targets, lr=1e-3, n_steps=20_000, batch_size=1024, rng_key=None):
    """Train model on normalized (xs, targets) pairs.

    Args:
        model:      Flax module
        params:     initialized params from init_model
        xs:         (M, D) normalized inputs
        targets:    (M, D) normalized residuals
        lr:         Adam learning rate
        n_steps:    number of gradient steps
        batch_size: mini-batch size (full-batch if >= M)
        rng_key:    JAX PRNGKey for batch sampling

    Returns:
        trained params
    """
    if rng_key is None:
        rng_key = jax.random.PRNGKey(0)

    state = make_state(model, params, lr)
    M = xs.shape[0]
    use_full = batch_size >= M

    for step in range(n_steps):
        if use_full:
            batch = (xs, targets)
        else:
            rng_key, sk = jax.random.split(rng_key)
            idx = jax.random.randint(sk, (batch_size,), 0, M)
            batch = (xs[idx], targets[idx])

        state, loss = train_step(state, batch)

        if step % 1000 == 0:
            print(f"step {step:5d}  loss {loss:.4e}")

    print(f"done  steps={n_steps}  final loss {loss:.4e}")
    return state.params
