FROM public.ecr.aws/lambda/python:3.11

# --- הוספת השורה הזו: תיקון חורי אבטחה במערכת ההפעלה ---
# מעדכן את ספריית glib2 לגרסה האחרונה והמאובטחת
RUN yum update -y glib2

# העתקת קובץ הדרישות והתקנת ספריות
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt

# העתקת הקוד שלנו
COPY main.py ${LAMBDA_TASK_ROOT}

# הגדרת הפקודה שתרוץ
CMD [ "main.lambda_handler" ]