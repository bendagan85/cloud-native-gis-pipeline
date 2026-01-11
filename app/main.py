import os
import json
import logging
import psycopg2
from flask import Flask, request, jsonify

# --- הגדרת השרת ---
app = Flask(__name__)

# לוגים (זה הולך ל-CloudWatch אוטומטית ב-EKS)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("GeoApp")

# משתני סביבה
DB_HOST = os.environ.get('DB_HOST')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASS = os.environ.get('DB_PASS')

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def init_db():
    """אתחול הטבלה והרחבת PostGIS"""
    try:
        conn = get_db_connection()
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS geospatial_data (
                id SERIAL PRIMARY KEY,
                properties JSONB,
                geom GEOMETRY(Geometry, 4326),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        logger.info("DB Initialized successfully")
        cur.close()
        conn.close()
    except Exception as e:
        logger.error(f"DB Init Error: {e}")

# --- נתיב 1: התצוגה (מה שרואים בדפדפן) ---
@app.route('/', methods=['GET'])
def index():
    try:
        # בדיקה כמה שורות יש בטבלה
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT count(*) FROM geospatial_data;")
        count = cur.fetchone()[0]
        cur.close()
        conn.close()
        
        # HTML פשוט ויפה שמראה שהכל עובד
        return f"""
        <html>
            <body style="font-family: Arial; text-align: center; padding-top: 50px;">
                <h1 style="color: #2c3e50;">🌍 ASTERRA Geo-App (Kubernetes)</h1>
                <p>Status: <strong>Online</strong></p>
                <div style="border: 2px solid #27ae60; display: inline-block; padding: 20px; border-radius: 10px;">
                    <h2>Processed Records in DB</h2>
                    <h1 style="color: #27ae60; font-size: 50px; margin: 0;">{count}</h1>
                </div>
                <p style="color: gray; margin-top: 20px;">Powered by Flask, PostGIS & EKS</p>
            </body>
        </html>
        """, 200
    except Exception as e:
        return f"Error connecting to DB: {str(e)}", 500

# --- נתיב 2: קליטת נתונים (Ingest) ---
@app.route('/ingest', methods=['POST'])
def ingest():
    try:
        data = request.json
        if 'features' not in data:
            return jsonify({"error": "Invalid GeoJSON"}), 400

        conn = get_db_connection()
        cur = conn.cursor()
        
        inserted = 0
        for feature in data['features']:
            geom = json.dumps(feature['geometry'])
            props = json.dumps(feature['properties'])
            
            # שאילתה חכמה של PostGIS
            query = "INSERT INTO geospatial_data (properties, geom) VALUES (%s, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))"
            cur.execute(query, (props, geom))
            inserted += 1
            
        conn.commit()
        cur.close()
        conn.close()
        
        logger.info(f"Inserted {inserted} records.")
        return jsonify({"status": "success", "count": inserted}), 200

    except Exception as e:
        logger.error(f"Ingest Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    init_db()
    app.run(host='0.0.0.0', port=5000)