# 📱 Push Notifications App

Una aplicación completa de notificaciones push construida con **Flutter** (frontend) y **Python FastAPI** (backend), usando **Oracle Database** y **Firebase Cloud Messaging**.

## 🎯 Descripción del Proyecto

Esta aplicación demuestra un sistema completo de notificaciones que incluye:

- **🔔 Notificaciones Push Nativas** - Notificaciones del sistema Android vía Firebase FCM
- **📢 Notificaciones Internas** - Sistema de notificaciones dentro de la app con campanita
- **🔐 Autenticación Biométrica** - Login con huella dactilar como alternativa
- **🏠 Dashboard Completo** - Vista del estado del sistema y gestión de notificaciones

---

## 🏗️ Arquitectura del Sistema

```
📱 Flutter App (Android APK)
         ↕ HTTP/JWT
🐍 FastAPI Backend (Python)
         ↕ cx_Oracle
🗄️ Oracle Database
         
🔥 Firebase Cloud Messaging
         ↕ Push Tokens
📱 Android Notifications
```

### Stack Tecnológico

| Componente | Tecnología | Versión |
|------------|------------|---------|
| **Frontend** | Flutter | 3.0+ |
| **Backend** | Python + FastAPI | 3.8+ |
| **Base de Datos** | Oracle Database | 11g+ |
| **Push Notifications** | Firebase FCM | Latest |
| **Autenticación** | JWT + Biometric | - |
| **State Management** | Provider Pattern | 6.1+ |

---

## 📋 Features Principales

### 🔐 **Autenticación**
- ✅ Login/Register con validación
- ✅ JWT tokens con expiración
- ✅ Autenticación biométrica (huella dactilar)
- ✅ Persistencia de sesión
- ✅ Auto-logout al expirar token

### 🔔 **Push Notifications**
- ✅ Notificaciones nativas de Android
- ✅ Envío individual o masivo
- ✅ Navegación automática al abrir
- ✅ Requerir login si sesión expirada
- ✅ Log completo de envíos

### 📢 **Notificaciones Internas**
- ✅ Campanita en header con contador
- ✅ Vista previa en dropdown menu
- ✅ Lista completa con scroll
- ✅ Marcar como leída automáticamente
- ✅ Navegación a detalle individual

### 📱 **Mobile App**
- ✅ APK instalable
- ✅ Registro automático de device
- ✅ Material Design 3
- ✅ Responsive UI
- ✅ Error handling completo

---

## 🚀 Quick Start

### 1. **Setup del Backend**
```bash
# Instalar dependencias
pip install -r requirements.txt

# Configurar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales

# Ejecutar servidor
python main.py
```

### 2. **Setup de Base de Datos**
```sql
-- Ejecutar DDL completo
sqlplus user/pass@database < create_tables.sql
```

### 3. **Setup del Frontend**
```bash
# Instalar dependencias
flutter pub get

# Configurar Firebase
# Colocar google-services.json en android/app/

# Cambiar IP del backend en services
# Generar APK
flutter build apk --release
```

### 4. **Configuración Firebase**
- Crear proyecto en Firebase Console
- Habilitar Cloud Messaging
- Descargar service account key para backend
- Descargar google-services.json para frontend

---

## 📚 Documentación Completa

### 📡 [**API Specification**](./docs/api_specs.md)
Documentación completa de todos los endpoints del backend:
- Autenticación y registro de usuarios
- Gestión de dispositivos y tokens FCM  
- Envío de push notifications
- Manejo de notificaciones internas
- Ejemplos de requests/responses
- Códigos de error y troubleshooting

### 📱 [**Frontend Specification**](./docs/front_spec.md)
Documentación técnica del desarrollo Flutter:
- Arquitectura y estructura del proyecto
- Sistema de autenticación biométrica
- Manejo de estado con Provider
- UI/UX y design system
- Configuración de build y deployment
- Testing y debugging guide

### 🗄️ [**Database Specification**](./docs/ddbb_spec.md)
Especificación completa de la base de datos Oracle:
- Esquema de tablas y relaciones
- DDL completo con triggers e índices
- Consultas optimizadas y análisis
- Estrategias de mantenimiento
- Seguridad y backup
- Troubleshooting de performance

---

## 🛠️ Configuración de Desarrollo

### **Prerequisitos**
- **Flutter SDK** 3.0+
- **Python** 3.8+
- **Oracle Database** 11g+
- **Firebase Project** con FCM habilitado
- **Android Studio/VS Code** con extensiones

### **Variables de Entorno**
```bash
# Backend (.env)
ORACLE_USER=your_oracle_user
ORACLE_PASSWORD=your_oracle_password  
ORACLE_DSN=localhost:1521/XE
SECRET_KEY=your_jwt_secret_key
FIREBASE_CREDENTIALS=path/to/service-account.json

# Frontend
BASE_URL=http://your-server-ip:8000
```

### **Archivos de Configuración Requeridos**
```
backend/
├── firebase-service-account-key.json    # Firebase Admin SDK
└── .env                                 # Variables de entorno

frontend/
├── android/app/google-services.json     # Firebase client config
└── lib/services/*                       # Actualizar BASE_URL
```

---

## 🧪 Testing

### **Usuario de Prueba**
```
Username: admin
Password: admin123
```

### **Flujo de Testing Completo**
1. **Login** con credenciales o biometría
2. **Verificar registro** automático de device
3. **Enviar push notification** desde backend
4. **Verificar notificación nativa** en Android
5. **Enviar notificación interna** desde backend  
6. **Verificar campanita** con contador
7. **Navegar a detalles** de notificaciones

---

## 📊 API Endpoints Summary

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| `POST` | `/register` | Registro de usuario | ❌ |
| `POST` | `/login` | Autenticación | ❌ |
| `POST` | `/register-device` | Registro FCM token | ✅ |
| `POST` | `/send-push-notification` | Enviar push | ✅ |
| `POST` | `/send-internal-notification` | Enviar interna | ✅ |
| `GET` | `/internal-notifications` | Listar internas | ✅ |
| `PUT` | `/internal-notifications/{id}/read` | Marcar leída | ✅ |

---

## 🗄️ Database Tables Summary

| Tabla | Descripción | Registros Típicos |
|-------|-------------|-------------------|
| `users` | Usuarios registrados | ~100-1000 |
| `devices` | Dispositivos y tokens FCM | ~100-5000 |  
| `internal_notifications` | Notificaciones internas | ~1000-10000 |
| `push_notification_log` | Auditoría de push | ~1000-50000 |

---

## 📱 App Screens Overview

| Pantalla | Función | Features |
|----------|---------|----------|
| **Login** | Autenticación | Login/Register, Biometría |
| **Home** | Dashboard principal | Estado, Campanita, Menú |
| **Notification Detail** | Detalle de notificación | Push/Interna, Metadata |

---

## 🚨 Troubleshooting Rápido

### **Backend Issues**
```bash
# Verificar conexión Oracle
python -c "import cx_Oracle; print('Oracle OK')"

# Test Firebase credentials  
python -c "import firebase_admin; print('Firebase OK')"

# Ver logs del servidor
tail -f server.log
```

### **Frontend Issues**
```bash
# Limpiar build
flutter clean && flutter pub get

# Debug en dispositivo
flutter run --verbose

# Ver logs
flutter logs
```

### **Database Issues**
```sql
-- Verificar tablas
SELECT table_name FROM user_tables;

-- Verificar conexiones activas
SELECT count(*) FROM v$session WHERE username = 'PUSH_APP_USER';
```

---

## 🔧 Deployment Checklist

### **Pre-Production**
- [ ] Cambiar URLs de desarrollo por producción
- [ ] Configurar variables de entorno de producción
- [ ] Ejecutar DDL en base de datos de producción
- [ ] Configurar Firebase project de producción
- [ ] Testing completo en dispositivos físicos

### **Production Ready**
- [ ] Build APK release firmado
- [ ] Configurar HTTPS en backend
- [ ] Implementar connection pooling
- [ ] Configurar backups automáticos
- [ ] Monitoreo y alertas

---

## 📈 Métricas y Monitoreo

### **KPIs Principales**
- **Usuarios Activos Diarios**: Login exitosos por día
- **Rate de Entrega Push**: % de notificaciones entregadas exitosamente  
- **Engagement**: % de notificaciones internas leídas
- **Performance**: Tiempo de respuesta promedio de APIs

### **Logs a Monitorear**
- Errores de autenticación
- Fallos de conexión a Oracle
- Errores de FCM
- Requests lentas (>2s)

---

## 🤝 Contribución

Este proyecto está diseñado como una **demo completa** y **referencia técnica** para implementar sistemas de notificaciones push en aplicaciones móviles.

### **Para Extender el Proyecto**
1. Fork el repositorio
2. Crear feature branch
3. Implementar mejoras
4. Actualizar documentación correspondiente
5. Submit pull request

---

## 📞 Soporte

### **Documentación Técnica**
- **[API Specs](./docs/api_specs.md)** - Para desarrollo backend e integración
- **[Frontend Specs](./docs/front_spec.md)** - Para desarrollo Flutter y UI
- **[Database Specs](./docs/ddbb_spec.md)** - Para administración de BD y queries

### **Issues Comunes**
Ver las secciones de **Troubleshooting** en cada documento específico para soluciones detalladas.

---

## 📄 Licencia

Este proyecto es una demostración técnica y está disponible para fines educativos y de referencia.

---

## 🔄 Updates y Versioning

**Versión Actual**: 1.0.0  
**Última Actualización**: Julio 2025

### **Roadmap Futuro**
- [ ] Soporte para iOS
- [ ] Notificaciones programadas
- [ ] Dashboard web de administración
- [ ] Métricas avanzadas y analytics
- [ ] Soporte multi-idioma

---

**💡 ¿Listo para comenzar?** Revisa la documentación específica de cada componente y sigue el Quick Start guide para tener la aplicación funcionando en minutos.

*Construido con ❤️ para demostrar las mejores prácticas en desarrollo de aplicaciones móviles con notificaciones push.*