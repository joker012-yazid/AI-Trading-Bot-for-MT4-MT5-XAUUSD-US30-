from __future__ import annotations

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

BOTDATA_PATH = Path(os.getenv("BOTDATA", str(Path(__file__).resolve().parent.parent / "botdata")))
BASE_EQUITY = float(os.getenv("BASE_EQUITY", "1000"))
DAILY_LOSS_LIMIT = float(os.getenv("DAILY_LOSS_LIMIT", "2.0"))

LOG_PATH = BOTDATA_PATH / "logs"
PRESETS_PATH = BOTDATA_PATH / "presets"
CONTROL_FILE = BOTDATA_PATH / "control.json"
NEWS_FILE = BOTDATA_PATH / "news.csv"

app = FastAPI(title="AI Trading Bot Dashboard")
templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))

app.mount("/static", StaticFiles(directory=str(Path(__file__).parent / "templates")), name="static")


def _read_trades() -> Optional[pd.DataFrame]:
    if not LOG_PATH.exists():
        return None

    csv_files = sorted(LOG_PATH.glob("*.csv"))
    if not csv_files:
        return None

    latest = csv_files[-1]
    try:
        df = pd.read_csv(latest, parse_dates=["timestamp"], infer_datetime_format=True)
        return df
    except Exception:
        return None


def _derive_equity_curve(df: pd.DataFrame) -> pd.Series:
    balance = df.get("balance")
    if balance is not None and not balance.isna().all():
        return balance

    pnl = df.get("profit")
    if pnl is None or pnl.empty:
        raise ValueError("Trade log missing profit column")

    cumulative = pnl.cumsum()
    return cumulative + BASE_EQUITY


def _calculate_metrics(df: pd.DataFrame) -> Dict[str, Any]:
    if df.empty:
        raise ValueError("Trade log is empty")

    if "timestamp" not in df.columns:
        raise ValueError("Trade log missing timestamp column")

    df_sorted = df.sort_values("timestamp")
    pnl = df_sorted.get("profit")
    if pnl is None:
        raise ValueError("Trade log missing profit column")

    trades = int(pnl.count())
    total_pnl = float(pnl.sum())
    pnl_pct = round((total_pnl / BASE_EQUITY) * 100, 4) if BASE_EQUITY else None

    equity_curve = _derive_equity_curve(df_sorted)
    max_dd = None
    if equity_curve is not None and not equity_curve.empty:
        running_max = equity_curve.cummax()
        drawdown = (equity_curve - running_max) / running_max * 100
        max_dd = round(drawdown.min(), 4)

    day_counts = int(df_sorted["timestamp"].dt.normalize().nunique())

    today = datetime.utcnow().date()
    today_mask = df_sorted["timestamp"].dt.date == today
    today_pnl = float(df_sorted.loc[today_mask, "profit"].sum()) if today_mask.any() else 0.0
    daily_pnl_pct_today = round((today_pnl / BASE_EQUITY) * 100, 4) if BASE_EQUITY else None
    lockout_breached = False
    if daily_pnl_pct_today is not None:
        lockout_breached = daily_pnl_pct_today <= -DAILY_LOSS_LIMIT

    return {
        "trades": trades,
        "pnl": round(total_pnl, 2),
        "pnl_pct": pnl_pct,
        "max_dd": max_dd,
        "days": day_counts,
        "daily_pnl_pct_today": daily_pnl_pct_today,
        "lockout_breached": lockout_breached,
    }


def _build_daily_series(df: pd.DataFrame) -> List[Dict[str, Any]]:
    if df.empty:
        return []

    if "timestamp" not in df.columns or "profit" not in df.columns:
        raise ValueError("Trade log missing timestamp/profit columns")

    df_sorted = df.sort_values("timestamp").copy()
    df_sorted["date"] = df_sorted["timestamp"].dt.date
    grouped = df_sorted.groupby("date")["profit"].sum().reset_index().sort_values("date")
    grouped["equity"] = BASE_EQUITY + grouped["profit"].cumsum()

    return [
        {
            "date": datetime.strftime(row["date"], "%Y-%m-%d"),
            "pnl": round(float(row["profit"]), 2),
            "equity": round(float(row["equity"]), 2),
        }
        for _, row in grouped.iterrows()
    ]


def _list_presets() -> List[str]:
    if not PRESETS_PATH.exists():
        return []
    return sorted([item.name for item in PRESETS_PATH.glob("*.set") if item.is_file()])


def _load_control() -> Dict[str, Any]:
    if not CONTROL_FILE.exists():
        return {
            "trading_enabled": True,
            "risk_percent": 0.5,
        }
    try:
        data = json.loads(CONTROL_FILE.read_text())
        return {
            "trading_enabled": bool(data.get("trading_enabled", True)),
            "risk_percent": float(data.get("risk_percent", 0.5)),
        }
    except Exception:
        return {
            "trading_enabled": True,
            "risk_percent": 0.5,
        }


@app.get("/", response_class=HTMLResponse)
async def index(request: Request) -> HTMLResponse:
    context = {
        "request": request,
        "base_equity": BASE_EQUITY,
        "daily_loss_limit": DAILY_LOSS_LIMIT,
        "presets": _list_presets(),
        "control": _load_control(),
    }
    return templates.TemplateResponse("index.html", context)


@app.get("/api/metrics")
async def api_metrics() -> JSONResponse:
    df = _read_trades()
    if df is None:
        return JSONResponse({"detail": "No trade logs available"}, status_code=404)

    try:
        metrics = _calculate_metrics(df)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return JSONResponse(metrics)


@app.get("/api/daily")
async def api_daily() -> JSONResponse:
    df = _read_trades()
    if df is None:
        return JSONResponse({"detail": "No trade logs available"}, status_code=404)

    try:
        daily = _build_daily_series(df)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    return JSONResponse(daily)


@app.get("/api/presets")
async def api_presets() -> JSONResponse:
    return JSONResponse({"presets": _list_presets()})


@app.get("/api/control")
async def api_control() -> JSONResponse:
    return JSONResponse(_load_control())


@app.post("/upload/preset")
async def upload_set(file: UploadFile = File(...)) -> JSONResponse:
    if not file.filename.lower().endswith(".set"):
        raise HTTPException(status_code=400, detail="Only .set files are supported")

    PRESETS_PATH.mkdir(parents=True, exist_ok=True)
    target = PRESETS_PATH / file.filename
    content = await file.read()
    target.write_bytes(content)
    return JSONResponse({"status": "ok", "filename": file.filename})


@app.post("/upload/news")
async def upload_news(file: UploadFile = File(...)) -> JSONResponse:
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Only CSV files are supported")

    NEWS_FILE.parent.mkdir(parents=True, exist_ok=True)
    content = await file.read()
    NEWS_FILE.write_bytes(content)
    return JSONResponse({"status": "ok", "filename": file.filename})


def _coerce_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


@app.post("/control")
async def update_control(
    trading_enabled: Any = Form(...),
    risk_percent: float = Form(...),
) -> JSONResponse:
    if risk_percent <= 0:
        raise HTTPException(status_code=400, detail="Risk percent must be positive")

    CONTROL_FILE.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "trading_enabled": _coerce_bool(trading_enabled),
        "risk_percent": risk_percent,
        "updated_at": datetime.utcnow().isoformat() + "Z",
    }
    CONTROL_FILE.write_text(json.dumps(payload, indent=2))
    return JSONResponse({"status": "saved", "data": payload})
