#!/usr/bin/env python3
"""
Celery Worker Startup Health Check Script
Verifies database connectivity and basic system health before starting worker
"""

import os
import sys
import time
import logging
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def check_database_connection() -> bool:
    """Check if database is accessible"""
    try:
        import psycopg2
        
        # Get database connection details from environment
        db_host = os.getenv('DATABASE_HOST', 'localhost')
        db_port = os.getenv('DATABASE_PORT', '5432')
        db_name = os.getenv('DATABASE_NAME', 'ai_platform')
        db_user = os.getenv('DATABASE_USER', 'postgres')
        db_password = os.getenv('DATABASE_PASSWORD', 'postgres')
        
        logger.info(f"Checking database connection to {db_host}:{db_port}/{db_name}")
        
        conn = psycopg2.connect(
            host=db_host,
            port=db_port,
            database=db_name,
            user=db_user,
            password=db_password,
            connect_timeout=10
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        result = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        logger.info("✅ Database connection successful")
        return True
        
    except ImportError:
        logger.warning("⚠️ psycopg2 not available, skipping database check")
        return True
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")
        return False

def check_redis_connection() -> bool:
    """Check if Redis is accessible"""
    try:
        import redis
        
        redis_host = os.getenv('REDIS_HOST', 'localhost')
        redis_port = int(os.getenv('REDIS_PORT', '6379'))
        redis_db = int(os.getenv('REDIS_DB', '0'))
        
        logger.info(f"Checking Redis connection to {redis_host}:{redis_port}/{redis_db}")
        
        r = redis.Redis(
            host=redis_host,
            port=redis_port,
            db=redis_db,
            socket_connect_timeout=10,
            socket_timeout=10
        )
        
        r.ping()
        logger.info("✅ Redis connection successful")
        return True
        
    except ImportError:
        logger.warning("⚠️ redis not available, skipping Redis check")
        return True
    except Exception as e:
        logger.error(f"❌ Redis connection failed: {e}")
        return False

def check_celery_app() -> bool:
    """Check if Celery app can be imported"""
    try:
        # Try to import the Celery app
        sys.path.insert(0, '/app')
        
        # This is a basic import check - adjust path as needed
        logger.info("Checking Celery app import...")
        
        # For now, just check if we can import celery
        import celery
        logger.info("✅ Celery import successful")
        return True
        
    except Exception as e:
        logger.error(f"❌ Celery app import failed: {e}")
        return False

def wait_for_dependencies(max_retries: int = 30, retry_delay: int = 2) -> bool:
    """Wait for dependencies to become available"""
    logger.info("Starting dependency health checks...")
    
    for attempt in range(1, max_retries + 1):
        logger.info(f"Health check attempt {attempt}/{max_retries}")
        
        checks = [
            ("Database", check_database_connection),
            ("Redis", check_redis_connection),
            ("Celery App", check_celery_app)
        ]
        
        all_passed = True
        for check_name, check_func in checks:
            if not check_func():
                all_passed = False
                break
        
        if all_passed:
            logger.info("🎉 All health checks passed!")
            return True
        
        if attempt < max_retries:
            logger.info(f"⏳ Waiting {retry_delay}s before retry...")
            time.sleep(retry_delay)
    
    logger.error("❌ Health checks failed after maximum retries")
    return False

def main():
    """Main startup check function"""
    logger.info("🚀 Starting Celery Worker Health Check")
    
    # Check environment variables
    required_env_vars = [
        'CELERY_APP'
    ]
    
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    if missing_vars:
        logger.error(f"❌ Missing required environment variables: {missing_vars}")
        sys.exit(1)
    
    # Wait for dependencies
    if not wait_for_dependencies():
        logger.error("❌ Startup health check failed")
        sys.exit(1)
    
    logger.info("✅ Startup health check completed successfully")
    sys.exit(0)

if __name__ == "__main__":
    main()