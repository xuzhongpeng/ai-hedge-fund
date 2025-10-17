from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

class LoginResponse(BaseModel):
    message: str
    username: str

@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    if request.username == "xzp" and request.password == "xzp":
        return LoginResponse(
            message="Login successful",
            username=request.username
        )
    else:
        raise HTTPException(status_code=401, detail="Invalid username or password")
