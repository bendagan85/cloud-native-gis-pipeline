import os
import json
import logging
import threading
import time
import boto3
import psycopg2
from flask import Flask, jsonify

# --- הגדרות ---
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("GeoApp")

# כתובת התור שלך
SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/002757291574/dev-ingest-queue"
AWS_REGION = "us-east-1"

# משתני דאטה-בייס
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
    """אתחול הטבלה"""
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

# --- פונקציית העבודה ברקע (SQS Listener) ---
def poll_sqs():
    """פונקציה שרצה ברקע, מאזינה ל-SQS ומעבדת קבצים"""
    logger.info("Starting SQS Polling Worker...")
    sqs = boto3.client('sqs', region_name=AWS_REGION)
    s3 = boto3.client('s3', region_name=AWS_REGION)

    while True:
        try:
            # 1. משיכת הודעה מהתור
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20  # Long Polling
            )

            if 'Messages' in response:
                for message in response['Messages']:
                    logger.info(f"Processing message: {message['MessageId']}")
                    
                    # 2. פענוח ההודעה (S3 Event)
                    body = json.loads(message['Body'])
                    
                    # בדיקה שזו אכן הודעה מ-S3
                    if 'Records' in body:
                        for record in body['Records']:
                            bucket_name = record['s3']['bucket']['name']
                            file_key = record['s3']['object']['key']
                            
                            logger.info(f"Downloading file: {file_key} from {bucket_name}")

                            # 3. הורדת הקובץ מ-S3
                            obj = s3.get_object(Bucket=bucket_name, Key=file_key)
                            file_content = obj['Body'].read().decode('utf-8')
                            geo_data = json.loads(file_content)

                            # 4. הכנסה לדאטה-בייס
                            insert_geojson_to_db(geo_data)

                    # 5. מחיקת ההודעה מהתור (כדי שלא נעבד אותה שוב)
                    sqs.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=message['ReceiptHandle']
                    )
            else:
                # אם אין הודעות, נחים קצת
                pass

        except Exception as e:
            logger.error(f"Worker Error: {e}")
            time.sleep(5)

def insert_geojson_to_db(data):
    """פונקציית עזר להכנסת הנתונים"""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        inserted = 0
        for feature in data['features']:
            geom = json.dumps(feature['geometry'])
            props = json.dumps(feature['properties'])
            
            query = "INSERT INTO geospatial_data (properties, geom) VALUES (%s, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))"
            cur.execute(query, (props, geom))
            inserted += 1
            
        conn.commit()
        cur.close()
        conn.close()
        logger.info(f"Successfully inserted {inserted} records from S3 file.")
    except Exception as e:
        logger.error(f"DB Insert Error: {e}")

# --- השרת (התצוגה) ---
@app.route('/', methods=['GET'])
def index():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        # שליפת 10 הרשומות האחרונות + ספירה כללית
        cur.execute("SELECT count(*) FROM geospatial_data;")
        total_count = cur.fetchone()[0]

        cur.execute("SELECT id, properties, created_at FROM geospatial_data ORDER BY id DESC LIMIT 10;")
        rows = cur.fetchall()
        
        cur.close()
        conn.close()
        
        # בניית טבלה ב-HTML
        table_rows = ""
        for row in rows:
            table_rows += f"<tr><td>{row[0]}</td><td>{row[1]}</td><td>{row[2]}</td></tr>"

        return f"""
        <html>
            <head>
                <style>
                    body {{ font-family: Arial, sans-serif; text-align: center; background-color: #f4f4f9; }}
                    table {{ margin: 0 auto; border-collapse: collapse; width: 80%; background: white; }}
                    th, td {{ padding: 12px; border: 1px solid #ddd; text-align: left; }}
                    th {{ background-color: #2c3e50; color: white; }}
                    tr:nth-child(even) {{ background-color: #f2f2f2; }}
                    .card {{ background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: inline-block; margin-bottom: 20px; }}
                </style>
                <meta http-equiv="refresh" content="5"> </head>
            <body>
                <h1 style="color: #2c3e50;">🌍 ASTERRA Live Dashboard</h1>
                
                <div class="card">
                    <h3>Total Records Processed</h3>
                    <h1 style="color: #27ae60; margin: 0;">{total_count}</h1>
                </div>

                <h3>Recent Data Ingested (Last 10)</h3>
                <table>
                    <tr>
                        <th>ID</th>
                        <th>Properties (JSON)</th>
                        <th>Ingested At</th>
                    </tr>
                    {table_rows}
                </table>
                <p style="color: gray; margin-top: 20px;">*Page refreshes automatically every 5 seconds</p>
            </body>
        </html>
        """, 200
    except Exception as e:
        return f"Error: {str(e)}", 500

# --- הרצה ---
if __name__ == "__main__":
    init_db()
    
    # הפעלת ה-Worker בתהליך נפרד (Thread)
    worker_thread = threading.Thread(target=poll_sqs)
    worker_thread.daemon = True # יסגר כשהתוכנית הראשית נסגרת
    worker_thread.start()
    
    # הפעלת השרת
    app.run(host='0.0.0.0', port=5000)