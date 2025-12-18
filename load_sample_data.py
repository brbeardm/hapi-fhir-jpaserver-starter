#!/usr/bin/env python3
"""
Load Sample FHIR Data into HAPI FHIR Server
Creates Practitioners, Locations, Schedules, and Slots for demo purposes

Usage:
    python load_sample_data.py --base-url https://your-app.railway.app
"""

import json
import requests
import argparse
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any

# Sample data templates
SAMPLE_PRACTITIONERS = [
    {
        "resourceType": "Practitioner",
        "id": "practitioner-001",
        "identifier": [{"system": "http://hl7.org/fhir/sid/us-npi", "value": "1234567890"}],
        "name": [{"family": "Smith", "given": ["John"], "prefix": ["Dr."]}],
        "telecom": [{"system": "phone", "value": "555-0101"}],
        "qualification": [{
            "code": {
                "coding": [{
                    "system": "http://terminology.hl7.org/CodeSystem/v2-0360",
                    "code": "MD",
                    "display": "Doctor of Medicine"
                }]
            }
        }]
    },
    {
        "resourceType": "Practitioner",
        "id": "practitioner-002",
        "identifier": [{"system": "http://hl7.org/fhir/sid/us-npi", "value": "1234567891"}],
        "name": [{"family": "Johnson", "given": ["Sarah"], "prefix": ["Dr."]}],
        "telecom": [{"system": "phone", "value": "555-0102"}],
        "qualification": [{
            "code": {
                "coding": [{
                    "system": "http://terminology.hl7.org/CodeSystem/v2-0360",
                    "code": "MD",
                    "display": "Doctor of Medicine"
                }]
            }
        }]
    },
    {
        "resourceType": "Practitioner",
        "id": "practitioner-003",
        "identifier": [{"system": "http://hl7.org/fhir/sid/us-npi", "value": "1234567892"}],
        "name": [{"family": "Williams", "given": ["Michael"], "prefix": ["Dr."]}],
        "telecom": [{"system": "phone", "value": "555-0103"}],
        "qualification": [{
            "code": {
                "coding": [{
                    "system": "http://terminology.hl7.org/CodeSystem/v2-0360",
                    "code": "DO",
                    "display": "Doctor of Osteopathic Medicine"
                }]
            }
        }]
    }
]

SAMPLE_LOCATIONS = [
    {
        "resourceType": "Location",
        "id": "location-001",
        "name": "Main Clinic",
        "address": {
            "line": ["123 Healthcare Blvd"],
            "city": "Houston",
            "state": "TX",
            "postalCode": "77030",
            "country": "US"
        },
        "telecom": [{"system": "phone", "value": "555-1000"}],
        "status": "active"
    },
    {
        "resourceType": "Location",
        "id": "location-002",
        "name": "Westside Medical Center",
        "address": {
            "line": ["456 Medical Drive"],
            "city": "Houston",
            "state": "TX",
            "postalCode": "77024",
            "country": "US"
        },
        "telecom": [{"system": "phone", "value": "555-2000"}],
        "status": "active"
    }
]

def create_schedules(base_url: str, location_ids: List[str], practitioner_ids: List[str]) -> List[str]:
    """Create Schedule resources and return their IDs."""
    schedule_ids = []
    
    # Create a schedule for each practitioner at each location
    for loc_id in location_ids:
        for prac_id in practitioner_ids:
            schedule = {
                "resourceType": "Schedule",
                "id": f"schedule-{prac_id}-{loc_id}",
                "actor": [
                    {"reference": f"Practitioner/{prac_id}"},
                    {"reference": f"Location/{loc_id}"}
                ],
                "planningHorizon": {
                    "start": datetime.now().isoformat(),
                    "end": (datetime.now() + timedelta(days=90)).isoformat()
                },
                "status": "active"
            }
            
            response = requests.put(
                f"{base_url}/fhir/Schedule/{schedule['id']}",
                json=schedule,
                headers={"Content-Type": "application/fhir+json", "Accept": "application/fhir+json"}
            )
            
            if response.status_code in [200, 201]:
                print(f"✅ Created Schedule: {schedule['id']}")
                schedule_ids.append(schedule['id'])
            else:
                print(f"⚠️ Failed to create Schedule {schedule['id']}: {response.status_code} - {response.text[:200]}")
    
    return schedule_ids

def create_slots(base_url: str, schedule_ids: List[str], days_ahead: int = 30):
    """Create Slot resources for the next N days."""
    slots_created = 0
    
    # Generate slots: 9 AM - 5 PM, every 30 minutes, Monday-Friday
    start_date = datetime.now().replace(hour=9, minute=0, second=0, microsecond=0)
    
    for day_offset in range(days_ahead):
        current_date = start_date + timedelta(days=day_offset)
        
        # Skip weekends
        if current_date.weekday() >= 5:  # Saturday = 5, Sunday = 6
            continue
        
        # Create slots for each schedule
        for schedule_id in schedule_ids:
            # Morning slots: 9 AM - 12 PM
            for hour in [9, 10, 11]:
                for minute in [0, 30]:
                    slot_time = current_date.replace(hour=hour, minute=minute)
                    
                    slot = {
                        "resourceType": "Slot",
                        "schedule": {"reference": f"Schedule/{schedule_id}"},
                        "status": "free",
                        "start": slot_time.isoformat(),
                        "end": (slot_time + timedelta(minutes=30)).isoformat()
                    }
                    
                    response = requests.post(
                        f"{base_url}/fhir/Slot",
                        json=slot,
                        headers={"Content-Type": "application/fhir+json", "Accept": "application/fhir+json"}
                    )
                    
                    if response.status_code in [200, 201]:
                        slots_created += 1
                        if slots_created % 10 == 0:
                            print(f"✅ Created {slots_created} slots...")
                    else:
                        print(f"⚠️ Failed to create slot: {response.status_code} - {response.text[:200]}")
            
            # Afternoon slots: 1 PM - 5 PM
            for hour in [13, 14, 15, 16]:
                for minute in [0, 30]:
                    slot_time = current_date.replace(hour=hour, minute=minute)
                    
                    slot = {
                        "resourceType": "Slot",
                        "schedule": {"reference": f"Schedule/{schedule_id}"},
                        "status": "free",
                        "start": slot_time.isoformat(),
                        "end": (slot_time + timedelta(minutes=30)).isoformat()
                    }
                    
                    response = requests.post(
                        f"{base_url}/fhir/Slot",
                        json=slot,
                        headers={"Content-Type": "application/fhir+json", "Accept": "application/fhir+json"}
                    )
                    
                    if response.status_code in [200, 201]:
                        slots_created += 1
                        if slots_created % 10 == 0:
                            print(f"✅ Created {slots_created} slots...")
    
    return slots_created

def load_resource(base_url: str, resource: Dict[str, Any]) -> bool:
    """Load a single FHIR resource using PUT (create or update)."""
    resource_type = resource.get("resourceType")
    resource_id = resource.get("id")
    
    if not resource_type or not resource_id:
        print(f"⚠️ Skipping resource without resourceType or id: {resource}")
        return False
    
    url = f"{base_url}/fhir/{resource_type}/{resource_id}"
    
    try:
        response = requests.put(
            url,
            json=resource,
            headers={
                "Content-Type": "application/fhir+json",
                "Accept": "application/fhir+json"
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            print(f"✅ Created/Updated {resource_type}/{resource_id}")
            return True
        else:
            print(f"⚠️ Failed to create {resource_type}/{resource_id}: {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Error loading {resource_type}/{resource_id}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Load sample FHIR data into HAPI FHIR server")
    parser.add_argument(
        "--base-url",
        required=True,
        help="Base URL of HAPI FHIR server (e.g., https://your-app.railway.app)"
    )
    parser.add_argument(
        "--days-ahead",
        type=int,
        default=30,
        help="Number of days ahead to create slots (default: 30)"
    )
    parser.add_argument(
        "--skip-slots",
        action="store_true",
        help="Skip creating slots (faster for testing)"
    )
    
    args = parser.parse_args()
    
    base_url = args.base_url.rstrip('/')
    
    print(f"🚀 Loading sample data into HAPI FHIR server: {base_url}")
    print("=" * 60)
    
    # Test connection
    try:
        response = requests.get(f"{base_url}/fhir/metadata", timeout=10)
        if response.status_code != 200:
            print(f"❌ Server not responding correctly. Status: {response.status_code}")
            sys.exit(1)
        print("✅ Connected to HAPI FHIR server")
    except requests.exceptions.RequestException as e:
        print(f"❌ Cannot connect to server: {e}")
        sys.exit(1)
    
    # Load Practitioners
    print("\n📋 Loading Practitioners...")
    practitioner_ids = []
    for practitioner in SAMPLE_PRACTITIONERS:
        if load_resource(base_url, practitioner):
            practitioner_ids.append(practitioner['id'])
    
    # Load Locations
    print("\n📍 Loading Locations...")
    location_ids = []
    for location in SAMPLE_LOCATIONS:
        if load_resource(base_url, location):
            location_ids.append(location['id'])
    
    # Create Schedules
    print("\n📅 Creating Schedules...")
    schedule_ids = create_schedules(base_url, location_ids, practitioner_ids)
    
    # Create Slots
    if not args.skip_slots:
        print(f"\n⏰ Creating Slots (next {args.days_ahead} days)...")
        slots_created = create_slots(base_url, schedule_ids, days_ahead=args.days_ahead)
        print(f"✅ Created {slots_created} slots")
    else:
        print("\n⏭️ Skipping slot creation (--skip-slots)")
    
    print("\n" + "=" * 60)
    print("✅ Sample data loading complete!")
    print(f"\n📊 Summary:")
    print(f"   - Practitioners: {len(practitioner_ids)}")
    print(f"   - Locations: {len(location_ids)}")
    print(f"   - Schedules: {len(schedule_ids)}")
    if not args.skip_slots:
        print(f"   - Slots: {slots_created}")
    
    print(f"\n🔍 Test queries:")
    print(f"   GET {base_url}/fhir/Practitioner")
    print(f"   GET {base_url}/fhir/Location")
    print(f"   GET {base_url}/fhir/Schedule")
    print(f"   GET {base_url}/fhir/Slot?status=free")

if __name__ == "__main__":
    main()

