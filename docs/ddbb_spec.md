# 🗄️ Push Notifications App - Database Specification

## 📋 Información General

**SGBD:** Oracle Database 11g+  
**Encoding:** UTF-8  
**Connection Pool:** cx_Oracle  
**ORM:** Raw SQL (FastAPI + cx_Oracle)  

---

## 🏗️ Arquitectura de Base de Datos

### Esquema General
```
PUSH_NOTIFICATIONS_SCHEMA
├── USERS                    # Usuarios registrados
├── DEVICES                  # Dispositivos y tokens FCM  
├── INTERNAL_NOTIFICATIONS   # Notificaciones internas
└── PUSH_NOTIFICATION_LOG    # Auditoría de push notifications
```

### Relaciones
```
USERS (1) ──── (N) DEVICES
USERS (1) ──── (N) INTERNAL_NOTIFICATIONS  
USERS (1) ──── (N) PUSH_NOTIFICATION_LOG
DEVICES (1) ──── (N) PUSH_NOTIFICATION_LOG
```

---

## 📊 Tablas Principales

### 1. 👤 **USERS**
Almacena información de usuarios registrados en la aplicación.

```sql
CREATE TABLE users (
    id NUMBER(10) PRIMARY KEY,
    username VARCHAR2(50) NOT NULL UNIQUE,
    email VARCHAR2(100) NOT NULL UNIQUE,
    password_hash VARCHAR2(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Campos
| Campo | Tipo | Descripción | Constraints |
|-------|------|-------------|-------------|
| `id` | NUMBER(10) | ID único del usuario | PRIMARY KEY, AUTO_INCREMENT |
| `username` | VARCHAR2(50) | Nombre de usuario | NOT NULL, UNIQUE |
| `email` | VARCHAR2(100) | Email del usuario | NOT NULL, UNIQUE |
| `password_hash` | VARCHAR2(255) | Hash bcrypt de la contraseña | NOT NULL |
| `created_at` | TIMESTAMP | Fecha de registro | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TIMESTAMP | Última actualización | AUTO_UPDATE |

#### Índices
- `idx_users_username` en `username`
- `idx_users_email` en `email`

#### Triggers
- `trg_users_id` - Auto-incremento de ID
- `trg_users_updated_at` - Actualización automática de timestamp

---

### 2. 📱 **DEVICES**
Almacena información de dispositivos registrados y tokens FCM.

```sql
CREATE TABLE devices (
    id NUMBER(10) PRIMARY KEY,
    user_id NUMBER(10) NOT NULL,
    device_id VARCHAR2(255) NOT NULL,
    fcm_token VARCHAR2(500) NOT NULL,
    device_name VARCHAR2(100),
    device_model VARCHAR2(100),
    os_version VARCHAR2(50),
    app_version VARCHAR2(20),
    is_active NUMBER(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_devices_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE
);
```

#### Campos
| Campo | Tipo | Descripción | Constraints |
|-------|------|-------------|-------------|
| `id` | NUMBER(10) | ID único del dispositivo | PRIMARY KEY, AUTO_INCREMENT |
| `user_id` | NUMBER(10) | ID del usuario propietario | FK → users.id, NOT NULL |
| `device_id` | VARCHAR2(255) | ID único del dispositivo Android | NOT NULL |
| `fcm_token` | VARCHAR2(500) | Token de Firebase Cloud Messaging | NOT NULL |
| `device_name` | VARCHAR2(100) | Nombre del dispositivo | NULLABLE |
| `device_model` | VARCHAR2(100) | Modelo del dispositivo | NULLABLE |
| `os_version` | VARCHAR2(50) | Versión del sistema operativo | NULLABLE |
| `app_version` | VARCHAR2(20) | Versión de la aplicación | NULLABLE |
| `is_active` | NUMBER(1) | Estado activo (1) o inactivo (0) | DEFAULT 1 |
| `created_at` | TIMESTAMP | Fecha de registro | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TIMESTAMP | Última actualización | AUTO_UPDATE |
| `last_used_at` | TIMESTAMP | Último uso del dispositivo | DEFAULT CURRENT_TIMESTAMP |

#### Índices
- `idx_devices_user_id` en `user_id`
- `idx_devices_device_id` en `device_id`
- `idx_devices_fcm_token` en `fcm_token`
- `idx_devices_user_device` en `(user_id, device_id)` UNIQUE

#### Reglas de Negocio
- Un usuario puede tener múltiples dispositivos
- Un dispositivo puede tener solo un token FCM activo
- Cuando se actualiza un token FCM, el anterior se invalida

---

### 3. 📢 **INTERNAL_NOTIFICATIONS**
Almacena notificaciones internas que aparecen en la campanita de la app.

```sql
CREATE TABLE internal_notifications (
    id NUMBER(10) PRIMARY KEY,
    user_id NUMBER(10) NOT NULL,
    title VARCHAR2(255) NOT NULL,
    message CLOB NOT NULL,
    notification_type VARCHAR2(50) DEFAULT 'info',
    priority_level NUMBER(1) DEFAULT 1,
    is_read NUMBER(1) DEFAULT 0,
    read_at TIMESTAMP,
    expires_at TIMESTAMP,
    metadata CLOB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_internal_notifications_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE
);
```

#### Campos
| Campo | Tipo | Descripción | Constraints |
|-------|------|-------------|-------------|
| `id` | NUMBER(10) | ID único de la notificación | PRIMARY KEY, AUTO_INCREMENT |
| `user_id` | NUMBER(10) | ID del usuario destinatario | FK → users.id, NOT NULL |
| `title` | VARCHAR2(255) | Título de la notificación | NOT NULL |
| `message` | CLOB | Contenido de la notificación | NOT NULL |
| `notification_type` | VARCHAR2(50) | Tipo de notificación | DEFAULT 'info' |
| `priority_level` | NUMBER(1) | Nivel de prioridad (1=Baja, 2=Media, 3=Alta) | DEFAULT 1 |
| `is_read` | NUMBER(1) | Estado leído (1) o no leído (0) | DEFAULT 0 |
| `read_at` | TIMESTAMP | Fecha y hora de lectura | NULLABLE |
| `expires_at` | TIMESTAMP | Fecha de expiración | NULLABLE |
| `metadata` | CLOB | Datos adicionales en JSON | NULLABLE |
| `created_at` | TIMESTAMP | Fecha de creación | DEFAULT CURRENT_TIMESTAMP |
| `updated_at` | TIMESTAMP | Última actualización | AUTO_UPDATE |

#### Índices
- `idx_internal_notifications_user_id` en `user_id`
- `idx_internal_notifications_is_read` en `is_read`
- `idx_internal_notifications_created_at` en `created_at DESC`
- `idx_internal_notifications_user_read` en `(user_id, is_read)`
- `idx_internal_notifications_priority` en `(priority_level, created_at DESC)`

#### Types de Notificación
- `info` - Información general
- `welcome` - Mensaje de bienvenida
- `alert` - Alerta importante
- `update` - Actualización de sistema
- `test` - Notificación de prueba

---

### 4. 📊 **PUSH_NOTIFICATION_LOG**
Tabla de auditoría para registrar el envío de notificaciones push.

```sql
CREATE TABLE push_notification_log (
    id NUMBER(10) PRIMARY KEY,
    user_id NUMBER(10),
    device_id NUMBER(10),
    title VARCHAR2(255) NOT NULL,
    body CLOB NOT NULL,
    fcm_message_id VARCHAR2(255),
    status VARCHAR2(20) DEFAULT 'sent',
    response_data CLOB,
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,
    error_message VARCHAR2(500),
    CONSTRAINT fk_push_log_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_push_log_device_id FOREIGN KEY (device_id) 
        REFERENCES devices(id) ON DELETE SET NULL
);
```

#### Campos
| Campo | Tipo | Descripción | Constraints |
|-------|------|-------------|-------------|
| `id` | NUMBER(10) | ID único del log | PRIMARY KEY, AUTO_INCREMENT |
| `user_id` | NUMBER(10) | ID del usuario destinatario | FK → users.id, NULLABLE |
| `device_id` | NUMBER(10) | ID del dispositivo destinatario | FK → devices.id, NULLABLE |
| `title` | VARCHAR2(255) | Título de la notificación | NOT NULL |
| `body` | CLOB | Contenido de la notificación | NOT NULL |
| `fcm_message_id` | VARCHAR2(255) | ID del mensaje en FCM | NULLABLE |
| `status` | VARCHAR2(20) | Estado del envío | DEFAULT 'sent' |
| `response_data` | CLOB | Respuesta completa de FCM | NULLABLE |
| `sent_at` | TIMESTAMP | Fecha y hora de envío | DEFAULT CURRENT_TIMESTAMP |
| `delivered_at` | TIMESTAMP | Fecha y hora de entrega | NULLABLE |
| `error_message` | VARCHAR2(500) | Mensaje de error si falló | NULLABLE |

#### Estados Posibles
- `sent` - Enviado a FCM
- `delivered` - Entregado al dispositivo
- `failed` - Falló el envío

---

## 🔧 Secuencias y Triggers

### Secuencias para Auto-incremento
```sql
CREATE SEQUENCE seq_users_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_devices_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_internal_notifications_id START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_push_notification_log_id START WITH 1 INCREMENT BY 1;
```

### Triggers Principales
```sql
-- Auto-incremento de IDs
CREATE OR REPLACE TRIGGER trg_users_id
    BEFORE INSERT ON users FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_users_id.NEXTVAL;
    END IF;
END;

-- Actualización automática de timestamps
CREATE OR REPLACE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users FOR EACH ROW
BEGIN
    :NEW.updated_at := CURRENT_TIMESTAMP;
END;

-- Marcar read_at automáticamente
CREATE OR REPLACE TRIGGER trg_internal_notifications_updated_at
    BEFORE UPDATE ON internal_notifications FOR EACH ROW
BEGIN
    :NEW.updated_at := CURRENT_TIMESTAMP;
    IF :OLD.is_read = 0 AND :NEW.is_read = 1 THEN
        :NEW.read_at := CURRENT_TIMESTAMP;
    END IF;
END;
```

---

## 📈 Consultas de Performance

### Consultas Optimizadas Frecuentes

#### 1. Login de Usuario
```sql
SELECT id, username, password_hash 
FROM users 
WHERE username = :username;
```

#### 2. Obtener Tokens FCM de Usuario
```sql
SELECT fcm_token 
FROM devices 
WHERE user_id = :user_id 
AND is_active = 1;
```

#### 3. Notificaciones No Leídas
```sql
SELECT id, title, message, created_at
FROM internal_notifications
WHERE user_id = :user_id 
AND is_read = 0
ORDER BY created_at DESC;
```

#### 4. Dashboard de Estadísticas
```sql
SELECT 
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM devices WHERE is_active = 1) as active_devices,
    (SELECT COUNT(*) FROM internal_notifications WHERE is_read = 0) as unread_notifications
FROM dual;
```

---

## 🔍 Análisis y Monitoreo

### Métricas Clave

#### Usuarios Activos
```sql
SELECT 
    COUNT(DISTINCT u.id) as active_users
FROM users u
JOIN devices d ON u.id = d.user_id
WHERE d.last_used_at >= SYSDATE - 7  -- Últimos 7 días
AND d.is_active = 1;
```

#### Notificaciones por Tipo
```sql
SELECT 
    notification_type,
    COUNT(*) as total,
    COUNT(CASE WHEN is_read = 1 THEN 1 END) as read_count,
    ROUND(COUNT(CASE WHEN is_read = 1 THEN 1 END) * 100.0 / COUNT(*), 2) as read_percentage
FROM internal_notifications
WHERE created_at >= SYSDATE - 30  -- Último mes
GROUP BY notification_type
ORDER BY total DESC;
```

#### Éxito de Push Notifications
```sql
SELECT 
    status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM push_notification_log
WHERE sent_at >= SYSDATE - 7  -- Última semana
GROUP BY status;
```

---

## 🛠️ Mantenimiento de Base de Datos

### Limpieza Automática

#### Script de Limpieza Semanal
```sql
-- Desactivar dispositivos sin uso por 30 días
UPDATE devices 
SET is_active = 0 
WHERE last_used_at < SYSDATE - 30
AND is_active = 1;

-- Eliminar notificaciones leídas muy antiguas
DELETE FROM internal_notifications 
WHERE is_read = 1 
AND read_at < SYSDATE - 90;  -- 3 meses

-- Limpiar logs antiguos
DELETE FROM push_notification_log 
WHERE sent_at < SYSDATE - 30;  -- 1 mes
```

### Backup Strategy
```sql
-- Export de datos críticos
expdp system/password directory=DATA_PUMP_DIR dumpfile=push_app_backup.dmp 
      schemas=PUSH_APP_SCHEMA compression=all

-- Backup de configuración
SELECT table_name, num_rows FROM user_tables;
SELECT sequence_name, last_number FROM user_sequences;
```

---

## 📊 Indices y Optimización

### Plan de Indexación
```sql
-- Índices principales (ya creados)
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_devices_user_id ON devices(user_id);
CREATE INDEX idx_internal_notifications_user_read ON internal_notifications(user_id, is_read);

-- Índices adicionales para performance
CREATE INDEX idx_devices_last_used ON devices(last_used_at) WHERE is_active = 1;
CREATE INDEX idx_notifications_type_priority ON internal_notifications(notification_type, priority_level);
CREATE INDEX idx_push_log_status_date ON push_notification_log(status, sent_at);
```

### Estadísticas de Tablas
```sql
-- Actualizar estadísticas para el optimizador
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS('PUSH_APP_SCHEMA', 'USERS');
    DBMS_STATS.GATHER_TABLE_STATS('PUSH_APP_SCHEMA', 'DEVICES');
    DBMS_STATS.GATHER_TABLE_STATS('PUSH_APP_SCHEMA', 'INTERNAL_NOTIFICATIONS');
    DBMS_STATS.GATHER_TABLE_STATS('PUSH_APP_SCHEMA', 'PUSH_NOTIFICATION_LOG');
END;
/
```

---

## 🔐 Seguridad de Base de Datos

### Usuarios y Privilegios
```sql
-- Usuario de aplicación con privilegios mínimos
CREATE USER push_app_user IDENTIFIED BY "secure_password";

GRANT CONNECT TO push_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON users TO push_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON devices TO push_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON internal_notifications TO push_app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON push_notification_log TO push_app_user;

-- Solo SELECT en vistas de estadísticas
GRANT SELECT ON user_tables TO push_app_user;
GRANT SELECT ON user_sequences TO push_app_user;
```

### Auditoría
```sql
-- Habilitar auditoría en tablas críticas
AUDIT INSERT, UPDATE, DELETE ON users;
AUDIT INSERT, UPDATE, DELETE ON devices;
```

---

## 🚨 Troubleshooting

### Problemas Comunes

#### 1. Conexiones Agotadas
```sql
-- Ver conexiones activas
SELECT username, count(*) 
FROM v$session 
WHERE username = 'PUSH_APP_USER'
GROUP BY username;

-- Configurar connection pool
ALTER SYSTEM SET processes=300 SCOPE=SPFILE;
```

#### 2. Bloqueos de Tabla
```sql
-- Identificar bloqueos
SELECT s.sid, s.serial#, s.username, s.program, s.machine, s.logon_time
FROM v$session s, v$lock l, dba_objects o
WHERE s.sid = l.sid
AND l.id1 = o.object_id
AND o.object_name IN ('USERS', 'DEVICES', 'INTERNAL_NOTIFICATIONS');
```

#### 3. Performance Lenta
```sql
-- Top queries lentas
SELECT sql_text, executions, disk_reads, buffer_gets
FROM v$sql 
WHERE sql_text LIKE '%users%' OR sql_text LIKE '%devices%'
ORDER BY disk_reads DESC;
```

---

## 📋 Checklist de Deployment

### Pre-Deployment
- [ ] Crear usuario de base de datos
- [ ] Ejecutar DDL completo
- [ ] Verificar secuencias e índices
- [ ] Cargar datos de prueba
- [ ] Testear conexión desde aplicación

### Post-Deployment
- [ ] Verificar logs de aplicación
- [ ] Monitorear performance de queries
- [ ] Configurar backup automático
- [ ] Establecer alertas de monitoreo

---

## 📞 Soporte de Base de Datos

### Contactos de Escalación
- **DBA Principal**: Para problemas de performance y configuración
- **DevOps**: Para deployment y backup
- **Development Team**: Para cambios de esquema

### Logs a Monitorear
- Oracle Alert Log
- Application connection errors
- Failed login attempts
- Long-running queries

---

*Última actualización: Julio 2025*