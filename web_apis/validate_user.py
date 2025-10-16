from fastapi import HTTPException
from web_apis.get_db_connection import get_db_connection

def validate_user(username: str, password: str):
    # Connect to the database
    # TODO
    return {"is_valid": True}