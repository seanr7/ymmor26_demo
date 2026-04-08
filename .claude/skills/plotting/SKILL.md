---
name: plotting
description: Generates and saves matplotlib plots and animations for research code. Use when the user asks to plot, visualize, animate, show, or save figures, gifs, or videos — including imshow, line plots, scatter plots, vector fields, image grids, trajectory plots, and time-series animations. Prefers existing helper functions in the repo's plotting module over writing matplotlib from scratch. Covers figure sizing, label placement, colorbar handling, and gif/mp4 export.
---

# research-plotting

Apply this when generating, editing, or saving any matplotlib plot or
animation in this repo.

## First rule: use the existing plotting module

This repo has a plotting module with hand-tuned helpers. Use them
instead of writing matplotlib from scratch. Available functions:

| Function | Use for |
|---|---|
| `imshow_movie(sol, ...)` | Animate `(T, H, W)` image stacks. Handles colorbars, labels, gif/mp4 export. |
| `imshow_pts_movies(sol, pts, extent, ...)` | Image animation with overlaid scatter points. |
| `scatter_movie(pts, ...)` | Animate `(T, N, 2)` or `(G, T, N, 2)` particle trajectories. |
| `line_movie(sol, ...)` | Animate `(T, S)` or `(L, T, S)` line plots over time. |
| `trajectory_movie(y, ...)` | Animate a single 1D trajectory growing over time. |
| `vector_field_movie(vecs, ...)` | Animate `(T, N, 2)` vector fields on a grid. |
| `plot_grid(A, ...)` | Static grid of `N` images with shared/per-cell colorbars. |
| `plot_grid_movie(A, ...)` | Animated grid of `(N, T, H, W)` movies. |
| `plot_moments(true, pred, ...)` | Mean ± std bands comparing two sample sets over time. |
| `save_tensor_to_mp4(video, out_path, ...)` | Encode `(T, H, W[, C])` to H.264 mp4 with optional colormap. |

**Rules:**
- If the user's plot fits one of these functions, use it. Don't reach
  for raw `plt.subplots` + `FuncAnimation`.
- If the data has a time dimension and the user wants to "see" or
  "show" it, default to the corresponding `_movie` function and save
  as a gif. Don't make a static plot of the first frame unless asked.
- If none of these functions fit, **ask before writing a new one**.
  Don't silently add a new helper to the plotting module. Suggest the
  closest existing function and ask whether to extend it or write
  something new.
- Don't reimplement functionality that exists. If `imshow_movie`
  almost does what's needed but is missing one kwarg, ask whether to
  add the kwarg there rather than writing a parallel one-off.

## Saving conventions

- Static plots: save as `.png` via `save_to=...` (the helpers handle
  this) or `fig.savefig(path)` for ad-hoc figures.
- Animations with a time dimension: save as `.gif` by default, using
  the `save_to=` argument of the movie helpers. Use `.mp4` only when
  asked or when the gif would be huge (use `save_tensor_to_mp4` for
  long videos).
- Always save to a path under the Hydra output dir from `get_outpath()`,
  not to cwd. Example: `save_to=get_outpath() / "loss_curve.png"`.
- Print the save path on a lowercase one-line print after saving.

## Visual clarity checklist

Before returning any plotting code, check each of these. These are
the things matplotlib gets wrong by default and that ruin research
figures.

**Sizing:**
- `figsize` is set explicitly. Default to `(6, 4)` for single plots,
  `(8, 8)` for grids, `(8, 3)` for wide time-series.
- Don't make figures larger than ~`(12, 8)` unless the data demands
  it. Oversized figures hide problems and look amateurish in papers.
- For grids, let `plot_grid` infer `grid_height`/`grid_width` from
  `sqrt(N)` unless the user wants a specific shape.

**Labels and ticks:**
- Every axis has a label if the units mean something. Use `'time'`,
  `'iteration'`, `'loss'`, `'x'`, etc. Lowercase.
- Tick labels don't overlap. For dense x-axes, rotate 45° or thin
  them out with `ax.set_xticks(...)`.
- Colorbar ticks are formatted sensibly — use `cbar_tick_fmt='%.2f'`
  or similar when default scientific notation is ugly.
- Legend doesn't cover the data. Default to `loc='best'`; if it
  collides, use `loc='upper right'` or move it outside with
  `bbox_to_anchor`.

**Colors and contrast:**
- Default cmap is `'viridis'` for scalar fields. Use `'RdBu_r'` or
  `'seismic'` for signed data centered at zero (and set
  `c_norm=(-vmax, vmax)` so zero stays white).
- Don't use `'jet'`. Ever.
- Line plots: rely on the default Matplotlib color cycle (`C0`, `C1`,
  ...) unless there's a reason to override.
- Text labels overlaid on images need contrast — use `label_color=
  "white"` on dark cmaps, `"black"` on light ones.

**Layout:**
- Use `tight=True` (or `fig.tight_layout()`) to remove padding.
- For multi-panel figures, check that titles don't overlap the panel
  above. Use `fig.suptitle(..., y=0.98)` and `fig.tight_layout(rect=
  [0, 0, 1, 0.96])` if needed.
- For animations, set `interval=100` (10 fps display) and `fps=10`
  for the saved gif unless the user wants smoother.

**Colorbars:**
- Single shared colorbar (`colorbar_mode='single'`) for grids of
  related data. Per-cell (`'each'`) only when the panels have wildly
  different ranges.
- For animations, decide between `live_cbar=True` (rescales each
  frame, good for seeing structure) and a fixed `c_norm` (good for
  comparing frames). Default to fixed `c_norm` if you can compute
  `(vmin, vmax)` from the full data — it makes the animation honest.

## Good example — animating a solution field

```python
from gmfm.plot import imshow_movie  # adjust import to match repo
from gmfm.config import get_outpath

# sol: (T, H, W) array from a PDE solver
out = get_outpath() / "wave_sol.gif"
imshow_movie(
    sol,
    title="wave",
    cmap="RdBu_r",
    c_norm=(-float(sol).max(), float(sol).max()),  # symmetric, fixed
    figsize=(5, 5),
    fps=15,
    save_to=out,
    show_inline=False,
)
print(f"saved animation to {out}")
```

Why it's good: uses the existing helper, fixed symmetric color
scale, reasonable figsize, saves to the Hydra output dir, lowercase
print.

## Good example — comparing true vs predicted moments

```python
from gmfm.plot import plot_moments
from gmfm.config import get_outpath

out = get_outpath() / "moments.png"
plot_moments(
    true=true_samples,   # (n_true, T)
    pred=pred_samples,   # (n_pred, T)
    t=t,
    figsize=(6, 4),
    save_to=out,
)
print(f"saved moments plot to {out}")
```

## Good example — quick static loss curve

```python
import matplotlib.pyplot as plt
from gmfm.config import get_outpath

fig, ax = plt.subplots(figsize=(6, 3))
ax.plot(losses)
ax.set_xlabel("iteration")
ax.set_ylabel("loss")
ax.set_yscale("log")
fig.tight_layout()
out = get_outpath() / "loss.png"
fig.savefig(out, dpi=150)
plt.close(fig)
print(f"saved loss curve to {out}")
```

Why it's good: no helper exists for this so raw matplotlib is fine,
but it still has explicit figsize, axis labels, log scale where
appropriate, tight layout, explicit close, and saves to the Hydra
output dir.

## Bad example — do not write code like this

```python
# Bug 1: reinvents imshow_movie from scratch
fig, ax = plt.subplots(figsize=(15, 12))  # Bug 2: way too big
ims = []
for i in range(sol.shape[0]):
    im = ax.imshow(sol[i], cmap='jet')    # Bug 3: jet
    ims.append([im])
ani = animation.ArtistAnimation(fig, ims)
ani.save('output.gif')                    # Bug 4: cwd, not outpath
                                          # Bug 5: no fps set
                                          # Bug 6: no axis labels or title
                                          # Bug 7: no print confirming save
```

Every line of this is wrong. The whole thing should be one call to
`imshow_movie(sol, save_to=get_outpath() / "output.gif", ...)`.

## When the user asks for "a plot of X"

1. Check the shape of `X`. If it has a time dimension, the default
   answer is an animation, not a static plot.
2. Check the function table above. If something fits, use it.
3. If nothing fits, ask: "I don't see a helper for this in the
   plotting module — should I add one to `plot.py`, or write a
   one-off in this script?"
4. Apply the visual clarity checklist before returning the code.
5. Save to `get_outpath()` and print the path.