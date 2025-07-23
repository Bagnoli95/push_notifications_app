-- ==========================================
-- CONSULTAS ÚTILES PARA ADMINISTRACIÓN
-- ==========================================

-- ==========================================
-- 1. CONSULTAS DE MONITOREO
-- ==========================================

-- Ver todos los usuarios registrados
SELECT 
    u.id,
    u.username,
    u.email,
    u.created_at,
    COUNT(d.id) as devices_count,
    COUNT(CASE WHEN d.is_active = 1 THEN 1 END) as active_devices
FROM users u
LEFT JOIN devices d ON u.id = d.user_id
GROUP BY u.id, u.username, u.email, u.created_at
ORDER BY u.created_at DESC;

-- Ver dispositivos activos por usuario
SELECT 
    u.username,
    d.device_id,
    d.device_name,
    d.fcm_token,
    d.last_used_at,
    d.is_active
FROM users u
JOIN devices d ON u.id = d.user_id
WHERE d.is_active = 1
ORDER BY u.username, d.last_used_at DESC;

-- Ver notificaciones internas no leídas por usuario
SELECT 
    u.username,
    COUNT(*) as unread_notifications
FROM users u
JOIN internal_notifications n ON u.id = n.user_id
WHERE n.is_read = 0
GROUP BY u.username
ORDER BY unread_notifications DESC;

-- Ver estadísticas generales
SELECT 
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM devices WHERE is_active = 1) as active_devices,
    (SELECT COUNT(*) FROM internal_notifications WHERE is_read = 0) as unread_notifications,
    (SELECT COUNT(*) FROM push_notification_log WHERE sent_at >= SYSDATE - 1) as push_sent_last_24h
FROM dual;

-- ==========================================
-- 2. CONSULTAS PARA TESTING
-- ==========================================

-- Buscar usuario para testing
SELECT 
    u.id,
    u.username,
    u.email,
    d.fcm_token,
    d.device_id
FROM users u
LEFT JOIN devices d ON u.id = d.user_id
WHERE u.username = 'admin' -- Cambiar por el usuario que quieras testear
AND d.is_active = 1;

-- Ver notificaciones de un usuario específico
SELECT 
    n.id,
    n.title,
    n.message,
    n.notification_type,
    n.priority_level,
    n.is_read,
    n.created_at,
    n.read_at
FROM internal_notifications n
JOIN users u ON n.user_id = u.id
WHERE u.username = 'admin' -- Cambiar por el usuario
ORDER BY n.created_at DESC;

-- ==========================================
-- 3. CONSULTAS DE LIMPIEZA
-- ==========================================

-- Limpiar dispositivos inactivos (más de 30 días sin uso)
UPDATE devices 
SET is_active = 0 
WHERE last_used_at < SYSDATE - 30
AND is_active = 1;

-- Eliminar notificaciones internas leídas más antiguas que 30 días
DELETE FROM internal_notifications 
WHERE is_read = 1 
AND read_at < SYSDATE - 30;

-- Limpiar logs de push notifications más antiguos que 7 días
DELETE FROM push_notification_log 
WHERE sent_at < SYSDATE - 7;

-- ==========================================
-- 4. CONSULTAS PARA INSERTAR DATOS DE PRUEBA
-- ==========================================

-- Insertar usuario de prueba
INSERT INTO users (username, email, password_hash) VALUES 
('testuser', 'test@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/Xn3rBUzKy');

-- Insertar notificación interna de prueba para todos los usuarios
INSERT INTO internal_notifications (user_id, title, message, notification_type, priority_level)
SELECT 
    u.id,
    'Notificación de Prueba',
    'Esta es una notificación de prueba para verificar que el sistema funciona correctamente. Fecha: ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS'),
    'test',
    1
FROM users u;

-- Insertar notificación de alta prioridad para un usuario específico
INSERT INTO internal_notifications (user_id, title, message, notification_type, priority_level) VALUES 
(1, 'Alerta Importante', 'Esta es una notificación de alta prioridad que requiere atención inmediata.', 'alert', 3);

-- ==========================================
-- 5. CONSULTAS DE ANÁLISIS
-- ==========================================

-- Usuarios más activos (por número de dispositivos)
SELECT 
    u.username,
    COUNT(d.id) as total_devices,
    COUNT(CASE WHEN d.is_active = 1 THEN 1 END) as active_devices,
    MAX(d.last_used_at) as last_activity
FROM users u
LEFT JOIN devices d ON u.id = d.user_id
GROUP BY u.username
ORDER BY active_devices DESC, last_activity DESC;

-- Análisis de notificaciones por tipo
SELECT 
    notification_type,
    priority_level,
    COUNT(*) as total,
    COUNT(CASE WHEN is_read = 1 THEN 1 END) as read_count,
    COUNT(CASE WHEN is_read = 0 THEN 1 END) as unread_count,
    ROUND(COUNT(CASE WHEN is_read = 1 THEN 1 END) * 100.0 / COUNT(*), 2) as read_percentage
FROM internal_notifications
GROUP BY notification_type, priority_level
ORDER BY priority_level DESC, total DESC;

-- Actividad por día (últimos 7 días)
SELECT 
    TO_CHAR(date_day, 'DD/MM/YYYY') as day,
    COALESCE(new_users, 0) as new_users,
    COALESCE(new_notifications, 0) as new_notifications,
    COALESCE(push_sent, 0) as push_sent
FROM (
    SELECT TRUNC(SYSDATE) - LEVEL + 1 as date_day
    FROM dual
    CONNECT BY LEVEL <= 7
) dates
LEFT JOIN (
    SELECT TRUNC(created_at) as day, COUNT(*) as new_users
    FROM users
    WHERE created_at >= SYSDATE - 7
    GROUP BY TRUNC(created_at)
) u ON dates.date_day = u.day
LEFT JOIN (
    SELECT TRUNC(created_at) as day, COUNT(*) as new_notifications
    FROM internal_notifications
    WHERE created_at >= SYSDATE - 7
    GROUP BY TRUNC(created_at)
) n ON dates.date_day = n.day
LEFT JOIN (
    SELECT TRUNC(sent_at) as day, COUNT(*) as push_sent
    FROM push_notification_log
    WHERE sent_at >= SYSDATE - 7
    GROUP BY TRUNC(sent_at)
) p ON dates.date_day = p.day
ORDER BY dates.date_day DESC;

-- ==========================================
-- 6. CONSULTAS DE MANTENIMIENTO
-- ==========================================

-- Verificar integridad referencial
SELECT 
    'devices' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN user_id NOT IN (SELECT id FROM users) THEN 1 END) as orphaned_records
FROM devices
UNION ALL
SELECT 
    'internal_notifications' as table_name,
    COUNT(*) as total_records,
    COUNT(CASE WHEN user_id NOT IN (SELECT id FROM users) THEN 1 END) as orphaned_records
FROM internal_notifications;

-- Ver el tamaño de las tablas
SELECT 
    segment_name as table_name,
    ROUND(bytes/1024/1024, 2) as size_mb,
    blocks,
    extents
FROM user_segments 
WHERE segment_type = 'TABLE'
AND segment_name IN ('USERS', 'DEVICES', 'INTERNAL_NOTIFICATIONS', 'PUSH_NOTIFICATION_LOG')
ORDER BY bytes DESC;

-- Recompilar objetos inválidos (si los hay)
BEGIN
    FOR cur IN (SELECT object_name, object_type FROM user_objects WHERE status = 'INVALID') LOOP
        BEGIN
            IF cur.object_type = 'TRIGGER' THEN
                EXECUTE IMMEDIATE 'ALTER TRIGGER ' || cur.object_name || ' COMPILE';
            ELSIF cur.object_type = 'PROCEDURE' THEN
                EXECUTE IMMEDIATE 'ALTER PROCEDURE ' || cur.object_name || ' COMPILE';
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error recompiling ' || cur.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
END;
/

COMMIT;