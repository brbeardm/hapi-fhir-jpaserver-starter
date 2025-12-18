#!/bin/bash
# Load Sample FHIR Data using cURL
# Usage: ./load_sample_data.sh https://your-app.railway.app

BASE_URL="${1:-http://localhost:8080}"
BASE_URL="${BASE_URL%/}"  # Remove trailing slash

echo "🚀 Loading sample data into HAPI FHIR server: $BASE_URL"
echo "============================================================"

# Test connection
echo "Testing connection..."
if ! curl -s -f "${BASE_URL}/fhir/metadata" > /dev/null; then
    echo "❌ Cannot connect to server at $BASE_URL"
    exit 1
fi
echo "✅ Connected to HAPI FHIR server"
echo ""

# Sample Practitioner
echo "📋 Creating Practitioner..."
curl -X PUT "${BASE_URL}/fhir/Practitioner/practitioner-001" \
  -H "Content-Type: application/fhir+json" \
  -H "Accept: application/fhir+json" \
  -d '{
    "resourceType": "Practitioner",
    "id": "practitioner-001",
    "identifier": [{"system": "http://hl7.org/fhir/sid/us-npi", "value": "1234567890"}],
    "name": [{"family": "Smith", "given": ["John"], "prefix": ["Dr."]}],
    "telecom": [{"system": "phone", "value": "555-0101"}]
  }'
echo ""
echo ""

# Sample Location
echo "📍 Creating Location..."
curl -X PUT "${BASE_URL}/fhir/Location/location-001" \
  -H "Content-Type: application/fhir+json" \
  -H "Accept: application/fhir+json" \
  -d '{
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
    "status": "active"
  }'
echo ""
echo ""

# Sample Schedule
echo "📅 Creating Schedule..."
curl -X PUT "${BASE_URL}/fhir/Schedule/schedule-001" \
  -H "Content-Type: application/fhir+json" \
  -H "Accept: application/fhir+json" \
  -d '{
    "resourceType": "Schedule",
    "id": "schedule-001",
    "actor": [
      {"reference": "Practitioner/practitioner-001"},
      {"reference": "Location/location-001"}
    ],
    "planningHorizon": {
      "start": "2025-01-01T00:00:00Z",
      "end": "2025-12-31T23:59:59Z"
    },
    "status": "active"
  }'
echo ""
echo ""

# Sample Slot
echo "⏰ Creating Slot..."
curl -X POST "${BASE_URL}/fhir/Slot" \
  -H "Content-Type: application/fhir+json" \
  -H "Accept: application/fhir+json" \
  -d '{
    "resourceType": "Slot",
    "schedule": {"reference": "Schedule/schedule-001"},
    "status": "free",
    "start": "2025-01-15T09:00:00Z",
    "end": "2025-01-15T09:30:00Z"
  }'
echo ""
echo ""

echo "============================================================"
echo "✅ Sample data loading complete!"
echo ""
echo "🔍 Test queries:"
echo "   GET ${BASE_URL}/fhir/Practitioner"
echo "   GET ${BASE_URL}/fhir/Location"
echo "   GET ${BASE_URL}/fhir/Schedule"
echo "   GET ${BASE_URL}/fhir/Slot?status=free"

