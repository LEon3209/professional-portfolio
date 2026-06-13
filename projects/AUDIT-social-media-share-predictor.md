# QA Audit — Social Media Share Predictor

**Page:** `projects/social-media-share-predictor.html`
**Date:** 2026-06-13
**Method:** Served the portfolio locally (Python http server on :8080), loaded the page in a headless browser, checked console, network, every asset, responsive layout (mobile/tablet/desktop), heading structure, and read the full rendered notebook for analytical correctness.

---

## Verdict

The page **runs cleanly** — zero console errors, all CSS and 149 figures return HTTP 200, both download links resolve in the real repo, no horizontal overflow, mobile layout holds up, code blocks scroll internally as intended. As a *web artifact* it's in good shape.

The issues are split between **a few real front-end polish bugs** and a **more important content/credibility problem**: the model barely beats a naive baseline, and the notebook's narrative overstates the result. For a portfolio piece aimed at recruiters/hiring managers, the framing is the thing most worth fixing.

---

## A. Front-end / QA bugs

| # | Severity | Issue | Location | Fix |
|---|----------|-------|----------|-----|
| A1 | **Med** | `<meta name="description">` is cut off mid-word: `"…the pipeline runs from explo"`. Hurts SEO and link previews. | head, line 7 | Write a complete 150–160 char description. |
| A2 | Low | Heading hierarchy skips a level (H3 → H5 in the EDA section), and the notebook mixes H3/H4/H5 inconsistently. Minor WCAG / a11y nit. | EDA `<details>` | Normalize notebook headings to a single descending order. |
| A3 | Low | `plt.show` (missing `()`) is left in several cells, so outputs render literal `<function matplotlib.pyplot.show>` lines. Looks unfinished in a showcase. | multiple cells | Either fix in source notebook and re-render, or strip those stray output lines. |
| A4 | Low | All 149 figures are PNGs eagerly listed in one page (page is ~70 MB of assets staged). They're `loading="lazy"` (good), but first load is heavy. | figures | Consider WebP + a "show figures" toggle per section. |
| A5 | Info | Figure `alt` text is generic (`"Notebook figure 12"`). | all `<img>` | Optional: describe what each plot shows. |

**No** broken links, no 404s (the ZIP 404 in my test was only because I excluded large binaries from the local staging copy — `Social-Media-Share-Predictor.zip` exists in the real repo).

---

## B. Content / analytical findings (the important ones)

| # | Severity | Issue |
|---|----------|-------|
| B1 | **High (credibility)** | **The model barely predicts.** All three models land at **R² ≈ 0.11–0.13** on validation and **R² ≈ 0.124** on test. That means the model explains ~12% of variance in shares — only marginally better than predicting the mean. |
| B2 | **High (honesty)** | **The narrative overstates the result.** The conclusion says the ANN gives *"way better"* predictions and *"the R² and MAE values are way better in the test set."* They aren't — test R² (0.124) is essentially tied with / slightly below Linear Regression's validation R² (0.127), and all three MAEs sit within ~2% of each other. A sharp reviewer will catch this and it undercuts trust in the whole piece. |
| B3 | **Med** | **Very aggressive outlier removal.** The dataset is cut from **39,644 → 10,886 rows (~73% dropped)** via manual per-column thresholds. Some filters use `>` and keep only the tail (e.g. `kw_max_max > 650000`, `kw_max_avg > 2000`, `kw_avg_avg > 1500`) — worth double-checking these aren't inverted, and the sheer volume dropped is a likely contributor to the weak R². |
| B4 | Low | `sms_df.corr()` is called on the full frame (will warn/break under modern pandas `numeric_only`), and >20 matplotlib figures opened in a loop without `plt.close()` (the RuntimeWarning is visible in the output). Cosmetic in a rendered notebook, but flags as dated. |

**Why B1/B2 matter most:** the honest story here is genuinely interesting — *"share counts are dominated by virality/noise that these features can't capture, so even a tuned ANN only reaches R²≈0.12."* That's a real, defensible data-science insight. The current text instead claims victory, which is both inaccurate and a weaker story than the truth.

---

## C. What's working well

- Clean semantic HTML, skip-link present, `<details>`/`<summary>` accordions keep the long notebook navigable.
- Fully responsive: no horizontal page overflow at 375px; long code lines scroll inside their own blocks.
- All styling and imagery load with no errors.
- Good "At a Glance" framing and download affordances at the top.

---

## D. Recommended fix order

1. **Rewrite the conclusion + "best model" narrative** to tell the honest story (B1, B2). Highest impact, lowest effort.
2. **Fix the meta description** (A1).
3. **Re-examine the outlier thresholds** (B3) — and if you re-run, report the row count retained explicitly.
4. Polish: stray `plt.show`, heading levels, optional WebP (A2–A4).
