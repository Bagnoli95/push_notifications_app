# Modelos Pydantic
from typing import Optional
from pydantic import BaseModel


class UserRegister(BaseModel):
    username: str
    email: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str

class DeviceRegister(BaseModel):
    fcm_token: str
    device_id: str

class PushNotification(BaseModel):
    title: str
    body: str
    user_id: Optional[int] = None
    username: Optional[str] = None

class InternalNotification(BaseModel):
    title: str
    message: str
    user_id: Optional[int] = None
    username: Optional[str] = None