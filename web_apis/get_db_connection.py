import pyodbc
from fastapi import HTTPException

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
