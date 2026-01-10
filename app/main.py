import json
import os
import boto3
import psycopg2
from psycopg2 import sql
import logging

# הגדרת לוגים (CloudWatch אוהב את זה)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# שליפת משתני סביבה (הסיסמאות יגיעו מכאן, לא מהקוד)
DB_HOST = os.environ.get('DB_HOST')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASS = os.environ.get('DB_PASS')

s3_client = boto3.client('s3')

def get_db_connection():
    """יצירת חיבור למסד הנתונים"""
    conn = psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    return conn

def init_db():
    """וידוא שהטבלה והתוסף PostGIS קיימים"""
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        # 1. הפעלת תוסף PostGIS
        cur.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
        
        # 2. יצירת טבלה אם לא קיימת
        # שים לב: אנחנו שומרים את הגיאומטריה כסוג GEOGRAPHY או GEOMETRY
        cur.execute("""
            CREATE TABLE IF NOT EXISTS geospatial_data (
                id SERIAL PRIMARY KEY,
                properties JSONB,
                geom GEOMETRY(Geometry, 4326),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        logger.info("Database initialized successfully (PostGIS + Table).")
    except Exception as e:
        logger.error(f"Error initializing DB: {e}")
        conn.rollback()
    finally:
        cur.close()
        conn.close()

def lambda_handler(event, context):
    """
    זו הפונקציה הראשית שתרוץ כשקובץ עולה ל-S3
    """
    # אתחול ה-DB בריצה הראשונה
    init_db()

    # שליפת שם הדלי והקובץ מתוך האירוע (Event)
    # זה עובד גם בלמבדה וגם בסימולציה מקומית
    try:
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"Processing file: {key} from bucket: {bucket}")

            # הורדת הקובץ מ-S3 לזיכרון
            response = s3_client.get_object(Bucket=bucket, Key=key)
            file_content = response['Body'].read().decode('utf-8')
            geojson_data = json.loads(file_content)

            # ולידציה בסיסית
            if 'features' not in geojson_data:
                logger.error("Invalid GeoJSON: No 'features' found.")
                continue

            # שמירה לדאטה-בייס
            conn = get_db_connection()
            cur = conn.cursor()
            
            count = 0
            for feature in geojson_data['features']:
                geom = json.dumps(feature['geometry'])
                props = json.dumps(feature['properties'])
                
                # שאילתת SQL חכמה שממירה GeoJSON ישר לפורמט של PostGIS
                insert_query = """
                    INSERT INTO geospatial_data (properties, geom)
                    VALUES (%s, ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326));
                """
                cur.execute(insert_query, (props, geom))
                count += 1
            
            conn.commit()
            cur.close()
            conn.close()
            
            logger.info(f"Successfully loaded {count} features from {key}")

        return {"statusCode": 200, "body": "Success"}

    except Exception as e:
        logger.error(f"Error processing S3 event: {e}")
        return {"statusCode": 500, "body": str(e)}

# קוד בדיקה מקומי (אם מריצים את הקובץ ידנית במחשב)
if __name__ == "__main__":
    print("This script is designed to run as a Lambda handler or Container task.")