FROM public.ecr.aws/lambda/python:3.11

# --- עדכון אבטחה גורף ---
# במקום לתקן חבילה ספציפית, אנחנו מעדכנים את כל מערכת ההפעלה
# זה יתקן את libpng, glib2 וכל פרצת אבטחה עתידית שתתגלה בלינוקס הזה
RUN yum update -y

# העתקת קובץ הדרישות והתקנת ספריות פייתון
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt

# העתקת הקוד שלנו
COPY main.py ${LAMBDA_TASK_ROOT}

# הגדרת הפקודה שתרוץ
CMD [ "main.lambda_handler" ]