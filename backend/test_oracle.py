#!/usr/bin/env python3
"""
Test Oracle Database Connection
Verifica la conexión a Oracle y las tablas de la aplicación
"""

import cx_Oracle
import os
from dotenv import load_dotenv
from datetime import datetime

# Cargar variables de entorno
load_dotenv()

# Configuración desde .env
ORACLE_USER = os.getenv("ORACLE_USER", "")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "")
ORACLE_DSN = os.getenv("ORACLE_DSN", "localhost:1521/XE")

def test_oracle_connection():
    """Test básico de conexión a Oracle"""
    print("🔍 Testing Oracle Connection...")
    print(f"📍 DSN: {ORACLE_DSN}")
    print(f"👤 User: {ORACLE_USER}")
    print("-" * 50)
    
    if not ORACLE_USER or not ORACLE_PASSWORD:
        print("❌ Error: ORACLE_USER and ORACLE_PASSWORD must be set in .env file")
        return False
    
    try:
        # Test de conexión básica
        connection = cx_Oracle.connect(ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN)
        print("✅ Connection successful!")
        
        cursor = connection.cursor()
        
        # Test query básico
        cursor.execute("SELECT 1 FROM dual")
        result = cursor.fetchone()
        print(f"✅ Basic query test: {result[0]}")
        
        # Información de la base de datos
        cursor.execute("SELECT version FROM v$instance")
        version = cursor.fetchone()
        print(f"📊 Oracle version: {version[0] if version else 'Unknown'}")
        
        # Verificar esquema actual
        cursor.execute("SELECT USER FROM dual")
        current_user = cursor.fetchone()
        print(f"👤 Current schema: {current_user[0] if current_user else 'Unknown'}")
        
        connection.close()
        return True
        
    except cx_Oracle.Error as e:
        error_obj, = e.args
        print(f"❌ Oracle Error: {error_obj.message}")
        print(f"🔍 Error Code: {error_obj.code}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

def test_tables():
    """Test de existencia y estructura de tablas"""
    print("\n🗄️ Testing Application Tables...")
    print("-" * 50)
    
    try:
        connection = cx_Oracle.connect(ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN)
        cursor = connection.cursor()
        
        # Lista de tablas esperadas
        expected_tables = ['USERS', 'DEVICES', 'INTERNAL_NOTIFICATIONS']
        
        # Verificar existencia de tablas
        cursor.execute("""
            SELECT table_name 
            FROM user_tables 
            WHERE table_name IN ('USERS', 'DEVICES', 'INTERNAL_NOTIFICATIONS')
            ORDER BY table_name
        """)
        
        existing_tables = [row[0] for row in cursor.fetchall()]
        
        print(f"📋 Expected tables: {expected_tables}")
        print(f"✅ Existing tables: {existing_tables}")
        
        # Verificar tablas faltantes
        missing_tables = set(expected_tables) - set(existing_tables)
        if missing_tables:
            print(f"⚠️ Missing tables: {list(missing_tables)}")
        else:
            print("✅ All required tables exist!")
        
        # Contar registros en cada tabla
        for table in existing_tables:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"📊 {table}: {count} records")
            except Exception as e:
                print(f"❌ Error counting {table}: {e}")
        
        connection.close()
        return len(missing_tables) == 0
        
    except Exception as e:
        print(f"❌ Error testing tables: {e}")
        return False

def test_crud_operations():
    """Test de operaciones CRUD básicas"""
    print("\n🔧 Testing CRUD Operations...")
    print("-" * 50)
    
    try:
        connection = cx_Oracle.connect(ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN)
        cursor = connection.cursor()
        
        # Test INSERT - Usuario de prueba
        test_username = f"test_user_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        test_email = f"{test_username}@test.com"
        
        print(f"📝 Testing INSERT with user: {test_username}")
        
        cursor.execute("""
            INSERT INTO users (username, email, password_hash) 
            VALUES (:1, :2, :3)
        """, (test_username, test_email, "test_hash_123"))
        
        # Test SELECT - Verificar inserción
        cursor.execute("SELECT id, username FROM users WHERE username = :1", (test_username,))
        user_result = cursor.fetchone()
        
        if user_result:
            user_id = user_result[0]
            print(f"✅ INSERT successful - User ID: {user_id}")
            
            # Test UPDATE
            cursor.execute("""
                UPDATE users 
                SET email = :1 
                WHERE id = :2
            """, (f"updated_{test_email}", user_id))
            
            print("✅ UPDATE successful")
            
            # Test DELETE - Limpiar datos de prueba
            cursor.execute("DELETE FROM users WHERE id = :1", (user_id,))
            print("✅ DELETE successful")
            
        else:
            print("❌ INSERT failed - No user found")
            return False
        
        connection.commit()
        connection.close()
        print("✅ All CRUD operations successful!")
        return True
        
    except Exception as e:
        print(f"❌ Error in CRUD operations: {e}")
        try:
            connection.rollback()
            connection.close()
        except:
            pass
        return False

def main():
    """Función principal de testing"""
    print("🚀 Oracle Database Test Suite")
    print("=" * 50)
    
    # Verificar variables de entorno
    if not ORACLE_USER or not ORACLE_PASSWORD:
        print("❌ Missing environment variables!")
        print("Please set ORACLE_USER and ORACLE_PASSWORD in your .env file")
        return
    
    # Ejecutar tests
    tests = [
        ("Connection Test", test_oracle_connection),
        ("Tables Test", test_tables),
        ("CRUD Test", test_crud_operations)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} failed with exception: {e}")
            results.append((test_name, False))
    
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
        print("🎉 All tests passed! Oracle database is ready.")
    else:
        print("⚠️ Some tests failed. Check configuration and database setup.")

if __name__ == "__main__":
    main()