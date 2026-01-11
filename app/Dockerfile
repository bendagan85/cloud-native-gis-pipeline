# משתמשים באימג' פייתון רשמי וקל משקל (הרבה יותר ידידותי ל-GeoPandas)
FROM python:3.11-slim

# הגדרת תיקיית העבודה (סטנדרט של דוקר)
WORKDIR /app

# התקנת כלי מערכת בסיסיים שיעזרו בבנייה (GCC וכד')
# אלו פקודות של Debian/Ubuntu ולא של Amazon Linux
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# העתקת קובץ הדרישות והתקנה
COPY requirements.txt .
# --no-cache-dir מונע מהאימג' להתנפח סתם
RUN pip install --no-cache-dir -r requirements.txt

# העתקת הקוד שלנו
COPY main.py .

# חשיפת הפורט (דוקומנטציה בלבד, אבל טוב שיהיה)
EXPOSE 5000

# הרצת השרת
# שים לב: אנחנו מריצים את main.py ישירות
CMD ["python", "main.py"]