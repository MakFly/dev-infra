from fastapi import FastAPI

from app.interfaces.http.health import router as health_router

app = FastAPI(title="DevHub FastAPI DDD")
app.include_router(health_router)
