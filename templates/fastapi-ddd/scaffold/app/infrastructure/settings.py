from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "dev"
    app_debug: bool = True
    database_url: str = "postgresql://test:test@infra-postgres:5432/devhub"
    redis_url: str = "redis://infra-redis:6379/0"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
