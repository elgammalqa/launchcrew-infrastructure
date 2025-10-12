#!/usr/bin/env python3
"""
Test Ray cluster connectivity and basic functionality
"""

import ray
import sys
import time

def test_ray_connection():
    """Test connection to Ray cluster"""
    print("🔌 Connecting to Ray cluster...")
    
    try:
        # Connect to Ray cluster
        # For local testing with port-forward: ray.init(address="ray://localhost:10001")
        # For in-cluster: ray.init(address="ray://ray-cluster-head-svc.ai-platform-infra.svc.cluster.local:10001")
        ray.init(address="auto")
        
        print("✅ Connected to Ray cluster!")
        print(f"   Dashboard: {ray.get_dashboard_url()}")
        print(f"   Nodes: {len(ray.nodes())}")
        print(f"   Available resources: {ray.available_resources()}")
        
        return True
    except Exception as e:
        print(f"❌ Failed to connect: {e}")
        return False

@ray.remote
def hello_ray(name: str) -> str:
    """Simple Ray remote function"""
    return f"Hello {name} from Ray!"

@ray.remote
def compute_pi(num_samples: int) -> float:
    """Compute Pi using Monte Carlo method"""
    import random
    inside_circle = 0
    
    for _ in range(num_samples):
        x, y = random.random(), random.random()
        if x*x + y*y <= 1:
            inside_circle += 1
    
    return 4 * inside_circle / num_samples

def test_ray_tasks():
    """Test Ray task execution"""
    print("\n🧪 Testing Ray tasks...")
    
    try:
        # Test simple task
        result = ray.get(hello_ray.remote("Developer"))
        print(f"   ✅ Simple task: {result}")
        
        # Test parallel tasks
        print("   🔄 Running parallel Pi computation...")
        start = time.time()
        futures = [compute_pi.remote(1_000_000) for _ in range(4)]
        results = ray.get(futures)
        elapsed = time.time() - start
        
        avg_pi = sum(results) / len(results)
        print(f"   ✅ Parallel tasks completed in {elapsed:.2f}s")
        print(f"   📊 Estimated Pi: {avg_pi:.6f}")
        
        return True
    except Exception as e:
        print(f"   ❌ Task execution failed: {e}")
        return False

def main():
    """Main test function"""
    print("🚀 Ray Cluster Test\n")
    
    # Test connection
    if not test_ray_connection():
        sys.exit(1)
    
    # Test tasks
    if not test_ray_tasks():
        ray.shutdown()
        sys.exit(1)
    
    # Cleanup
    print("\n🧹 Shutting down Ray...")
    ray.shutdown()
    print("✅ All tests passed!")

if __name__ == "__main__":
    main()
