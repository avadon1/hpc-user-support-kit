import argparse
import json
import os
import platform
import sys
from pathlib import Path

import numpy as np
import sklearn
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler


def main() -> int:
    ap = argparse.ArgumentParser(description="CPU demo: sklearn Iris + LogisticRegression")
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", type=str, default="output/metrics.json")
    args = ap.parse_args()

    X, y = load_iris(return_X_y=True)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=args.seed, stratify=y
    )

    model = Pipeline(
        steps=[
            ("scaler", StandardScaler()),
            ("clf", LogisticRegression(solver="lbfgs", max_iter=500)),
        ]
    )
    model.fit(X_train, y_train)
    acc = float(accuracy_score(y_test, model.predict(X_test)))

    metrics = {
        "dataset": "iris",
        "n_samples": int(X.shape[0]),
        "n_features": int(X.shape[1]),
        "n_classes": int(np.unique(y).size),
        "accuracy": acc,
        "seed": args.seed,
        "python": sys.version.split()[0],
        "python_executable": sys.executable,
        "platform": platform.platform(),
        "numpy": np.__version__,
        "sklearn": sklearn.__version__,
        "slurm_job_id": os.environ.get("SLURM_JOB_ID"),
    }

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print("CPU demo (sklearn) completed")
    print(f"accuracy={acc:.4f}")
    print(f"wrote_metrics={out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
