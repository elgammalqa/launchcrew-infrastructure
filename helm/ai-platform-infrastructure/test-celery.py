#!/usr/bin/env python3
"""
Test script for Celery deployment in AI Platform Infrastructure
This script tests Celery worker connectivity and task execution
"""

import os
import sys
import time
from celery import Celery

# Celery configuration
BROKER_URL = os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0')
RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', 'redis://localhost:6379/0')

# Create Celery app
app = Celery('test_tasks', broker=BROKER_URL, backend=RESULT_BACKEND)

# Configure Celery
app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    result_expires=3600,
)

@app.task
def add_numbers(x, y):
    """Simple test task that adds two numbers"""
    time.sleep(2)  # Simulate some work
    return x + y

@app.task
def multiply_numbers(x, y):
    """Simple test task that multiplies two numbers"""
    time.sleep(1)  # Simulate some work
    return x * y

def test_celery_connection():
    """Test Celery broker connection"""
    print("🔍 Testing Celery connection...")
    
    try:
        # Test broker connection
        inspect = app.control.inspect()
        stats = inspect.stats()
        
        if stats:
            print("✅ Celery broker connection successful!")
            print(f"📊 Active workers: {len(stats)}")
            for worker, info in stats.items():
                print(f"   - {worker}: {info.get('pool', {}).get('max-concurrency', 'N/A')} max concurrency")
            return True
        else:
            print("❌ No Celery workers found!")
            return False
            
    except Exception as e:
        print(f"❌ Celery connection failed: {e}")
        return False

def test_task_execution():
    """Test task execution"""
    print("\n🚀 Testing task execution...")
    
    try:
        # Send test tasks
        result1 = add_numbers.delay(4, 6)
        result2 = multiply_numbers.delay(3, 7)
        
        print(f"📤 Sent tasks: {result1.id}, {result2.id}")
        
        # Wait for results
        print("⏳ Waiting for results...")
        
        # Get results with timeout
        add_result = result1.get(timeout=30)
        multiply_result = result2.get(timeout=30)
        
        print(f"✅ Add result: 4 + 6 = {add_result}")
        print(f"✅ Multiply result: 3 × 7 = {multiply_result}")
        
        return True
        
    except Exception as e:
        print(f"❌ Task execution failed: {e}")
        return False

def main():
    """Main test function"""
    print("🧪 Celery Test Suite")
    print("=" * 50)
    print(f"Broker URL: {BROKER_URL}")
    print(f"Result Backend: {RESULT_BACKEND}")
    print("=" * 50)
    
    # Test connection
    if not test_celery_connection():
        sys.exit(1)
    
    # Test task execution
    if not test_task_execution():
        sys.exit(1)
    
    print("\n🎉 All Celery tests passed!")
    print("\n💡 Tips:")
    print("   - Monitor tasks in Flower: http://localhost:5555")
    print("   - Check worker logs: kubectl logs -l app.kubernetes.io/component=celery-worker -f")
    print("   - Scale workers: kubectl scale deployment ai-celery-worker --replicas=3")

if __name__ == "__main__":
    main()