import os
import subprocess
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel

app = FastAPI()
SECRET_TOKEN = os.getenv("AGENT_SECRET", "default_secret")

class AccountRequest(BaseModel):
    protocol: str
    username: str
    duration_days: int
    password: str = "123456"

@app.get("/ping")
def ping():
    return {"status": "online"}

@app.post("/api/account/create")
def create_account(data: AccountRequest, x_agent_token: str = Header(None)):
    if x_agent_token != SECRET_TOKEN:
        raise HTTPException(status_code=401, detail="Token autentikasi salah")

    # Sesuaikan path script CLI bawaan script tunneling VPS Anda
    commands = {
        "ssh": f"/usr/bin/add-ssh {data.username} {data.password} {data.duration_days}",
        "vmess": f"/usr/bin/add-ws {data.username} {data.duration_days}",
        "vless": f"/usr/bin/add-vless {data.username} {data.duration_days}",
        "trojan": f"/usr/bin/add-tr {data.username} {data.duration_days}"
    }

    cmd = commands.get(data.protocol.lower())
    if not cmd:
        raise HTTPException(status_code=400, detail="Protokol tidak didukung")

    try:
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True)
        return {
            "status": "success",
            "protocol": data.protocol,
            "username": data.username,
            "raw_output": proc.stdout
        }
    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Gagal: {e.stderr or e.stdout}")
