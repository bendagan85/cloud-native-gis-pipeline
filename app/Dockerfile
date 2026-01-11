FROM public.ecr.aws/lambda/python:3.11

# --- 1. התיקון לשגיאת הבנייה (GCC) ---
# אנחנו מתקינים כלי פיתוח (gcc, c++) כדי ש-numpy ו-geopandas יוכלו להתקין את עצמם
RUN yum update -y && \
    yum install -y gcc gcc-c++ python3-devel

# העתקת קובץ הדרישות והתקנת ספריות פייתון
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt

# העתקת הקוד שלנו
COPY main.py ${LAMBDA_TASK_ROOT}

# --- 2. התיקון עבור קוברנטיס ו-Flask ---
# שינינו את זה מ-CMD שמפעיל handler ל-ENTRYPOINT שמריץ את פייתון ישירות.
# זה יגרום לשרת (app.run) לרוץ מיד כשהפוד עולה ולהאזין לפורט 5000.
ENTRYPOINT [ "python", "main.py" ]