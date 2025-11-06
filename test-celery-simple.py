#!/usr/bin/env python3
"""
Simple Celery test script to verify workers are functioning
"""
import redis
import json
import uuid
import time

def test_celery_workers():
    """Test Celery workers by sending a simple task"""
    
    # Connect to Redis
    r = redis.Redis(host='redis', port=6379, db=0, password='redis-dev-secret-2024')
    
    print("🔍 Testing Celery workers...")
    print(f"📊 Redis connection: {r.ping()}")
    print(f"📊 Initial queue length: {r.llen('celery')}")
    
    # Create a simple task message
    task_id = str(uuid.uuid4())
    task_message = {
        "id": task_id,
        "task": "tasks.hello",
        "args": [],
        "kwargs": {},
        "retries": 0,
        "eta": None,
        "expires": None,
        "utc": True,
    }
    
    # Send task to queue
    print(f"📤 Sending test task: {task_id}")
    r.lpush('celery', json.dumps(task_message))
    
    # Wait and check if task was processed
    print("⏳ Waiting for task to be processed...")
    for i in range(10):
        queue_length = r.llen('celery')
        print(f"   Queue length: {queue_length}")
        if queue_length == 0:
            print("✅ Task was processed by worker!")
            return True
        time.sleep(1)
    
    print("❌ Task was not processed within 10 seconds")
    return False

if __name__ == "__main__":
    test_celery_workers()