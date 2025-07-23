# 📡 Push Notifications API Documentation

## 📋 Información General

**Base URL:** `http://your-server-ip:8000`  
**Versión:** 1.0.0  
**Autenticación:** JWT Bearer Token  
**Content-Type:** `application/json`

---

## 🔐 Autenticación

La API utiliza JWT (JSON Web Tokens) para la autenticación. Después del login exitoso, incluye el token en el header `Authorization` de todas las requests protegidas:

```
Authorization: Bearer <your-jwt-token>
```

---

## 📚 Endpoints

### 1. 👤 **Registro de Usuario**

**POST** `/register`

Registra un nuevo usuario en el sistema.

#### Request Body
```json
{
  "username": "string",
  "email": "string",
  "password": "string"
}
```

#### Response Success (200)
```json
{
  "message": "User registered successfully"
}
```

#### Response Error (400)
```json
{
  "detail": "Username or email already registered"
}
```

#### Validaciones
- `username`: Requerido, único en el sistema
- `email`: Requerido, formato email válido, único
- `password`: Requerido, mínimo 6 caracteres

---

### 2. 🔑 **Login de Usuario**

**POST** `/login`

Autentica un usuario y devuelve un JWT token.

#### Request Body
```json
{
  "username": "string",
  "password": "string"
}
```

#### Response Success (200)
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user_id": 1,
  "username": "admin"
}
```

#### Response Error (401)
```json
{
  "detail": "Incorrect username or password"
}
```

#### Notas
- El token expira en 30 minutos por defecto
- Usar el token en el header `Authorization: Bearer <token>`

---

### 3. 📱 **Registro de Device**

**POST** `/register-device`

Registra o actualiza el token FCM de un dispositivo para recibir push notifications.

#### Headers
```
Authorization: Bearer <jwt-token>
```

#### Request Body
```json
{
  "fcm_token": "string",
  "device_id": "string"
}
```

#### Response Success (200)
```json
{
  "message": "Device registered successfully"
}
```

#### Response Error (401)
```json
{
  "detail": "Could not validate credentials"
}
```

#### Notas
- Se ejecuta automáticamente después del login exitoso en la app
- Si el device ya existe, actualiza solo el FCM token
- `device_id`: ID único del dispositivo Android

---

### 4. 🔔 **Enviar Push Notification**

**POST** `/send-push-notification`

Envía una notificación push nativa a través de Firebase Cloud Messaging.

#### Headers
```
Authorization: Bearer <jwt-token>
```

#### Request Body
```json
{
  "title": "string",
  "body": "string",
  "user_id": 1,              // Opcional: enviar a usuario específico
  "username": "admin"        // Opcional: enviar a username específico
}
```

#### Response Success (200)
```json
{
  "message": "Push notification sent",
  "success_count": 2,
  "failure_count": 0
}
```

#### Response Error (404)
```json
{
  "detail": "No devices found"
}
```

#### Response Error (500)
```json
{
  "detail": "Failed to send notification: <error_message>"
}
```

#### Comportamiento
- Si no se especifica `user_id` ni `username`, envía a todos los usuarios
- Si se especifica `user_id`, envía solo a ese usuario
- Si se especifica `username`, envía solo a ese username
- La notificación aparece como notificación nativa del sistema
- Al tocar la notificación, abre la app y navega a pantalla de detalle

---

### 5. 📢 **Enviar Notificación Interna**

**POST** `/send-internal-notification`

Envía una notificación interna que aparece en la campanita de la app.

#### Headers
```
Authorization: Bearer <jwt-token>
```

#### Request Body
```json
{
  "title": "string",
  "message": "string",
  "user_id": 1,              // Opcional: enviar a usuario específico
  "username": "admin"        // Opcional: enviar a username específico
}
```

#### Response Success (200)
```json
{
  "message": "Internal notifications sent",
  "count": 3
}
```

#### Response Error (404)
```json
{
  "detail": "No users found"
}
```

#### Comportamiento
- Si no se especifica `user_id` ni `username`, envía a todos los usuarios
- Las notificaciones se almacenan en la base de datos
- Aparecen en la campanita del header de la app
- No pasan por FCM, son internas de la aplicación

---

### 6. 📥 **Obtener Notificaciones Internas**

**GET** `/internal-notifications`

Obtiene todas las notificaciones internas del usuario autenticado.

#### Headers
```
Authorization: Bearer <jwt-token>
```

#### Response Success (200)
```json
{
  "notifications": [
    {
      "id": 1,
      "title": "Bienvenido",
      "message": "Gracias por registrarte en nuestra app",
      "is_read": false,
      "created_at": "2025-07-23T10:30:00"
    },
    {
      "id": 2,
      "title": "Nueva función disponible",
      "message": "Ahora puedes usar autenticación biométrica",
      "is_read": true,
      "created_at": "2025-07-22T15:45:00"
    }
  ]
}
```

#### Notas
- Las notificaciones se ordenan por fecha de creación (más recientes primero)
- Incluye tanto notificaciones leídas como no leídas
- La app usa este endpoint para mostrar el contenido de la campanita

---

### 7. ✅ **Marcar Notificación como Leída**

**PUT** `/internal-notifications/{notification_id}/read`

Marca una notificación interna específica como leída.

#### Headers
```
Authorization: Bearer <jwt-token>
```

#### Path Parameters
- `notification_id`: ID de la notificación a marcar como leída

#### Response Success (200)
```json
{
  "message": "Notification marked as read"
}
```

#### Response Error (404)
```json
{
  "detail": "Notification not found"
}
```

#### Notas
- Solo se pueden marcar como leídas las notificaciones del usuario autenticado
- Se ejecuta automáticamente cuando el usuario toca una notificación en la app

---

## 🔧 Códigos de Estado HTTP

| Código | Descripción |
|--------|-------------|
| 200 | OK - Operación exitosa |
| 400 | Bad Request - Datos inválidos o faltantes |
| 401 | Unauthorized - Token inválido o faltante |
| 404 | Not Found - Recurso no encontrado |
| 500 | Internal Server Error - Error del servidor |

---

## 🛡️ Seguridad

### Headers de Seguridad
Todas las requests protegidas requieren:
```
Authorization: Bearer <jwt-token>
Content-Type: application/json
```

### Validación de Tokens
- Los tokens JWT expiran en 30 minutos
- Si el token expira, la app redirige automáticamente al login
- Los tokens contienen información del usuario (`user_id`, `username`)

---

## 📱 Integración con Firebase

### Configuración Requerida
- **Firebase Project** con Cloud Messaging habilitado
- **Service Account Key** del proyecto Firebase
- **FCM Tokens** registrados por cada dispositivo

### Flujo de Push Notifications
1. App obtiene FCM token del dispositivo
2. App registra el token via `/register-device`
3. Backend usa el token para enviar notifications via FCM
4. FCM entrega la notificación al dispositivo
5. Usuario toca la notificación → app abre pantalla de detalle

---

## 🗄️ Base de Datos

### Tablas Utilizadas
- **users**: Información de usuarios
- **devices**: Tokens FCM y dispositivos registrados
- **internal_notifications**: Notificaciones internas
- **push_notification_log**: Log de push notifications enviadas

---

## 🧪 Testing

### Usuarios de Prueba
```json
{
  "username": "admin",
  "password": "admin123"
}
```

### Ejemplos de Curl

#### Login
```bash
curl -X POST "http://localhost:8000/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

#### Enviar Push Notification
```bash
curl -X POST "http://localhost:8000/send-push-notification" \
  -H "Authorization: Bearer <your-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Notification",
    "body": "This is a test push notification",
    "username": "admin"
  }'
```

#### Obtener Notificaciones Internas
```bash
curl -X GET "http://localhost:8000/internal-notifications" \
  -H "Authorization: Bearer <your-token>"
```

---

## ⚠️ Limitaciones y Consideraciones

### Rate Limiting
- No implementado en esta versión
- Considerar implementar para producción

### Logs y Monitoreo
- Push notifications se registran en `push_notification_log`
- Implementar logs adicionales según necesidades

### Escalabilidad
- Configurar connection pooling para Oracle en producción
- Considerar implementar caché para tokens FCM frecuentes

### Seguridad Adicional
- Implementar refresh tokens para sesiones largas
- Validar origen de las requests en producción
- Configurar CORS apropiadamente

---

## 📞 Soporte

Para dudas técnicas o problemas con la API, verificar:
1. **Logs del servidor**: Errores detallados en consola
2. **Base de datos**: Verificar integridad de datos
3. **Firebase Console**: Estado de las notificaciones FCM
4. **Token JWT**: Verificar validez y expiración

---

*Última actualización: Julio 2025*