from fastapi import FastAPI, HTTPException
from web_apis.validate_user import validate_user
from web_apis.find_current_semester_course_offerings import find_current_semester_course_offerings
from web_apis.find_prerequisites import find_prerequisites
from web_apis.check_if_student_has_taken_all_prerequisites_for_course import check_if_student_has_taken_all_prerequisites_for_course
from web_apis.enroll_student_in_course_offering import enroll_student_in_course_offering
from web_apis.get_student_enrolled_in_course_offerings import get_student_enrolled_in_course_offerings
from web_apis.drop_student_from_course_offering import drop_student_from_course_offering

# Swagger UI
app = FastAPI(docs_url="/", redoc_url=None)

def main():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

if __name__ == "__main__":
    main()

@app.get("/validate_user/")
def validate_user_api(username: str, password: str):
    return validate_user(username, password)

@app.get("/find_current_semester_course_offerings/")
def find_current_semester_course_offerings_api(subjectCode: str, courseNumber: str):
    return find_current_semester_course_offerings(subjectCode, courseNumber)

@app.get("/find_prerequisites/")
def find_prerequisites_api(subjectCode: str, courseNumber: str):
    return find_prerequisites(subjectCode, courseNumber)

@app.get("/check_if_student_has_taken_all_prerequisites_for_course/")
def check_if_student_has_taken_all_prerequisites_for_course_api(studentID: int, subjectCode: str, courseNumber: str):
    return check_if_student_has_taken_all_prerequisites_for_course(studentID, subjectCode, courseNumber)

@app.get("/enroll_student_in_course_offering/")
def enroll_student_in_course_offering_api(studentID: int, courseOfferingID: int):
    return enroll_student_in_course_offering(studentID, courseOfferingID)

@app.get("/get_student_enrolled_in_course_offerings/")
def get_student_enrolled_in_course_offerings_api(studentID: int):
    return get_student_enrolled_in_course_offerings(studentID)

@app.get("/drop_student_from_course_offering/")
def drop_student_from_course_offering_api(studentID: int, courseOfferingID: int):
    return drop_student_from_course_offering(studentID, courseOfferingID)
