#!/usr/bin/env python3
"""
Test Firebase Configuration
Verifica la configuración de Firebase y FCM
"""

import firebase_admin
from firebase_admin import credentials, messaging
import os
import json
from dotenv import load_dotenv
from datetime import datetime

# Cargar variables de entorno
load_dotenv()

# Configuración desde .env
SENDER_ID = int(os.getenv("SENDER_ID", "0"))
SERVER_KEY = os.getenv("SERVER_KEY", "")
FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "./push-notifications-app.json")

def test_credentials_file():
    """Test de archivo de credenciales Firebase"""
    print("🔍 Testing Firebase Credentials File...")
    print(f"📍 Path: {FIREBASE_CREDENTIALS_PATH}")
    print("-" * 50)
    
    # Verificar que el archivo existe
    if not os.path.exists(FIREBASE_CREDENTIALS_PATH):
        print(f"❌ Error: Credentials file not found at {FIREBASE_CREDENTIALS_PATH}")
        return False
    
    print("✅ Credentials file exists")
    
    # Verificar que es un JSON válido
    try:
        with open(FIREBASE_CREDENTIALS_PATH, 'r') as f:
            cred_data = json.load(f)
        
        print("✅ Credentials file is valid JSON")
        
        # Verificar campos requeridos
        required_fields = [
            'type', 'project_id', 'private_key_id', 
            'private_key', 'client_email', 'client_id'
        ]
        
        missing_fields = []
        for field in required_fields:
            if field not in cred_data:
                missing_fields.append(field)
            else:
                # Mostrar algunos valores (sin exponer keys privadas)
                if field in ['project_id', 'client_email', 'type']:
                    print(f"📊 {field}: {cred_data[field]}")
                else:
                    print(f"✅ {field}: [CONFIGURED]")
        
        if missing_fields:
            print(f"❌ Missing required fields: {missing_fields}")
            return False
        
        print("✅ All required fields present")
        
        # Verificar el project_id vs SENDER_ID
        project_number = cred_data.get('project_number')
        if project_number:
            print(f"📊 project_number: {project_number}")
            if int(project_number) == SENDER_ID:
                print("✅ project_number matches SENDER_ID")
            else:
                print(f"⚠️ project_number ({project_number}) doesn't match SENDER_ID ({SENDER_ID})")
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON in credentials file: {e}")
        return False
    except Exception as e:
        print(f"❌ Error reading credentials file: {e}")
        return False

def test_firebase_initialization():
    """Test de inicialización de Firebase Admin SDK"""
    print("\n🚀 Testing Firebase Admin SDK Initialization...")
    print("-" * 50)
    
    try:
        # Verificar si ya está inicializado
        try:
            app = firebase_admin.get_app()
            print("ℹ️ Firebase app already initialized")
            firebase_admin.delete_app(app)
            print("🔄 Deleted existing app for clean test")
        except ValueError:
            print("ℹ️ No existing Firebase app found")
        
        # Inicializar Firebase
        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
        app = firebase_admin.initialize_app(cred)
        
        print("✅ Firebase Admin SDK initialized successfully")
        print(f"📊 Project ID: {cred.project_id}")
        
        # Verificar que la app está activa
        current_app = firebase_admin.get_app()
        if current_app:
            print("✅ Firebase app is active and accessible")
            return True
        else:
            print("❌ Firebase app initialization failed")
            return False
            
    except Exception as e:
        print(f"❌ Error initializing Firebase: {e}")
        return False

def test_fcm_service():
    """Test del servicio Firebase Cloud Messaging"""
    print("\n📱 Testing Firebase Cloud Messaging Service...")
    print("-" * 50)
    
    try:
        # Verificar que Firebase esté inicializado
        try:
            firebase_admin.get_app()
        except ValueError:
            print("⚠️ Firebase not initialized, initializing now...")
            cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
        
        # Test de creación de mensaje (sin enviar)
        test_message = messaging.Message(
            notification=messaging.Notification(
                title="Test Notification",
                body="This is a test message from Firebase test script"
            ),
            data={
                'test_key': 'test_value',
                'timestamp': datetime.now().isoformat()
            },
            token="fake_token_for_testing"  # Token falso para testing
        )
        
        print("✅ FCM Message object created successfully")
        print(f"📊 Message title: {test_message.notification.title}")
        print(f"📊 Message body: {test_message.notification.body}")
        print(f"📊 Data payload: {test_message.data}")
        
        # Test de MulticastMessage
        multicast_message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title="Multicast Test",
                body="Testing multicast functionality"
            ),
            tokens=["fake_token_1", "fake_token_2"]  # Tokens falsos
        )
        
        print("✅ FCM MulticastMessage object created successfully")
        print(f"📊 Target tokens: {len(multicast_message.tokens)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing FCM service: {e}")
        return False

def test_environment_variables():
    """Test de variables de entorno relacionadas con Firebase"""
    print("\n🔧 Testing Environment Variables...")
    print("-" * 50)
    
    results = {}
    
    # Test SENDER_ID
    if SENDER_ID and SENDER_ID != 0:
        print(f"✅ SENDER_ID: {SENDER_ID}")
        results['sender_id'] = True
    else:
        print("❌ SENDER_ID not configured or invalid")
        results['sender_id'] = False
    
    # Test SERVER_KEY
    if SERVER_KEY and len(SERVER_KEY) > 30:  # Las API keys de Firebase son largas
        print(f"✅ SERVER_KEY: {SERVER_KEY[:10]}...{SERVER_KEY[-5:]}")
        results['server_key'] = True
    else:
        print("❌ SERVER_KEY not configured or too short")
        results['server_key'] = False
    
    # Test FIREBASE_CREDENTIALS_PATH
    if FIREBASE_CREDENTIALS_PATH and os.path.exists(FIREBASE_CREDENTIALS_PATH):
        print(f"✅ FIREBASE_CREDENTIALS_PATH: {FIREBASE_CREDENTIALS_PATH}")
        results['credentials_path'] = True
    else:
        print(f"❌ FIREBASE_CREDENTIALS_PATH invalid: {FIREBASE_CREDENTIALS_PATH}")
        results['credentials_path'] = False
    
    # Verificar coherencia entre variables
    try:
        with open(FIREBASE_CREDENTIALS_PATH, 'r') as f:
            cred_data = json.load(f)
        
        project_number = cred_data.get('project_number')
        if project_number and int(project_number) == SENDER_ID:
            print("✅ SENDER_ID matches project_number in credentials")
            results['consistency'] = True
        else:
            print(f"⚠️ SENDER_ID ({SENDER_ID}) doesn't match project_number ({project_number})")
            results['consistency'] = False
            
    except Exception as e:
        print(f"❌ Error checking consistency: {e}")
        results['consistency'] = False
    
    return all(results.values())

def test_sample_notification():
    """Test de envío de notificación de muestra (dry run)"""
    print("\n🧪 Testing Sample Notification (Dry Run)...")
    print("-" * 50)
    
    try:
        # Verificar que Firebase esté inicializado
        try:
            firebase_admin.get_app()
        except ValueError:
            cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
            firebase_admin.initialize_app(cred)
        
        # Crear mensaje de prueba con token inválido (para dry run)
        message = messaging.Message(
            notification=messaging.Notification(
                title="Test from Firebase Test Script",
                body=f"This is a test notification sent at {datetime.now().strftime('%H:%M:%S')}"
            ),
            data={
                'test': 'true',
                'timestamp': datetime.now().isoformat(),
                'source': 'firebase_test_script'
            },
            token="INVALID_TOKEN_FOR_TESTING"  # Token inválido a propósito
        )
        
        print("✅ Test message created")
        print(f"📊 Title: {message.notification.title}")
        print(f"📊 Body: {message.notification.body}")
        
        # Intentar envío (esperamos que falle por token inválido, pero eso confirma que FCM funciona)
        try:
            response = messaging.send(message, dry_run=True)  # dry_run=True para no enviar realmente
            print("✅ FCM dry run successful!")
            print(f"📊 Message ID: {response}")
            return True
        except messaging.InvalidArgumentError as e:
            if "token" in str(e).lower():
                print("✅ FCM service working (invalid token error expected)")
                return True
            else:
                print(f"❌ Unexpected FCM error: {e}")
                return False
                
    except Exception as e:
        print(f"❌ Error in sample notification test: {e}")
        return False

def cleanup_firebase():
    """Limpieza de la app Firebase después de los tests"""
    try:
        app = firebase_admin.get_app()
        firebase_admin.delete_app(app)
        print("🧹 Firebase app cleaned up")
    except ValueError:
        pass  # No app to clean up

def main():
    """Función principal de testing"""
    print("🔥 Firebase Configuration Test Suite")
    print("=" * 50)
    
    # Verificar variables de entorno básicas
    if not FIREBASE_CREDENTIALS_PATH:
        print("❌ Missing FIREBASE_CREDENTIALS_PATH in environment variables!")
        print("Please set FIREBASE_CREDENTIALS_PATH in your .env file")
        return
    
    # Ejecutar tests
    tests = [
        ("Environment Variables", test_environment_variables),
        ("Credentials File", test_credentials_file),
        ("Firebase Initialization", test_firebase_initialization),
        ("FCM Service", test_fcm_service),
        ("Sample Notification", test_sample_notification)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            print()  # Línea en blanco entre tests
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} failed with exception: {e}")
            results.append((test_name, False))
    
    # Limpiar Firebase
    cleanup_firebase()
    
    # Resumen de resultados
    print("\n📊 Test Results Summary")
    print("=" * 50)
    
    passed = 0
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n🎯 Overall: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("🎉 All tests passed! Firebase is configured correctly.")
        print("\n📋 Next steps:")
        print("1. Make sure your Flutter app has the google-services.json file")
        print("2. Test sending real notifications from your backend")
        print("3. Register device tokens from your Flutter app")
    else:
        print("⚠️ Some tests failed. Check your Firebase configuration.")
        print("\n🔧 Common fixes:")
        print("1. Verify FIREBASE_CREDENTIALS_PATH points to correct file")
        print("2. Check that SENDER_ID matches your Firebase project")
        print("3. Ensure SERVER_KEY is correctly copied from Firebase Console")

if __name__ == "__main__":
    main()