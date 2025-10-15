from web_apis.course_recommender_apis import get_db_connection

def find_current_semester_course_offerings(subject_code: str, course_number: str):
    # Connect to the database
    conn = get_db_connection()
    cursor = conn.cursor()

    # Ensure the connection was successful
    if not conn:
        raise HTTPException(status_code=500, detail="Database connection failed")

    # Execute the stored procedure
    cursor.execute("{CALL procFindCurrentSemesterCourseOfferings(?, ?)}", (subject_code, course_number))
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
