# backend/main.py
"""
Improved Teqen FastAPI backend
Requirements (example):
pip install fastapi uvicorn redis bcrypt joblib scikit-learn pydantic pyjwt python-multipart

Run:
uvicorn main:app --reload --port 5000
"""

import time
import uuid
import logging
from typing import Optional, Dict, Any, Literal

import bcrypt
import joblib
import numpy as np
import redis
import jwt

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings
from sklearn.ensemble import RandomForestClassifier
import sqlite3
from pathlib import Path
from fastapi.middleware.cors import CORSMiddleware


# -------------------------
# Settings
# -------------------------
class Settings(BaseSettings):
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 0
    jwt_secret: str = "CHANGE_ME_TO_A_STRONG_SECRET"
    jwt_alg: str = "HS256"
    session_ttl: int = 300
    push_ttl: int = 180
    db_path: str = "users.db"
    rate_limit_max: int = 10           # max requests
    rate_limit_window: int = 60        # seconds for window
    block_threshold: int = 5           # failed attempts threshold to escalate block
    block_durations: Dict[str, int] = {
        "low": 300,           # 5 minutes
        "medium": 600,        # 10 minutes
        "high": 86400,        # 1 day
        "critical": 86400*7   # 7 days
    }

settings = Settings()

# -------------------------
# Logging
# -------------------------
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("teqen")

# -------------------------
# Redis client
# -------------------------
r = redis.Redis(
    host=settings.redis_host,
    port=settings.redis_port,
    db=settings.redis_db,
    decode_responses=True
)

# -------------------------
# DB (SQLite simple wrapper)
# -------------------------
def get_db_conn():
    conn = sqlite3.connect(settings.db_path, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

db = get_db_conn()

# create tables if not exist
db.execute("""
CREATE TABLE IF NOT EXISTS users(
    id INTEGER PRIMARY KEY,
    username TEXT UNIQUE,
    password BLOB,
    trusted_ips TEXT
)
""")
db.execute("""
CREATE TABLE IF NOT EXISTS attempts(
    id INTEGER PRIMARY KEY,
    username TEXT,
    ip TEXT,
    country TEXT,
    device TEXT,
    failed_attempts INTEGER,
    last_risk TEXT,
    created_at REAL
)
""")
db.commit()

# -------------------------
# Pydantic models
# -------------------------
class LoginReq(BaseModel):
    username: str = Field(min_length=1)
    password: str = Field(min_length=1)
    device: Optional[str] = None
    country: Optional[str] = None

class PushDecision(BaseModel):
    request_id: str
    action: Literal["allow", "deny"]
    sure: bool = True


# -------------------------
# Helper: password utils
# -------------------------
def hash_password(plain: str) -> bytes:
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt())

def verify_password(plain: str, hashed: bytes) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed)

# -------------------------
# Create demo users if not exist
# -------------------------
demo_users = [
    ("alice", "password1"),
    ("bob", "password2"),
    ("charlie", "password3"),
    ("dave", "password4"),
    ("eve", "password5")
]
for u, p in demo_users:
    cur = db.execute("SELECT id FROM users WHERE username=?", (u,)).fetchone()
    if not cur:
        db.execute(
            "INSERT INTO users(username,password) VALUES(?,?)",
            (u, hash_password(p))
        )
db.commit()

# -------------------------
# ML Model (simple)
# -------------------------
MODEL_PATH = "risk_model_improved.pkl"

def create_ml_model():
    X = np.array([
        [0,0,0], [1,0,0], [0,1,0], [0,0,1],
        [1,1,0], [1,0,1], [0,1,1], [1,1,1]
    ])
    y = np.array([0,1,1,1,2,2,2,3])
    model = RandomForestClassifier(n_estimators=50, random_state=42)
    model.fit(X, y)
    joblib.dump(model, MODEL_PATH)
    return model

try:
    ml_model = joblib.load(MODEL_PATH)
except Exception:
    ml_model = create_ml_model()

def predict_ml(ip_change: int, country_change: int, device_change: int) -> int:
    sample = np.array([[ip_change, country_change, device_change]])
    pred = int(ml_model.predict(sample)[0])
    return pred  # 0..3

# -------------------------
# FastAPI app
# -------------------------
app = FastAPI(title="teqen server (improved)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/push/pending/{username}")
def get_pending_push(username: str):
    keys = r.keys("push:*")
    pending = []
    for k in keys:
        data = r.hgetall(k)
        if data and data.get("user") == username and data.get("status") == "pending":
            pending.append({
                "push_id": k.replace("push:", ""),
                **data
            })
    return pending

# ====== Simelater Absher dashboard static + HTML ======

BASE_DIR = Path(__file__).resolve().parent
ABSHER_DIR = BASE_DIR / "Simelater Absher"

if ABSHER_DIR.exists():
    app.mount(
        "/Simelater Absher",
        StaticFiles(directory=ABSHER_DIR, html=True),
        name="Simelater Absher",
    )

# ====== SOC dashboard static + HTML ======
BASE_DIR = Path(__file__).resolve().parent
SOC_DIR = BASE_DIR / "soc"   # هنا لازم يكون مجلد soc في نفس مكان main.py

# نخدم ملفات CSS/JS/صور كـ static
if SOC_DIR.exists():
    app.mount(
        "/soc-static",
        StaticFiles(directory=SOC_DIR),
        name="soc-static"
    )

@app.get("/soc", response_class=HTMLResponse)
async def soc_dashboard():
    """
    يعرض صفحة SOC من ملف HTML داخل مجلد soc
    اسم الملف هنا: sochtml.html
    """
    html_path = SOC_DIR / "sochtml.html"
    if not html_path.exists():
        return HTMLResponse("<h2>SOC dashboard file not found</h2>", status_code=404)
    return HTMLResponse(html_path.read_text(encoding="utf-8"))

# =========================================

# -------------------------
# Utility: extract client IP safely
# -------------------------
def extract_client_ip(request: Request) -> str:
    xff = request.headers.get("x-forwarded-for")
    if xff:
        return xff.split(",")[0].strip()
    client = request.client
    return client.host if client else "0.0.0.0"

# -------------------------
# Rate limiting (Redis sliding window)
# -------------------------
def redis_rate_limit_key(ip: str) -> str:
    return f"rl:{ip}"

def rate_limit_check(ip: str):
    key = redis_rate_limit_key(ip)
    now = int(time.time() * 1000)
    window_ms = settings.rate_limit_window * 1000
    pipeline = r.pipeline()
    pipeline.zremrangebyscore(key, 0, now - window_ms)
    pipeline.zcard(key)
    pipeline.zadd(key, {str(uuid.uuid4()): now})
    pipeline.expire(key, settings.rate_limit_window + 2)
    _, count, _, _ = pipeline.execute()
    if count and int(count) >= settings.rate_limit_max:
        raise HTTPException(status_code=429, detail="Too many requests from IP")

# -------------------------
# Blocking utilities
# -------------------------
def block_ip(ip: str, seconds: int):
    r.set(f"block:{ip}", "1", ex=seconds)
    logger.warning(f"Blocked IP {ip} for {seconds}s")

def is_blocked(ip: str) -> bool:
    return r.exists(f"block:{ip}") == 1

# -------------------------
# SOC alert storage
# -------------------------
def soc_alert(info: dict, rule_risk: str, ml_risk: str):
    
    alert_id = str(uuid.uuid4())
    
    payload = {
        "user": info.get("user", ""),
        "ip": info.get("ip", ""),
        "country": info.get("country", ""),
        "device": info.get("device", ""),
        "action": info.get("status", ""),
        "rule_risk": rule_risk,
        "ml_risk": ml_risk,
        "time": str(time.time())
        
    }
    
    r.hset(f"soc:{alert_id}", mapping=payload)
    logger.error(f"SOC ALERT [{alert_id}] — rule={rule_risk}, ml={ml_risk}, data={info}")
    

# ========== Attempts (Absher Simulator) ==========

class AttemptModel(BaseModel):
    attemptId: str
    userId: str
    serviceName: Optional[str] = None
    status: Optional[str] = None
    riskLevel: Optional[str] = None
    riskReason: Optional[str] = None
    riskDetails: Optional[str] = None
    previousLocation: Optional[str] = None
    currentLocation: Optional[str] = None
    ipAddress: Optional[str] = None
    deviceInfo: Optional[str] = None
    createdAt: Optional[str] = None
    matchingCode: Optional[str] = None


@app.post("/attempts")
def save_attempt(attempt: AttemptModel):
    """
    يستقبل المحاولة من محاكي أبشر
    - يحفظها في Redis
    - يحدّث مؤشر آخر محاولة
    - يرسل تنبيه للسوك
    """
    # احفظ المحاولة
    key = f"attempt:{attempt.attemptId}"
    r.hset(key, mapping=attempt.model_dump())
    r.expire(key, 600)  # 10 دقائق

    # احفظ آخر attemptId
    r.set("attempt:last_id", attempt.attemptId, ex=600)

    # ارسل SOC alert (اختياري لكن مهم عندكم)
    info = {
        "user": attempt.userId,
        "ip": attempt.ipAddress or "",
        "country": attempt.currentLocation or "",
        "device": attempt.deviceInfo or "",
        "status": attempt.status or "Suspicious",
    }
    soc_alert(info, "high", "critical")

    return {"status": "ok", "attemptId": attempt.attemptId}


@app.get("/attempts/last")
def get_last_attempt():
    """
    يرجّع آخر محاولة محفوظة (لتطبيق تيقّن)
    """
    last_id = r.get("attempt:last_id")
    if not last_id:
        return {"status": "empty"}

    data = r.hgetall(f"attempt:{last_id}")
    if not data:
        return {"status": "empty"}

    return data


@app.get("/attempts/{attempt_id}")
def get_attempt(attempt_id: str):
    """
    يرجّع محاولة معينة (code.html?attemptId=...)
    """
    data = r.hgetall(f"attempt:{attempt_id}")
    if not data:
        raise HTTPException(status_code=404, detail="Attempt not found")
    return data

# نخزن آخر محاولة مشبوهة 
last_attempt: Optional[AttemptModel] = None


@app.get("/soc/alerts")
def get_soc_alerts():
    keys = r.keys("soc:*")
    alerts = []
    for k in keys:
        item = r.hgetall(k)
        item["id"] = k
        alerts.append(item)

    alerts.sort(key=lambda x: float(x.get("time", 0)), reverse=True)
    return alerts

# -------------------------
# Rule engine: numeric scoring + textual
# -------------------------
RISK_LEVELS = ["normal", "low", "medium", "high", "critical"]

def rule_engine_score(data: Dict[str, Any]) -> Dict[str, Any]:
    ip_change = 1 if data.get("ip") != data.get("last_ip") else 0
    device_change = 1 if data.get("device") != data.get("last_device") else 0
    country_change = 1 if data.get("country") != data.get("last_country") else 0

    score = ip_change + device_change + (2 * country_change)

    if ip_change and country_change and device_change:
        label = "critical"
    elif country_change and not (ip_change and device_change):
        label = "high"
    elif ip_change or device_change:
        label = "medium"
    elif score == 0:
        label = "normal"
    else:
        label = "low"

    numeric = min(3, score)
    return {
        "numeric": numeric,
        "label": label,
        "ip_change": ip_change,
        "country_change": country_change,
        "device_change": device_change
    }

def compute_combined_risk(data: Dict[str, Any], approved: bool) -> Dict[str, Any]:
    rule = rule_engine_score(data)
    ml_pred = predict_ml(
        int(rule["ip_change"]),
        int(rule["country_change"]),
        int(rule["device_change"])
    )
    ml_map = {0: "normal", 1: "medium", 2: "high", 3: "critical"}
    ml_label = ml_map.get(ml_pred, "normal")

    def severity_index(lbl: str) -> int:
        try:
            return RISK_LEVELS.index(lbl)
        except ValueError:
            return 0

    final_idx = max(severity_index(rule["label"]), severity_index(ml_label))
    final_label = RISK_LEVELS[min(final_idx, len(RISK_LEVELS)-1)]

    failed = int(data.get("failed_attempts", 0))
    if final_label in ("critical", "high") and failed >= settings.block_threshold:
        secs = settings.block_durations.get(final_label, 3600)
        block_ip(data["ip"], secs)
        soc_alert(data, rule["label"], ml_label)

    if final_label == "critical" and approved:
        soc_alert(data, rule["label"], ml_label)

    return {
        "rule_label": rule["label"],
        "ml_label": ml_label,
        "final_label": final_label,
        "rule_details": rule
    }

# -------------------------
# JWT utils
# -------------------------
def create_jwt(username: str, exp_seconds: int = 3600) -> str:
    payload = {
        "sub": username,
        "iat": int(time.time()),
        "exp": int(time.time()) + exp_seconds
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_alg)
    return token

# -------------------------
# Main endpoints
# -------------------------
# --------- محاولات محاكي أبشر + تخزينها + SOC ----------

# نخزن آخر محاولة في الذاكرة (اختياري لو احتجناه لاحقًا)
last_attempt: Optional[AttemptModel] = None

# ---------------------------------------------------------

@app.post("/login")
def login(req: LoginReq, request: Request):
    client_ip = extract_client_ip(request)

    if is_blocked(client_ip):
        raise HTTPException(status_code=403, detail="IP blocked")

    rate_limit_check(client_ip)

    row = db.execute(
        "SELECT password, trusted_ips FROM users WHERE username=?",
        (req.username,)
    ).fetchone()
    if not row:
        raise HTTPException(status_code=401, detail="Invalid username or password")

    hashed = row["password"]
    if not verify_password(req.password, hashed):
        db.execute(
            "INSERT INTO attempts(username,ip,country,device,failed_attempts,last_risk,created_at) "
            "VALUES(?,?,?,?,?,?,?)",
            (req.username, client_ip, req.country, req.device, 1, "failed_auth", time.time())
        )
        db.commit()
        raise HTTPException(status_code=401, detail="Invalid username or password")

    last = db.execute(
        "SELECT ip,country,device,failed_attempts FROM attempts WHERE username=? "
        "ORDER BY id DESC LIMIT 1",
        (req.username,)
    ).fetchone()

    if last:
        last_ip, last_country, last_device, failed_attempts = (
            last["ip"],
            last["country"],
            last["device"],
            int(last["failed_attempts"] or 0),
        )
    else:
        last_ip, last_country, last_device, failed_attempts = (
            client_ip,
            req.country,
            req.device,
            0,
        )

    rid = str(uuid.uuid4())
    push_key = f"push:{rid}"
    mapping = {
        "user": req.username,
        "ip": client_ip,
        "country": req.country or "",
        "device": req.device or "",
        "last_ip": last_ip or "",
        "last_country": last_country or "",
        "last_device": last_device or "",
        "status": "pending",
        "failed_attempts": failed_attempts,
    }
    r.hset(push_key, mapping=mapping)
    r.expire(push_key, settings.push_ttl)

    return JSONResponse({"status": "MFA_REQUIRED", "push_id": rid})

@app.post("/mfa")
def mfa(req: PushDecision):
    push_key = f"push:{req.request_id}"
    data = r.hgetall(push_key)
    if not data:
        raise HTTPException(status_code=400, detail="Invalid or expired request")

    approved = req.action == "allow"
    info = {
        "user": data.get("user"),
        "ip": data.get("ip"),
        "country": data.get("country"),
        "device": data.get("device"),
        "last_ip": data.get("last_ip"),
        "last_country": data.get("last_country"),
        "last_device": data.get("last_device"),
        "status": req.action,
        "failed_attempts": int(data.get("failed_attempts", 0)),
    }
    if not approved:
        info["failed_attempts"] += 1

    risk = compute_combined_risk(info, approved)

    db.execute(
        "INSERT INTO attempts(username,ip,country,device,failed_attempts,last_risk,created_at) "
        "VALUES(?,?,?,?,?,?,?)",
        (
            info["user"],
            info["ip"],
            info["country"],
            info["device"],
            info["failed_attempts"],
            risk["final_label"],
            time.time(),
        ),
    )
    db.commit()

    r.delete(push_key)

    response = {
        "status": req.action,
        "rule_risk": risk["rule_label"],
        "ml_risk": risk["ml_label"],
        "final_risk": risk["final_label"],
    }

    if approved:
        token = create_jwt(info["user"], exp_seconds=3600)
        response["token"] = token

    return response

# -------------------------
# Admin helper: unblock ip (for debugging)
# -------------------------
@app.post("/admin/unblock")
def admin_unblock(ip: str):
    r.delete(f"block:{ip}")
    return {"status": "ok", "unblocked": ip}

# -------------------------
# Healthcheck
# -------------------------
@app.get("/health")
def health():
    try:
        r.ping()
        return {"status": "ok"}
    except Exception:
        raise HTTPException(status_code=503, detail="Redis unreachable")

# -------------------------
# Exception handlers (clean JSON)
# -------------------------
@app.exception_handler(HTTPException)
def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(status_code=exc.status_code, content={"error": exc.detail})