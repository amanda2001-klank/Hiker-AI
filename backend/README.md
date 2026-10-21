# APP Venture FastAPI Backend & PostgreSQL

## Exact Windows Commands to Run & Verify

1. **Install Python Dependencies**:
   ```bash
   cd backend
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Configure PostgreSQL & Create Database**:
   - Ensure PostgreSQL is running locally on port `5432`.
   - Create the database:
     ```sql
     CREATE DATABASE app_venture;
     ```
   - Verify/update database credentials in `.env`:
     ```env
     DATABASE_URL=${DATABASE_URL}
     SECRET_KEY=supersecretkeyappventure2026
     ALGORITHM=HS256
     ACCESS_TOKEN_EXPIRE_MINUTES=1440
     ```

3. **Apply Alembic Migrations / Initialize Tables**:
   ```bash
   alembic upgrade head
   ```

4. **Start FastAPI on Port 8000**:
   ```bash
   uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
   ```

5. **Verify API Documentation**:
   - Open browser at: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

6. **Run Backend Unit Tests**:
   ```bash
   pytest tests/
   ```
