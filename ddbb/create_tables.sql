-- ==========================================
-- DDL para Push Notifications App
-- Base de datos: Oracle
-- ==========================================

-- Crear secuencias para los IDs (Oracle tradicional)
CREATE SEQUENCE seq_users_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_devices_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_internal_notifications_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- ==========================================
-- Tabla: USERS
-- Almacena información de usuarios registrados
-- ==========================================
CREATE TABLE users (
    id NUMBER(10) PRIMARY KEY,
    username VARCHAR2(50) NOT NULL UNIQUE,
    email VARCHAR2(100) NOT NULL UNIQUE,
    password_hash VARCHAR2(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger para auto-incrementar ID
CREATE OR REPLACE TRIGGER trg_users_id
    BEFORE INSERT ON users
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_users_id.NEXTVAL;
    END IF;
END;
/

-- Trigger para actualizar updated_at
CREATE OR REPLACE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
BEGIN
    :NEW.updated_at := CURRENT_TIMESTAMP;
END;
/

-- Índices para optimizar consultas
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- ==========================================
-- Tabla: DEVICES
-- Almacena tokens FCM y información de dispositivos
-- ==========================================
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

-- Trigger para auto-incrementar ID
CREATE OR REPLACE TRIGGER trg_devices_id
    BEFORE INSERT ON devices
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_devices_id.NEXTVAL;
    END IF;
END;
/

-- Trigger para actualizar updated_at
CREATE OR REPLACE TRIGGER trg_devices_updated_at
    BEFORE UPDATE ON devices
    FOR EACH ROW
BEGIN
    :NEW.updated_at := CURRENT_TIMESTAMP;
END;
/

-- Índices para optimizar consultas
CREATE INDEX idx_devices_user_id ON devices(user_id);
CREATE INDEX idx_devices_device_id ON devices(device_id);
CREATE INDEX idx_devices_fcm_token ON devices(fcm_token);
CREATE UNIQUE INDEX idx_devices_user_device ON devices(user_id, device_id);

-- ==========================================
-- Tabla: INTERNAL_NOTIFICATIONS
-- Almacena notificaciones internas de la app
-- ==========================================
CREATE TABLE internal_notifications (
    id NUMBER(10) PRIMARY KEY,
    user_id NUMBER(10) NOT NULL,
    title VARCHAR2(255) NOT NULL,
    message CLOB NOT NULL,
    notification_type VARCHAR2(50) DEFAULT 'info',
    priority_level NUMBER(1) DEFAULT 1, -- 1=Low, 2=Medium, 3=High
    is_read NUMBER(1) DEFAULT 0,
    read_at TIMESTAMP,
    expires_at TIMESTAMP,
    metadata CLOB, -- JSON adicional si necesitas
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_internal_notifications_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_is_read CHECK (is_read IN (0, 1)),
    CONSTRAINT chk_priority_level CHECK (priority_level IN (1, 2, 3))
);

-- Trigger para auto-incrementar ID
CREATE OR REPLACE TRIGGER trg_internal_notifications_id
    BEFORE INSERT ON internal_notifications
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_internal_notifications_id.NEXTVAL;
    END IF;
END;
/

-- Trigger para actualizar updated_at y read_at
CREATE OR REPLACE TRIGGER trg_internal_notifications_updated_at
    BEFORE UPDATE ON internal_notifications
    FOR EACH ROW
BEGIN
    :NEW.updated_at := CURRENT_TIMESTAMP;
    
    -- Si se marca como leída, actualizar read_at
    IF :OLD.is_read = 0 AND :NEW.is_read = 1 THEN
        :NEW.read_at := CURRENT_TIMESTAMP;
    END IF;
END;
/

-- Índices para optimizar consultas
CREATE INDEX idx_internal_notifications_user_id ON internal_notifications(user_id);
CREATE INDEX idx_internal_notifications_is_read ON internal_notifications(is_read);
CREATE INDEX idx_internal_notifications_created_at ON internal_notifications(created_at DESC);
CREATE INDEX idx_internal_notifications_user_read ON internal_notifications(user_id, is_read);
CREATE INDEX idx_internal_notifications_priority ON internal_notifications(priority_level, created_at DESC);

-- ==========================================
-- Tabla: PUSH_NOTIFICATION_LOG (Opcional)
-- Para auditoría de notificaciones push enviadas
-- ==========================================
CREATE TABLE push_notification_log (
    id NUMBER(10) PRIMARY KEY,
    user_id NUMBER(10),
    device_id NUMBER(10),
    title VARCHAR2(255) NOT NULL,
    body CLOB NOT NULL,
    fcm_message_id VARCHAR2(255),
    status VARCHAR2(20) DEFAULT 'sent', -- sent, delivered, failed
    response_data CLOB, -- Respuesta de FCM
    sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    delivered_at TIMESTAMP,
    error_message VARCHAR2(500),
    CONSTRAINT fk_push_log_user_id FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT fk_push_log_device_id FOREIGN KEY (device_id) 
        REFERENCES devices(id) ON DELETE SET NULL,
    CONSTRAINT chk_push_status CHECK (status IN ('sent', 'delivered', 'failed'))
);

-- Crear secuencia para push_notification_log
CREATE SEQUENCE seq_push_notification_log_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- Trigger para auto-incrementar ID
CREATE OR REPLACE TRIGGER trg_push_notification_log_id
    BEFORE INSERT ON push_notification_log
    FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        :NEW.id := seq_push_notification_log_id.NEXTVAL;
    END IF;
END;
/

-- Índices para la tabla de log
CREATE INDEX idx_push_log_user_id ON push_notification_log(user_id);
CREATE INDEX idx_push_log_device_id ON push_notification_log(device_id);
CREATE INDEX idx_push_log_sent_at ON push_notification_log(sent_at DESC);
CREATE INDEX idx_push_log_status ON push_notification_log(status);

-- ==========================================
-- Comentarios en las tablas
-- ==========================================
COMMENT ON TABLE users IS 'Usuarios registrados en la aplicación';
COMMENT ON COLUMN users.id IS 'ID único del usuario';
COMMENT ON COLUMN users.username IS 'Nombre de usuario único';
COMMENT ON COLUMN users.email IS 'Email único del usuario';
COMMENT ON COLUMN users.password_hash IS 'Hash bcrypt de la contraseña';

COMMENT ON TABLE devices IS 'Dispositivos registrados para notificaciones push';
COMMENT ON COLUMN devices.fcm_token IS 'Token de Firebase Cloud Messaging';
COMMENT ON COLUMN devices.device_id IS 'ID único del dispositivo';
COMMENT ON COLUMN devices.is_active IS '1 = activo, 0 = inactivo';

COMMENT ON TABLE internal_notifications IS 'Notificaciones internas de la aplicación';
COMMENT ON COLUMN internal_notifications.priority_level IS '1=Baja, 2=Media, 3=Alta';
COMMENT ON COLUMN internal_notifications.is_read IS '1 = leída, 0 = no leída';
COMMENT ON COLUMN internal_notifications.metadata IS 'Datos adicionales en formato JSON';

COMMENT ON TABLE push_notification_log IS 'Log de notificaciones push enviadas';

-- ==========================================
-- Datos de prueba (Opcional)
-- ==========================================

-- Usuario de prueba
INSERT INTO users (username, email, password_hash) VALUES 
('admin', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/Xn3rBUzKy'); -- password: admin123

-- Notificación interna de bienvenida
INSERT INTO internal_notifications (user_id, title, message, notification_type, priority_level) VALUES 
(1, '¡Bienvenido!', 'Gracias por registrarte en nuestra app de notificaciones push. Tu cuenta ha sido creada exitosamente.', 'welcome', 2);

COMMIT;

-- ==========================================
-- Verificar que las tablas se crearon correctamente
-- ==========================================
SELECT table_name, num_rows 
FROM user_tables 
WHERE table_name IN ('USERS', 'DEVICES', 'INTERNAL_NOTIFICATIONS', 'PUSH_NOTIFICATION_LOG')
ORDER BY table_name;