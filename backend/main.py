from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
import jwt
import bcrypt
import oracledb
from datetime import datetime, timedelta
from models.model import UserRegister, UserLogin, DeviceRegister, PushNotification, InternalNotification
import firebase_admin
from firebase_admin import credentials, messaging
import os
from contextlib import contextmanager
import uuid
from dotenv import load_dotenv
import logging
import json
import traceback
from typing import Optional
import time

# Cargar variables de entorno
load_dotenv()

# ==========================================
# CONFIGURACIÓN DE LOGGING
# ==========================================

# Configurar logging con encoding UTF-8 para Windows
import sys

# Configurar stdout para UTF-8 en Windows
if sys.platform == "win32":
    import codecs
    sys.stdout = codecs.getwriter("utf-8")(sys.stdout.detach())
    sys.stderr = codecs.getwriter("utf-8")(sys.stderr.detach())

# Configurar handlers con encoding UTF-8
file_handler = logging.FileHandler('app.log', encoding='utf-8')
file_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))

console_handler = logging.StreamHandler()
console_handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))

# Configurar el logger root
root_logger = logging.getLogger()
root_logger.setLevel(logging.INFO)
root_logger.addHandler(file_handler)
root_logger.addHandler(console_handler)

# Loggers específicos
logger = logging.getLogger("PushNotificationsAPI")
db_logger = logging.getLogger("Database")
firebase_logger = logging.getLogger("Firebase")
auth_logger = logging.getLogger("Authentication")

app = FastAPI(title="Push Notifications API")
security = HTTPBearer()

# Agregar CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especifica los dominios permitidos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# MIDDLEWARE DE LOGGING
# ==========================================

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # Log del request
    client_ip = request.client.host
    user_agent = request.headers.get("user-agent", "Unknown")
    
    logger.info(f"🔵 REQUEST START - {request.method} {request.url.path}")
    logger.info(f"   📍 Client IP: {client_ip}")
    logger.info(f"   🌐 User-Agent: {user_agent}")
    
    # Log de headers importantes (sin authorization completo por seguridad)
    auth_header = request.headers.get("authorization")
    if auth_header:
        logger.info(f"   🔐 Authorization: Bearer ***{auth_header[-10:] if len(auth_header) > 10 else '***'}")
    
    # Log del body para POST/PUT (limitado para seguridad)
    if request.method in ["POST", "PUT", "PATCH"]:
        try:
            body = await request.body()
            if body:
                # Parsear JSON y ocultar contraseñas
                try:
                    body_json = json.loads(body.decode())
                    if 'password' in body_json:
                        body_json['password'] = '***'
                    logger.info(f"   📄 Request Body: {json.dumps(body_json, indent=2)}")
                except:
                    logger.info(f"   📄 Request Body: {body.decode()[:200]}...")
        except:
            logger.info("   📄 Request Body: [Could not read body]")
    
    # Recrear el request para que siga funcionando
    async def receive():
        return {"type": "http.request", "body": body if 'body' in locals() else b""}
    
    request._receive = receive
    
    # Procesar request
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        # Log del response
        logger.info(f"🟢 RESPONSE SUCCESS - {request.method} {request.url.path}")
        logger.info(f"   📊 Status Code: {response.status_code}")
        logger.info(f"   ⏱️ Process Time: {process_time:.3f}s")
        
        return response
        
    except Exception as e:
        process_time = time.time() - start_time
        logger.error(f"🔴 RESPONSE ERROR - {request.method} {request.url.path}")
        logger.error(f"   ❌ Error: {str(e)}")
        logger.error(f"   ⏱️ Process Time: {process_time:.3f}s")
        logger.error(f"   📚 Traceback: {traceback.format_exc()}")
        raise

# ==========================================
# CONFIGURACIÓN ORIGINAL
# ==========================================

# Configuración desde variables de entorno
SENDER_ID = int(os.getenv("SENDER_ID", "0"))
SERVER_KEY = os.getenv("SERVER_KEY", "")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "./push-notifications-app.json")

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "fallback-secret-key-change-this")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))

# Oracle Database Configuration
ORACLE_USER = os.getenv("ORACLE_USER", "")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "")
ORACLE_HOST = os.getenv("ORACLE_HOST", "10.5.2.171")
ORACLE_PORT = int(os.getenv("ORACLE_PORT", "1521"))
ORACLE_SID = os.getenv("ORACLE_SID", "SICOOP")
ORACLE_JAR_PATH = os.getenv("ORACLE_JAR_PATH", "./utils/instantclient")

# Server Configuration
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8000"))
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

logger.info(f"🚀 Initializing Push Notifications API")
logger.info(f"   🌍 Environment: {ENVIRONMENT}")
logger.info(f"   🖥️ Host: {HOST}:{PORT}")

# Validar variables críticas
if not ORACLE_USER or not ORACLE_PASSWORD:
    logger.error("❌ ORACLE_USER and ORACLE_PASSWORD must be set in .env file")
    raise ValueError("ORACLE_USER and ORACLE_PASSWORD must be set in .env file")

if not SERVER_KEY:
    logger.error("❌ SERVER_KEY must be set in .env file")
    raise ValueError("SERVER_KEY must be set in .env file")

if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
    logger.error(f"❌ Firebase credentials file not found: {FIREBASE_CREDENTIALS_PATH}")
    raise ValueError(f"Firebase credentials file not found: {FIREBASE_CREDENTIALS_PATH}")

# Inicializar Oracle Client
try:
    if ORACLE_JAR_PATH and os.path.exists(ORACLE_JAR_PATH):
        oracledb.init_oracle_client(lib_dir=os.path.abspath(ORACLE_JAR_PATH))
        logger.info(f"✅ Oracle Client initialized from: {os.path.abspath(ORACLE_JAR_PATH)}")
    else:
        logger.warning("⚠️ Oracle Client path not found, using Thin mode")
except Exception as e:
    logger.warning(f"⚠️ Oracle Client init failed, using Thin mode: {e}")

# Construir DSN
ORACLE_DSN = oracledb.makedsn(ORACLE_HOST, ORACLE_PORT, sid=ORACLE_SID)
logger.info(f"✅ Oracle DSN: {ORACLE_DSN}")

# Inicializar Firebase Admin
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)
    firebase_logger.info(f"✅ Firebase initialized successfully with project: {cred.project_id}")
except Exception as e:
    firebase_logger.error(f"❌ Error initializing Firebase: {e}")
    raise

# ==========================================
# FUNCIONES DE UTILIDAD CON LOGGING
# ==========================================

@contextmanager
def get_db_connection():
    connection = None
    try:
        db_logger.info("🔗 Attempting Oracle connection...")
        connection = oracledb.connect(
            user=ORACLE_USER, 
            password=ORACLE_PASSWORD, 
            dsn=ORACLE_DSN
        )
        db_logger.info("✅ Oracle connection established")
        yield connection
    except oracledb.Error as e:
        db_logger.error(f"❌ Oracle connection error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database connection failed"
        )
    finally:
        if connection:
            connection.close()
            db_logger.info("🔗 Oracle connection closed")

def hash_password(password: str) -> str:
    auth_logger.info("🔐 Hashing password...")
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    auth_logger.info("🔐 Verifying password...")
    result = bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))
    auth_logger.info(f"🔐 Password verification: {'✅ Success' if result else '❌ Failed'}")
    return result

def create_access_token(data: dict):
    auth_logger.info(f"🎫 Creating access token for user: {data.get('sub', 'unknown')}")
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    auth_logger.info(f"✅ Access token created, expires: {expire}")
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        auth_logger.info("🎫 Verifying access token...")
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        user_id: int = payload.get("user_id")
        
        if username is None:
            auth_logger.error("❌ Token verification failed: missing username")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials"
            )
        
        auth_logger.info(f"✅ Token verified for user: {username} (ID: {user_id})")
        return payload
    except jwt.PyJWTError as e:
        auth_logger.error(f"❌ Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

# ==========================================
# ENDPOINTS CON LOGGING DETALLADO
# ==========================================

@app.get("/")
async def root():
    logger.info("📋 Root endpoint accessed")
    return {
        "message": "Push Notifications API",
        "environment": ENVIRONMENT,
        "version": "1.0.0",
        "docs": "/docs"
    }

@app.post("/register")
async def register_user(user: UserRegister):
    logger.info(f"👤 Registration attempt for user: {user.username}")
    logger.info(f"   📧 Email: {user.email}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verificar si usuario ya existe
            db_logger.info(f"🔍 Checking if user exists: {user.username}")
            cursor.execute("SELECT id FROM test.np_users WHERE username = :1 OR email = :2", 
                        (user.username, user.email))
            existing_user = cursor.fetchone()
            
            if existing_user:
                logger.warning(f"⚠️ Registration failed: User {user.username} already exists")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username or email already registered"
                )
            
            # Crear usuario
            logger.info(f"💾 Creating new user: {user.username}")
            hashed_password = hash_password(user.password)
            cursor.execute("""
                INSERT INTO test.np_users (username, email, password_hash) 
                VALUES (:1, :2, :3)
            """, (user.username, user.email, hashed_password))
            conn.commit()
            
            logger.info(f"✅ User {user.username} registered successfully")
            return {"message": "User registered successfully"}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Registration error for {user.username}: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed"
        )

@app.post("/login")
async def login_user(user: UserLogin):
    logger.info(f"🔑 Login attempt for user: {user.username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            db_logger.info(f"🔍 Looking up user: {user.username}")
            cursor.execute("""
                SELECT id, username, password_hash 
                FROM test.np_users WHERE username = :1
            """, (user.username,))
            
            db_user = cursor.fetchone()
            
            if not db_user:
                logger.warning(f"⚠️ Login failed: User {user.username} not found")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Incorrect username or password"
                )
            
            logger.info(f"👤 User found: {user.username} (ID: {db_user[0]})")
            
            if not verify_password(user.password, db_user[2]):
                logger.warning(f"⚠️ Login failed: Invalid password for {user.username}")
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Incorrect username or password"
                )
            
            # Crear token
            access_token = create_access_token(data={"sub": user.username, "user_id": db_user[0]})
            
            logger.info(f"✅ Login successful for {user.username}")
            return {
                "access_token": access_token,
                "token_type": "bearer",
                "user_id": db_user[0],
                "username": db_user[1]
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Login error for {user.username}: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed"
        )

@app.post("/register-device")
async def register_device(device: DeviceRegister, current_user = Depends(verify_token)):
    user_id = current_user["user_id"]
    username = current_user["sub"]
    
    logger.info(f"📱 Device registration for user: {username} (ID: {user_id})")
    logger.info(f"   🆔 Device ID: {device.device_id}")
    logger.info(f"   🔥 FCM Token: {device.fcm_token[:20]}...{device.fcm_token[-10:]}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Verificar si el device ya existe
            db_logger.info(f"🔍 Checking existing device for user {user_id}")
            cursor.execute("""
                SELECT id FROM test.np_devices 
                WHERE user_id = :1 AND device_id = :2
            """, (user_id, device.device_id))
            
            existing_device = cursor.fetchone()
            
            if existing_device:
                logger.info(f"🔄 Updating existing device {device.device_id}")
                cursor.execute("""
                    UPDATE test.np_devices 
                    SET fcm_token = :1, updated_at = CURRENT_TIMESTAMP
                    WHERE user_id = :2 AND device_id = :3
                """, (device.fcm_token, user_id, device.device_id))
                action = "updated"
            else:
                logger.info(f"➕ Creating new device registration {device.device_id}")
                cursor.execute("""
                    INSERT INTO test.np_devices (user_id, device_id, fcm_token)
                    VALUES (:1, :2, :3)
                """, (user_id, device.device_id, device.fcm_token))
                action = "created"
            
            conn.commit()
            logger.info(f"✅ Device {action} successfully for user {username}")
            return {"message": "Device registered successfully"}
            
    except Exception as e:
        logger.error(f"❌ Device registration error for {username}: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Device registration failed"
        )

@app.post("/send-push-notification")
async def send_push_notification(notification: PushNotification, current_user = Depends(verify_token)):
    username = current_user["sub"]
    
    logger.info(f"🔔 Push notification request from user: {username}")
    logger.info(f"   📝 Title: {notification.title}")
    logger.info(f"   📄 Body: {notification.body[:100]}...")
    logger.info(f"   🎯 Target User ID: {notification.user_id}")
    logger.info(f"   🎯 Target Username: {notification.username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Obtener tokens FCM
            if notification.user_id:
                logger.info(f"🔍 Getting FCM tokens for user ID: {notification.user_id}")
                cursor.execute("SELECT fcm_token FROM test.np_devices WHERE user_id = :1", (notification.user_id,))
            elif notification.username:
                logger.info(f"🔍 Getting FCM tokens for username: {notification.username}")
                cursor.execute("""
                    SELECT d.fcm_token FROM test.np_devices d
                    JOIN test.np_users u ON d.user_id = u.id
                    WHERE u.username = :1
                """, (notification.username,))
            else:
                logger.info("🔍 Getting FCM tokens for ALL users")
                cursor.execute("SELECT fcm_token FROM test.np_devices")
            
            tokens = [row[0] for row in cursor.fetchall()]
            logger.info(f"📱 Found {len(tokens)} FCM tokens")
            
            if not tokens:
                logger.warning("⚠️ No devices found for push notification")
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No devices found"
                )
            
            # Log de tokens (parcial por seguridad)
            for i, token in enumerate(tokens):
                logger.info(f"   🔥 Token {i+1}: {token[:15]}...{token[-10:]}")
            
            # Enviar notificación push
            firebase_logger.info("🚀 Sending push notification via FCM...")
            
            success_count = 0
            failure_count = 0
            errors = []
            
            # Enviar a cada token individualmente (compatible con todas las versiones)
            for i, token in enumerate(tokens):
                try:
                    message = messaging.Message(
                        notification=messaging.Notification(
                            title=notification.title,
                            body=notification.body
                        ),
                        data={
                            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                            'type': 'push_notification'
                        },
                        token=token
                    )
                    
                    response = messaging.send(message)
                    firebase_logger.info(f"   ✅ Token {i+1} sent successfully: {response}")
                    success_count += 1
                    
                except Exception as token_error:
                    firebase_logger.error(f"   ❌ Token {i+1} failed: {str(token_error)}")
                    failure_count += 1
                    errors.append(str(token_error))
            
            firebase_logger.info(f"📊 FCM Response Summary:")
            firebase_logger.info(f"   ✅ Success: {success_count}")
            firebase_logger.info(f"   ❌ Failures: {failure_count}")
            
            if errors:
                firebase_logger.error(f"   💥 Errors: {errors}")
            
            logger.info(f"✅ Push notification sent successfully")
            return {
                "message": "Push notification sent",
                "success_count": success_count,
                "failure_count": failure_count,
                "tokens_used": len(tokens),
                "errors": errors if errors else None
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Push notification error: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send notification: {str(e)}"
        )

@app.post("/send-internal-notification")
async def send_internal_notification(notification: InternalNotification, current_user = Depends(verify_token)):
    username = current_user["sub"]
    
    logger.info(f"📢 Internal notification request from user: {username}")
    logger.info(f"   📝 Title: {notification.title}")
    logger.info(f"   📄 Message: {notification.message[:100]}...")
    logger.info(f"   🎯 Target User ID: {notification.user_id}")
    logger.info(f"   🎯 Target Username: {notification.username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Obtener user_ids objetivo
            user_ids = []
            if notification.user_id:
                logger.info(f"🔍 Targeting specific user ID: {notification.user_id}")
                user_ids = [notification.user_id]
            elif notification.username:
                logger.info(f"🔍 Looking up user by username: {notification.username}")
                cursor.execute("SELECT id FROM test.np_users WHERE username = :1", (notification.username,))
                user = cursor.fetchone()
                if user:
                    user_ids = [user[0]]
                    logger.info(f"👤 Found user ID: {user[0]}")
            else:
                logger.info("🔍 Targeting ALL users")
                cursor.execute("SELECT id FROM test.np_users")
                user_ids = [row[0] for row in cursor.fetchall()]
            
            logger.info(f"🎯 Targeting {len(user_ids)} users")
            
            if not user_ids:
                logger.warning("⚠️ No users found for internal notification")
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="No users found"
                )
            
            # Insertar notificaciones internas
            logger.info("💾 Creating internal notifications...")
            for user_id in user_ids:
                cursor.execute("""
                    INSERT INTO test.np_internal_notifications (user_id, title, message)
                    VALUES (:1, :2, :3)
                """, (user_id, notification.title, notification.message))
                logger.info(f"   ✅ Created notification for user ID: {user_id}")
            
            conn.commit()
            
            logger.info(f"✅ Internal notifications sent to {len(user_ids)} users")
            return {
                "message": "Internal notifications sent",
                "count": len(user_ids)
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Internal notification error: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send internal notification"
        )

@app.get("/internal-notifications")
async def get_internal_notifications(current_user = Depends(verify_token)):
    user_id = current_user["user_id"]
    username = current_user["sub"]
    
    logger.info(f"📋 Getting internal notifications for user: {username} (ID: {user_id})")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Usar TO_CHAR() para convertir CLOB a VARCHAR2 directamente en la query
            cursor.execute("""
                SELECT id, 
                       TO_CHAR(title) as title, 
                       TO_CHAR(message) as message, 
                       is_read, 
                       created_at
                FROM test.np_internal_notifications
                WHERE user_id = :1
                ORDER BY created_at DESC
            """, (user_id,))
            
            notifications = []
            for row in cursor.fetchall():
                # Ahora todos los campos deberían ser tipos primitivos
                notification_data = {
                    "id": int(row[0]) if row[0] is not None else 0,
                    "title": str(row[1]) if row[1] is not None else "",
                    "message": str(row[2]) if row[2] is not None else "",
                    "is_read": bool(row[3]) if row[3] is not None else False,
                    "created_at": row[4].isoformat() if row[4] is not None else None
                }
                notifications.append(notification_data)
                
                logger.info(f"   📄 Notification {notification_data['id']}: {notification_data['title'][:30]}...")
            
            unread_count = len([n for n in notifications if not n["is_read"]])
            logger.info(f"📊 Found {len(notifications)} notifications ({unread_count} unread) for {username}")
            
            # Crear respuesta explícita con tipos primitivos
            response_data = {
                "notifications": notifications
            }
            
            return response_data
            
    except Exception as e:
        logger.error(f"❌ Error getting notifications for {username}: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get notifications"
        )

@app.put("/internal-notifications/{notification_id}/read")
async def mark_notification_as_read(notification_id: int, current_user = Depends(verify_token)):
    user_id = current_user["user_id"]
    username = current_user["sub"]
    
    logger.info(f"✅ Marking notification {notification_id} as read for user: {username}")
    
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
                UPDATE test.np_internal_notifications 
                SET is_read = 1
                WHERE id = :1 AND user_id = :2
            """, (notification_id, user_id))
            
            if cursor.rowcount == 0:
                logger.warning(f"⚠️ Notification {notification_id} not found for user {username}")
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Notification not found"
                )
            
            conn.commit()
            logger.info(f"✅ Notification {notification_id} marked as read for {username}")
            return {"message": "Notification marked as read"}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Error marking notification as read: {e}")
        logger.error(f"📚 Traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to mark notification as read"
        )
    
@app.get("/health")
async def health_check():
    logger.info("🏥 Health check requested")
    
    status_info = {
        "environment": ENVIRONMENT,
        "timestamp": datetime.utcnow().isoformat()
    }
    
    # Test Oracle
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM dual")
            result = cursor.fetchone()
            status_info["oracle"] = {
                "status": "✅ Connected",
                "dsn": ORACLE_DSN,
                "user": ORACLE_USER,
                "test_query": result[0] if result else None
            }
            db_logger.info("✅ Oracle health check passed")
    except Exception as e:
        status_info["oracle"] = {
            "status": f"❌ Error: {str(e)}",
            "dsn": ORACLE_DSN,
            "user": ORACLE_USER
        }
        db_logger.error(f"❌ Oracle health check failed: {e}")
    
    # Test Firebase
    try:
        app_instance = firebase_admin.get_app()
        status_info["firebase"] = {
            "status": "✅ Initialized",
            "project_id": app_instance.project_id if hasattr(app_instance, 'project_id') else "unknown"
        }
        firebase_logger.info("✅ Firebase health check passed")
    except Exception as e:
        status_info["firebase"] = {
            "status": f"❌ Error: {str(e)}",
            "credentials_path": FIREBASE_CREDENTIALS_PATH
        }
        firebase_logger.error(f"❌ Firebase health check failed: {e}")
    
    # Configuration summary
    status_info["config"] = {
        "sender_id": SENDER_ID,
        "server_key_configured": bool(SERVER_KEY),
        "secret_key_configured": bool(SECRET_KEY),
        "host": HOST,
        "port": PORT
    }
    
    overall_status = "healthy" if all([
        "✅" in str(status_info["oracle"]["status"]),
        "✅" in str(status_info["firebase"]["status"])
    ]) else "unhealthy"
    
    logger.info(f"🏥 Health check result: {overall_status}")
    
    return status_info

if __name__ == "__main__":
    import uvicorn
    logger.info(f"🚀 Starting server in {ENVIRONMENT} mode...")
    logger.info(f"📊 Health check available at: http://{HOST}:{PORT}/health")
    logger.info(f"📖 API docs available at: http://{HOST}:{PORT}/docs")
    uvicorn.run(app, host=HOST, port=PORT)