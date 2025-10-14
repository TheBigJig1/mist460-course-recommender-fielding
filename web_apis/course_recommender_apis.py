from fastapi import FastAPI, HTTPException
# from pydantic import BaseModel
import pyodbc

app = FastAPI()

def main():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

if __name__ == "__main__":
    main()

# Database connection parameters
DB_SERVER   = 'localhost,1433'
DB_DATABASE = 'MIST460_RelationalDatabase_Lastname'
DB_USER     = 'SA'
DB_PASSWORD = 'Str0ng#Pass2025'
DB_DRIVER   = 'ODBC Driver 18 for SQL Server'

def get_db_connection():
    try:
        conn_str = f'DRIVER={{{DB_DRIVER}}};SERVER={DB_SERVER};DATABASE={DB_DATABASE};UID={DB_USER};PWD={DB_PASSWORD}'
        return pyodbc.connect(conn_str)
    
    except Exception as e:
        print(f"Error connecting to database: {e}")
        raise HTTPException(status_code=500, detail="Database connection failed")

    return None

@app.get("/find_current_semester_course_offerings")
def find_current_semester_course_offerings(subject_code: str, course_number: str):
    # Connect to the database
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # Ensure the connection was successful
    if not conn:
        raise HTTPException(status_code=500, detail="Database connection failed")

    # Execute the stored procedure
    cursor.execute("{CALL procFindCurrentSemesterCourseOfferingsForSpecifiedCourse(?, ?)}", (subject_code, course_number))
    rows = cursor.fetchall()

    # Close the connection
    cursor.close()
    conn.close()

    # Convert rows to a list of dictionaries for better JSON serialization
    results = [
        {
            "SubjectCode": row.SubjectCode,
            "CourseNumber": row.CourseNumber,
            "CRN": row.CRN,
            "CourseOfferingID": row.CourseOfferingID,
            "CourseOfferingSemester": row.CourseOfferingSemester,
            "CourseOfferingYear": row.CourseOfferingYear,
            "NumberSeatsRemaining": row.NumberSeatsRemaining
        }
        for row in rows
    ]

    return {"data": results}
