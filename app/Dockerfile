FROM public.ecr.aws/lambda/python:3.11

# העתקת קובץ הדרישות והתקנת ספריות
COPY requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt

# העתקת הקוד שלנו
COPY main.py ${LAMBDA_TASK_ROOT}

# הגדרת הפקודה שתרוץ (שם הקובץ.שם הפונקציה)
CMD [ "main.lambda_handler" ]