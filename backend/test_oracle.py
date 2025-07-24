#!/usr/bin/env python3
"""
Test Oracle Database Connection con Oracle Client local
"""

import oracledb
import os
from dotenv import load_dotenv
from datetime import datetime
from contextlib import contextmanager
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Cargar variables de entorno
load_dotenv()

# Configuración desde .env
ORACLE_USER = os.getenv("ORACLE_USER", "")
ORACLE_PASSWORD = os.getenv("ORACLE_PASSWORD", "")
ORACLE_HOST=os.getenv("ORACLE_HOST", "")
ORACLE_PORT=os.getenv("ORACLE_PORT", "")
ORACLE_SID=os.getenv("ORACLE_SID", "")
ORACLE_JAR_PATH = os.getenv("ORACLE_JAR_PATH", "./instantclient")
ORACLE_DSN = os.getenv("ORACLE_DSN", "localhost:1521/XE")


# Configuración de nombres de tabla
TABLE_USERS = "TEST.NP_users"
TABLE_DEVICES = "TEST.NP_devices"
TABLE_INTERNAL_NOTIFICATIONS = "TEST.NP_internal_notifications"

class OracleDB:
    def __init__(self):
        # Construir DSN usando SID (configuración que funciona)
        self.dsn = oracledb.makedsn(ORACLE_HOST, ORACLE_PORT, sid=ORACLE_SID)
        self.user = ORACLE_USER
        self.password = ORACLE_PASSWORD
        
        # Inicializar Oracle Client
        try:
            if ORACLE_JAR_PATH and os.path.exists(ORACLE_JAR_PATH):
                oracledb.init_oracle_client(lib_dir=os.path.abspath(ORACLE_JAR_PATH))
                print(f"✅ Oracle Client initialized from: {os.path.abspath(ORACLE_JAR_PATH)}")
            else:
                print("⚠️ Oracle Client path not found")
        except Exception as e:
            print(f"⚠️ Oracle Client init failed: {e}")
    
    @contextmanager
    def get_connection(self):
        """Context manager for database connections"""
        conn = None
        try:
            conn = oracledb.connect(
                user=self.user,
                password=self.password,
                dsn=self.dsn
            )
            # Desactivar autocommit
            conn.autocommit = False
            yield conn
        except Exception as e:
            logger.error(f"Error conectando a Oracle: {e}")
            raise
        finally:
            if conn:
                conn.close()

def test_oracle_connection():
    """Test básico de conexión usando la clase OracleDB"""
    print("🔍 Testing Oracle Connection...")
    print(f"📍 Host: {ORACLE_HOST}:{ORACLE_PORT}")
    print(f"🗄️ SID: {ORACLE_SID}")
    print(f"👤 User: {ORACLE_USER}")
    print("-" * 50)
    
    if not ORACLE_USER or not ORACLE_PASSWORD:
        print("❌ Error: ORACLE_USER and ORACLE_PASSWORD must be set in .env file")
        return False
    
    try:
        db = OracleDB()
        print(f"📍 DSN construido: {db.dsn}")
        
        with db.get_connection() as conn:
            cursor = conn.cursor()
            
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
            
            # Información de la instancia
            cursor.execute("SELECT instance_name FROM v$instance")
            instance = cursor.fetchone()
            print(f"🏛️ Instance name: {instance[0] if instance else 'Unknown'}")
            
        print("✅ Connection successful!")
        return True
        
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False

def test_tables():
    """Test de existencia y estructura de tablas"""
    print("\n🗄️ Testing Application Tables...")
    print("-" * 50)
    
    try:
        db = OracleDB()
        
        with db.get_connection() as conn:
            cursor = conn.cursor()
            
            # Lista de tablas esperadas
            expected_tables = ['NP_USERS', 'NP_DEVICES', 'NP_INTERNAL_NOTIFICATIONS']
            
            # Verificar existencia de tablas en esquema TEST
            cursor.execute("""
                SELECT table_name 
                FROM all_tables 
                WHERE owner = 'TEST' 
                AND table_name IN ('NP_USERS', 'NP_DEVICES', 'NP_INTERNAL_NOTIFICATIONS')
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
            
            # Contar registros en cada tabla (usando nombres completos)
            table_mapping = {
                'NP_USERS': TABLE_USERS,
                'NP_DEVICES': TABLE_DEVICES,
                'NP_INTERNAL_NOTIFICATIONS': TABLE_INTERNAL_NOTIFICATIONS
            }
            
            for table_short, table_full in table_mapping.items():
                if table_short in existing_tables:
                    try:
                        cursor.execute(f"SELECT COUNT(*) FROM {table_full}")
                        count = cursor.fetchone()[0]
                        print(f"📊 {table_short}: {count} records")
                    except Exception as e:
                        print(f"❌ Error counting {table_short}: {e}")
        
        return len(missing_tables) == 0
        
    except Exception as e:
        print(f"❌ Error testing tables: {e}")
        return False

def test_crud_operations():
    """Test de operaciones CRUD básicas"""
    print("\n🔧 Testing CRUD Operations...")
    print("-" * 50)
    
    try:
        db = OracleDB()
        
        with db.get_connection() as conn:
            cursor = conn.cursor()
            
            # Test INSERT - Usuario de prueba
            test_username = f"test_user_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            test_email = f"{test_username}@test.com"
            
            print(f"📝 Testing INSERT with user: {test_username}")
            
            cursor.execute(f"""
                INSERT INTO {TABLE_USERS} (username, email, password_hash) 
                VALUES (:1, :2, :3)
            """, (test_username, test_email, "test_hash_123"))
            
            # Test SELECT - Verificar inserción
            cursor.execute(f"SELECT id, username FROM {TABLE_USERS} WHERE username = :1", (test_username,))
            user_result = cursor.fetchone()
            
            if user_result:
                user_id = user_result[0]
                print(f"✅ INSERT successful - User ID: {user_id}")
                
                # Test UPDATE
                cursor.execute(f"""
                    UPDATE {TABLE_USERS} 
                    SET email = :1 
                    WHERE id = :2
                """, (f"updated_{test_email}", user_id))
                
                print("✅ UPDATE successful")
                
                # Test DELETE - Limpiar datos de prueba
                cursor.execute(f"DELETE FROM {TABLE_USERS} WHERE id = :1", (user_id,))
                print("✅ DELETE successful")
                
            else:
                print("❌ INSERT failed - No user found")
                return False
            
            conn.commit()
        
        print("✅ All CRUD operations successful!")
        return True
        
    except Exception as e:
        print(f"❌ Error in CRUD operations: {e}")
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
