from flask import Flask, jsonify, request
from flask_cors import CORS
from datetime import datetime
import pytz

app = Flask(__name__)
CORS(app)

# Major cities with their timezones
MAJOR_CITIES = {
    "New York": "America/New_York",
    "London": "Europe/London",
    "Tokyo": "Asia/Tokyo",
    "Sydney": "Australia/Sydney",
    "Dubai": "Asia/Dubai",
    "Singapore": "Asia/Singapore",
    "São Paulo": "America/Sao_Paulo",
    "Mumbai": "Asia/Kolkata",
    "Paris": "Europe/Paris",
    "Los Angeles": "America/Los_Angeles",
    "Hong Kong": "Asia/Hong_Kong",
    "Berlin": "Europe/Berlin"
}

@app.route('/api/time', methods=['GET'])
def get_time():
    """Get current time for a specific timezone"""
    timezone = request.args.get('timezone', 'UTC')
    
    try:
        tz = pytz.timezone(timezone)
        current_time = datetime.now(tz)
        
        return jsonify({
            "timezone": timezone,
            "datetime": current_time.isoformat(),
            "time": current_time.strftime("%H:%M:%S"),
            "date": current_time.strftime("%Y-%m-%d"),
            "day": current_time.strftime("%A"),
            "offset": current_time.strftime("%z"),
            "offset_hours": int(current_time.strftime("%z")[:3]),
            "is_dst": bool(current_time.dst())
        })
    except pytz.exceptions.UnknownTimeZoneError:
        return jsonify({"error": "Unknown timezone"}), 400

@app.route('/api/timezones', methods=['GET'])
def get_timezones():
    """List all available timezones by region"""
    all_timezones = pytz.all_timezones
    
    # Group timezones by region
    regions = {}
    for tz in all_timezones:
        if '/' in tz:
            region = tz.split('/')[0]
            if region not in regions:
                regions[region] = []
            regions[region].append(tz)
    
    return jsonify({
        "count": len(all_timezones),
        "regions": regions,
        "common_timezones": pytz.common_timezones
    })

@app.route('/api/world-clocks', methods=['GET'])
def get_world_clocks():
    """Get time for multiple major cities simultaneously"""
    cities_data = []
    
    for city, timezone in MAJOR_CITIES.items():
        try:
            tz = pytz.timezone(timezone)
            current_time = datetime.now(tz)
            
            # Determine if it's day or night (6 AM to 6 PM is day)
            hour = current_time.hour
            is_day = 6 <= hour < 18
            
            cities_data.append({
                "city": city,
                "timezone": timezone,
                "datetime": current_time.isoformat(),
                "time": current_time.strftime("%H:%M:%S"),
                "time_12h": current_time.strftime("%I:%M:%S %p"),
                "date": current_time.strftime("%Y-%m-%d"),
                "day": current_time.strftime("%A"),
                "offset": current_time.strftime("%z"),
                "offset_hours": int(current_time.strftime("%z")[:3]),
                "is_day": is_day,
                "is_dst": bool(current_time.dst())
            })
        except Exception as e:
            cities_data.append({
                "city": city,
                "error": str(e)
            })
    
    return jsonify({
        "cities": cities_data,
        "count": len(cities_data)
    })

# Keep backward compatibility with the old /time endpoint
@app.route('/time', methods=['GET'])
def get_current_time():
    """Legacy endpoint for backward compatibility"""
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    return jsonify({"current_time": current_time})

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)