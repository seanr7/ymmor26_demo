import jax
import jax.numpy as jnp
import flax.linen as nn

_ACTS = {"tanh": nn.tanh, "relu": nn.relu, "gelu": nn.gelu, "silu": nn.silu}


class MLP(nn.Module):
    width: int
    depth: int
    out_dim: int
    act: str = "tanh"

    @nn.compact
    def __call__(self, x):
        act = _ACTS[self.act]
        for _ in range(self.depth):
            x = nn.Dense(self.width)(x)
            x = act(x)
        return nn.Dense(self.out_dim)(x)


def build_model(D, width=256, depth=4, act="tanh"):
    return MLP(width=width, depth=depth, out_dim=D, act=act)


def init_model(model, rng_key, D):
    dummy = jnp.zeros((1, D))
    params = model.init(rng_key, dummy)
    n = sum(x.size for x in jax.tree.leaves(params))
    print(f"model: width={model.width} depth={model.depth} act={model.act} params={n:,}")
    return params
