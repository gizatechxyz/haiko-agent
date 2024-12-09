import sys
import os
from pathlib import Path

sys.path.append(str(Path(__file__).parent.parent))

import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch
import json
import requests
from src.main import app, fetch_eth_prices, trend_num_to_string
from fastapi import HTTPException

client = TestClient(app)

@pytest.mark.parametrize("trend_num,expected", [
    (0, "Up"),
    (1, "Down"),
    (2, "Neutral"),
])
def test_trend_num_to_string_valid(trend_num, expected):
    assert trend_num_to_string(trend_num) == expected

def test_trend_num_to_string_invalid():
    with pytest.raises(ValueError, match="Unknown trend value"):
        trend_num_to_string(3)

# Mock Coingecko API responses
MOCK_VALID_RESPONSE = {
    "prices": [
        [1628755200000, 3000.0],
        [1628841600000, 3100.0],
        [1628928000000, 3200.0]
    ]
}

@pytest.fixture
def mock_requests_get():
    with patch('requests.get') as mock_get:
        yield mock_get

def test_fetch_eth_prices_success(mock_requests_get):
    mock_requests_get.return_value.json.return_value = MOCK_VALID_RESPONSE
    mock_requests_get.return_value.raise_for_status = Mock()
    
    result = fetch_eth_prices(3)
    assert len(result) == 3
    assert result[0][1] == 3000.0

def test_fetch_eth_prices_api_error(mock_requests_get):
    mock_requests_get.side_effect = requests.RequestException("API Error")
    
    with pytest.raises(HTTPException) as exc_info:
        fetch_eth_prices(3)
    assert exc_info.value.status_code == 500
    assert "Error fetching ETH prices" in str(exc_info.value.detail)

# Preprocessing Tests
def test_preprocess_valid_input(mock_requests_get):
    mock_requests_get.return_value.json.return_value = MOCK_VALID_RESPONSE
    mock_requests_get.return_value.raise_for_status = Mock()
    
    response = client.post("/preprocess", json={"days": 3, "lookback": 2})
    assert response.status_code == 200
    
    result = response.json()
    assert "args" in result
    parsed_args = json.loads(result["args"])
    assert "prices" in parsed_args
    assert "lookback" in parsed_args
    assert parsed_args["lookback"] == 2

def test_preprocess_invalid_days():
    response = client.post("/preprocess", json={"days": -1, "lookback": 2})
    assert response.status_code == 422

# Postprocessing Tests
@pytest.mark.parametrize("input_trend,expected_trend", [
    (0, "Up"),
    (1, "Down"),
    (2, "Neutral")
])
def test_postprocess_valid_trends(input_trend, expected_trend):
    mock_result = {
        "analysis": {
            "trend": input_trend,
            "vol_limit": 7907193
        }
    }
    
    response = client.post(
        "/postprocess",
        json={"result": json.dumps(mock_result)}
    )
    assert response.status_code == 200
    
    result = json.loads(response.json())
    assert result["results"]["trend"] == expected_trend
    assert result["results"]["vol_limit"] == 7907193

def test_postprocess_with_request_id():
    mock_result = {
        "analysis": {
            "trend": 0,
            "vol_limit": 7907193
        }
    }
    test_request_id = "test-123"
    
    response = client.post(
        "/postprocess",
        json={
            "result": json.dumps(mock_result),
            "request_id": test_request_id
        }
    )
    assert response.status_code == 200
    
    result = json.loads(response.json())
    assert result["request_id"] == test_request_id

# Error Handling Tests
def test_preprocess_missing_required_fields():
    response = client.post("/preprocess", json={"days": 3})  # Missing lookback
    assert response.status_code == 422

def test_postprocess_invalid_json():
    response = client.post("/postprocess", json={"result": "invalid json"})
    assert response.status_code == 500

# Integration Tests
def test_full_processing_flow(mock_requests_get):
    mock_requests_get.return_value.json.return_value = MOCK_VALID_RESPONSE
    mock_requests_get.return_value.raise_for_status = Mock()
    
    # First test preprocessing
    preprocess_response = client.post(
        "/preprocess",
        json={"days": 3, "lookback": 2}
    )
    assert preprocess_response.status_code == 200
    preprocess_result = preprocess_response.json()
    
    # Simulate Cairo computation result
    cairo_result = {
        "analysis": {
            "trend": 0,
            "vol_limit": 7907193
        }
    }
    
    # Test postprocessing
    postprocess_response = client.post(
        "/postprocess",
        json={
            "result": json.dumps(cairo_result),
            "request_id": "test-integration"
        }
    )
    assert postprocess_response.status_code == 200
    
    final_result = json.loads(postprocess_response.json())
    assert final_result["results"]["trend"] == "Up"
    assert final_result["results"]["vol_limit"] == 7907193
    assert final_result["request_id"] == "test-integration"