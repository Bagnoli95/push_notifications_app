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

class OracleDB:
    def __init__(self):
        # Construir DSN desde las partes usando SID
        self.dsn = oracledb.makedsn(ORACLE_HOST, ORACLE_PORT, sid=ORACLE_SID)
        self.user = ORACLE_USER
        self.password = ORACLE_PASSWORD
        
        # Inicializar Oracle Client
        try:
            if ORACLE_JAR_PATH and os.path.exists(ORACLE_JAR_PATH):
                oracledb.init_oracle_client(lib_dir=os.path.abspath(ORACLE_JAR_PATH))
                print(f"✅ Oracle Client initialized from: {os.path.abspath(ORACLE_JAR_PATH)}")
            else:
                print("⚠️ Oracle Client path not found, using Thin mode")
        except Exception as e:
            print(f"⚠️ Oracle Client init failed, using Thin mode: {e}")
    
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

def test_dsn_methods():
    """Probar diferentes métodos de construcción de DSN"""
    print("🔧 Testing Different DSN Methods...")
    print(f"📍 Host: {ORACLE_HOST}")
    print(f"🔌 Port: {ORACLE_PORT}")
    print(f"🗄️ SID: {ORACLE_SID}")
    print("-" * 50)
    
    dsn_methods = []
    
    # Método 1: makedsn con SID
    try:
        dsn1 = oracledb.makedsn(ORACLE_HOST, ORACLE_PORT, sid=ORACLE_SID)
        dsn_methods.append(("makedsn with SID", dsn1))
        print(f"✅ Method 1 - makedsn with SID: {dsn1}")
    except Exception as e:
        print(f"❌ Method 1 failed: {e}")
    
    # Método 2: makedsn con service_name
    try:
        dsn2 = oracledb.makedsn(ORACLE_HOST, ORACLE_PORT, service_name=ORACLE_SID)
        dsn_methods.append(("makedsn with service_name", dsn2))
        print(f"✅ Method 2 - makedsn with service_name: {dsn2}")
    except Exception as e:
        print(f"❌ Method 2 failed: {e}")
    
    # Método 3: DSN string directo
    try:
        dsn3 = f"{ORACLE_HOST}:{ORACLE_PORT}/{ORACLE_SID}"
        dsn_methods.append(("Direct DSN string", dsn3))
        print(f"✅ Method 3 - Direct DSN: {dsn3}")
    except Exception as e:
        print(f"❌ Method 3 failed: {e}")
    
    # Método 4: Easy Connect string
    try:
        dsn4 = f"{ORACLE_HOST}:{ORACLE_PORT}/{ORACLE_SID}"
        dsn_methods.append(("Easy Connect", dsn4))
        print(f"✅ Method 4 - Easy Connect: {dsn4}")
    except Exception as e:
        print(f"❌ Method 4 failed: {e}")
    
    return dsn_methods

def test_oracle_connection_with_dsn(dsn_name, dsn):
    """Test de conexión con un DSN específico"""
    print(f"\n🔍 Testing connection with {dsn_name}...")
    print(f"📍 DSN: {dsn}")
    print(f"👤 User: {ORACLE_USER}")
    print("-" * 50)
    
    try:
        # Test de conexión básica
        connection = oracledb.connect(
            user=ORACLE_USER, 
            password=ORACLE_PASSWORD, 
            dsn=dsn
        )
        print(f"✅ Connection successful with {dsn_name}!")
        
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
        
        # Información de la instancia
        cursor.execute("SELECT instance_name FROM v$instance")
        instance = cursor.fetchone()
        print(f"🏛️ Instance name: {instance[0] if instance else 'Unknown'}")
        
        connection.close()
        return True
        
    except oracledb.Error as e:
        error_obj, = e.args
        print(f"❌ Oracle Error with {dsn_name}: {error_obj.message}")
        print(f"🔍 Error Code: {error_obj.code}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error with {dsn_name}: {e}")
        return False

def test_oracle_class():
    """Test usando la clase OracleDB"""
    print("\n🏗️ Testing OracleDB Class...")
    print("-" * 50)
    
    try:
        db = OracleDB()
        print(f"📍 DSN construido: {db.dsn}")
        
        with db.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 'OracleDB class works!' FROM dual")
            result = cursor.fetchone()
            print(f"✅ OracleDB class test: {result[0]}")
            
        return True
        
    except Exception as e:
        print(f"❌ OracleDB class error: {e}")
        return False

def test_oracle_client_files():
    """Verificar archivos de Oracle Client"""
    print("\n📂 Testing Oracle Client Files...")
    print("-" * 50)
    
    if not os.path.exists(ORACLE_JAR_PATH):
        print(f"❌ Oracle Client directory not found: {ORACLE_JAR_PATH}")
        return False
    
    print(f"✅ Oracle Client directory exists: {ORACLE_JAR_PATH}")
    
    # Archivos críticos de Oracle Client
    # critical_files = ['oci.dll', 'oraocci19.dll', 'oraclient19.dll']
    # found_files = []
    
    # for file in critical_files:
    #     file_path = os.path.join(ORACLE_JAR_PATH, file)
    #     if os.path.exists(file_path):
    #         found_files.append(file)
    #         print(f"✅ Found: {file}")
    #     else:
    #         print(f"⚠️ Missing: {file}")
    
    # # Listar archivos .dll en el directorioex
    # try:
    #     all_files = [f for f in os.listdir(ORACLE_JAR_PATH) if f.endswith('.dll')]
    #     print(f"\n📋 DLL files in {ORACLE_JAR_PATH}:")
    #     for file in sorted(all_files):
    #         print(f"   📄 {file}")
    # except Exception as e:
    #     print(f"❌ Error listing files: {e}")
    
    # return len(found_files) > 0

def main():
    """Función principal de testing"""
    print("🚀 Oracle Database Test Suite (Multiple DSN Methods)")
    print("=" * 65)
    
    # Verificar variables de entorno
    if not ORACLE_USER or not ORACLE_PASSWORD:
        print("❌ Missing environment variables!")
        print("Please set ORACLE_USER and ORACLE_PASSWORD in your .env file")
        return
    
    # Test archivos Oracle Client
    print("\n" + "="*65)
    client_files_ok = test_oracle_client_files()
    
    # Test diferentes métodos de DSN
    print("\n" + "="*65)
    dsn_methods = test_dsn_methods()
    
    # Test conexiones con cada método de DSN
    connection_results = []
    for dsn_name, dsn in dsn_methods:
        print("\n" + "="*65)
        result = test_oracle_connection_with_dsn(dsn_name, dsn)
        connection_results.append((dsn_name, result))
        
        # Si este método funciona, salir del loop
        if result:
            print(f"\n🎉 Found working DSN method: {dsn_name}")
            break
    
    # Test clase OracleDB
    print("\n" + "="*65)
    class_result = test_oracle_class()
    
    # Resumen de resultados
    print("\n📊 Test Results Summary")
    print("=" * 50)
    
    print(f"Oracle Client Files: {'✅ PASSED' if client_files_ok else '❌ FAILED'}")
    
    successful_connections = [name for name, result in connection_results if result]
    if successful_connections:
        print(f"✅ Working DSN methods: {', '.join(successful_connections)}")
    else:
        print("❌ No working DSN methods found")
    
    print(f"OracleDB Class: {'✅ PASSED' if class_result else '❌ FAILED'}")
    
    if successful_connections and class_result:
        print("\n🎉 Oracle connection successful! Database is ready.")
        print("\n📋 Recommended DSN for your .env:")
        print(f"ORACLE_HOST={ORACLE_HOST}")
        print(f"ORACLE_PORT={ORACLE_PORT}")
        print(f"ORACLE_SID={ORACLE_SID}")
    else:
        print("\n⚠️ Some tests failed. Check configuration and database setup.")
        print("\n🔧 Troubleshooting tips:")
        print("1. Verify that SICOOP is the correct SID (not service name)")
        print("2. Check if the database is running and accessible")
        print("3. Verify network connectivity to 10.5.2.171:1521")
        print("4. Ask your DBA for the correct SID or service name")

if __name__ == "__main__":
    main()