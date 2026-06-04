from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "ReadFlow API"
    database_url: str = "sqlite:///./readflow_dev.db"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 60 * 24 * 14

    model_config = SettingsConfigDict(env_prefix="READFLOW_", env_file=".env")


settings = Settings()
