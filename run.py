import jax
from data import make_dataset
from train import train


D_VALUES = [8, 16, 32]
N_VALUES = [2, 8, 32, 128]

DT = 0.05
N_TRAIN_STEPS = 200
N_SPINUP = 2000


def run(D, N, rng_key):
    print(f"running D={D} N={N}")
    trajs, stats = make_dataset(rng_key, N, D, DT, N_TRAIN_STEPS, N_SPINUP)
    train(trajs, stats, cfg=None)


if __name__ == "__main__":
    rng_key = jax.random.PRNGKey(0)
    for D in D_VALUES:
        for N in N_VALUES:
            rng_key, subkey = jax.random.split(rng_key)
            run(D, N, subkey)
