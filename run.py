import jax
from data import make_dataset, make_pairs
from model import build_model, init_model
from train import train


D_VALUES = [8, 16, 32]
N_VALUES = [2, 8, 32, 128]

DT = 0.05
N_TRAIN_STEPS = 200
N_SPINUP = 2000

WIDTH = 256
DEPTH = 4
LR = 1e-3
N_STEPS = 20_000
BATCH_SIZE = 1024


def run(D, N, rng_key):
    print(f"\n--- D={D} N={N} ---")
    rng_key, dk, mk = jax.random.split(rng_key, 3)

    trajs, stats = make_dataset(dk, N, D, DT, N_TRAIN_STEPS, N_SPINUP)
    xs, targets = make_pairs(trajs, stats)

    model = build_model(D, width=WIDTH, depth=DEPTH)
    params = init_model(model, mk, D)

    params = train(model, params, xs, targets, lr=LR, n_steps=N_STEPS, batch_size=BATCH_SIZE, rng_key=rng_key)
    return params, stats


if __name__ == "__main__":
    rng_key = jax.random.PRNGKey(0)
    for D in D_VALUES:
        for N in N_VALUES:
            rng_key, sk = jax.random.split(rng_key)
            run(D, N, sk)
