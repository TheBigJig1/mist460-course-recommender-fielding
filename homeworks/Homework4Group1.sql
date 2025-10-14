-- Homework 4 - Group 1
-- Authors: Nada Mikky, Jaxon Fielding, Olivia Gottlieb
-- Description: contains Stored Procedures, UDFs, and Triggers for MIS assignment
USE MIST460_RelationalDatabase_Lastname;
GO

-- Stored Procedures, User Defined Functions, Triggers

/* =================================================================================
    1. When a student enrolls in a Course Offering, the number of seats available should be reduced.
    (As a student, need to know if any seats are available in a course offering) 
    DONE BY NADA
================================================================================= */

create or alter trigger trgReduceAvailableSeats -- resulting actions we need
on registrationCourseOffering -- table where event is happening

-- trigger event/action (inserted table mimics registrationCourseOffering, 
-- delete ( removes table) 
-- updated (deleted, inserted)
after insert 

as
begin

declare @courseOfferingID int;
select @courseOfferingID = CourseOfferingID
from inserted;

update CourseOffering
set NumberSeatsRemaining = NumberSeatsRemaining -1
where  CourseOfferingID = @courseOfferingID;
END;
GO
/*
TEST EXAMPLE: WORKS

select * from Registration; 
select * from registrationCourseOffering where RegistrationID =1; 
select * from CourseOffering where CourseOfferingID = 16; -- remaining seats = 3

insert into registrationCourseOffering 
(RegistrationID, CourseOfferingID, EnrollmentStatus, LastUpdate)
values (1, 16, 'Enrolled', getdate()) 
*/


/* =================================================================================
    2. When a student withdraws from a Course Offering, the number of seats available should be increased.
    (Again, as a student, need to know if any seats are available in a course offering) 
    DONE BY NADA
================================================================================= */
create or alter trigger trgIncreaseAvailableSeats -- resulting action we need
on RegistrationCourseOffering -- table where the event is happening
after update -- fires after EnrollmentStatus is updated
as
begin
    set nocount on;

    declare @courseOfferingID int;

    -- get the CourseOfferingID only when EnrollmentStatus changes from Enrolled to Dropped
    select @courseOfferingID = CourseOfferingID
    from deleted

    -- increase available seats by 1 for that course offering
    update CourseOffering
    set NumberSeatsRemaining = NumberSeatsRemaining + 1
    where CourseOfferingID = @courseOfferingID;
    end;
    go

    /*
    TEST EXAMPLE: WORKSSSS

    select * from Registration; 
    select * from registrationCourseOffering where RegistrationID =1; 

    1. excute this: 
    select * from CourseOffering where CourseOfferingID = 16; --3

    2. Excute:
    update RegistrationCourseOffering
    set EnrollmentStatus = 'Dropped',
        LastUpdate = getdate()
    where RegistrationID = 1
    and CourseOfferingID = 16;

    3. Excute again: it sould increment the NumberSeatsRemaining 
    select * from CourseOffering where CourseOfferingID = 16; --3

    */

/* =================================================================================
    3. When a student is assigned a grade for a Course Offering, the student's GPA should include that grade.
    (As a student, need to know that their GPA is correctly calculated and current).
    DONE BY Jaxon
================================================================================= */

IF COL_LENGTH('dbo.Student','GPA') IS NULL
BEGIN
    ALTER TABLE dbo.Student ADD GPA DECIMAL(4,3) NULL; -- store current cumulative GPA
END;
GO

-- Convert a letter grade to grade points (4.000 scale)
CREATE OR ALTER FUNCTION ufnGetGradePoints(@Letter NCHAR(2))
RETURNS DECIMAL(4,3)
AS
BEGIN
    DECLARE @GPA DECIMAL(4,3);
    SET @Letter = UPPER(TRIM(@Letter));
    SET @GPA = CASE @Letter
                WHEN 'A'  THEN 4.000
                WHEN 'B'  THEN 3.000
                WHEN 'C'  THEN 2.000
                WHEN 'D'  THEN 1.000
                WHEN 'F'  THEN 0.000
                ELSE NULL
            END;
    RETURN @GPA;    
END;
GO

-- Trigger 
CREATE OR ALTER TRIGGER trgAfterInsertUpdateGrade
ON dbo.RegistrationCourseOffering
AFTER INSERT, UPDATE
AS
BEGIN

    SET NOCOUNT ON;

    DECLARE @StudentId INT, @NewGPA DECIMAL(4,3);

    IF EXISTS (SELECT 1 FROM inserted WHERE FinalGrade IS NOT NULL)
    BEGIN
        -- Get the StudentId from the inserted rows
        SELECT TOP 1 @StudentId = r.StudentId
        FROM inserted i
        JOIN dbo.Registration r ON i.RegistrationID = r.RegistrationID; 

        -- Calculate the new GPA
        SELECT @NewGPA = AVG(dbo.ufnGetGradePoints(i.FinalGrade))
        FROM dbo.RegistrationCourseOffering i
        JOIN dbo.Registration r ON i.RegistrationID = r.RegistrationID
        WHERE r.StudentId = @StudentId AND i.FinalGrade IS NOT NULL;
        
        -- Update the Student's GPA
        UPDATE dbo.Student
        SET GPA = @NewGPA
        WHERE StudentId = @StudentId;
    END
END;
GO

/* -- Test Example:
DECLARE @StudentID INT = 1; 
DECLARE @TargetRCOID INT;

-- See current GPA and that student's course offerings
SELECT StudentID, GPA AS CurrentGPA_Before
FROM Student
WHERE StudentID = @StudentID;

SELECT rco.RegistrationCourseOfferingID,
       rco.FinalGrade,
       rco.RegistrationID
FROM RegistrationCourseOffering rco
JOIN Registration r ON rco.RegistrationID = r.RegistrationID
WHERE r.StudentID = @StudentID
ORDER BY rco.RegistrationCourseOfferingID;

-- Choose a specific RegistrationCourseOffering row to grade and update
SELECT TOP (2) @TargetRCOID = rco.RegistrationCourseOfferingID
FROM RegistrationCourseOffering rco
JOIN Registration r ON rco.RegistrationID = r.RegistrationID
WHERE r.StudentID = @StudentID;

UPDATE rco
SET FinalGrade = 'A'
FROM RegistrationCourseOffering rco
WHERE rco.RegistrationCourseOfferingID = @TargetRCOID;

-- Show GPA after trigger fires.
SELECT StudentID, GPA AS CurrentGPA_After
FROM Student
WHERE StudentID = @StudentID;

SELECT rco.RegistrationCourseOfferingID,
       rco.FinalGrade,
       rco.RegistrationID
FROM RegistrationCourseOffering rco
JOIN Registration r ON rco.RegistrationID = r.RegistrationID
WHERE r.StudentID = @StudentID
ORDER BY rco.RegistrationCourseOfferingID;

GO 

-- End test */


/* =================================================================================
    4. When a student rates a course offering, the average course offering rating should include that rating.
    (As an instructor, need to know that the course rating is correct and current).
    DONE BY OLIVIA
================================================================================= */
create or alter trigger trgUpdateAverageCourseRating
on RegistrationCourseOfferingRating
after insert, update, delete
as
begin
    set nocount on;

    declare @courseOfferingID int;

    -- Determine the CourseOfferingID based on the operation (insert, update, delete)
    if EXISTS (SELECT 1 FROM inserted)
    begin
        select @courseOfferingID = co.CourseOfferingID
        from inserted i
        join RegistrationCourseOffering rco ON i.RegistrationCourseOfferingID = rco.RegistrationCourseOfferingID
        join CourseOffering co ON rco.CourseOfferingID = co.CourseOfferingID;
    end
    else if EXISTS (SELECT 1 FROM deleted)
    begin
        select @courseOfferingID = co.CourseOfferingID
        from deleted d
        join RegistrationCourseOffering rco ON d.RegistrationCourseOfferingID = rco.RegistrationCourseOfferingID
        join CourseOffering co ON rco.CourseOfferingID = co.CourseOfferingID;
    end

    -- Update the CourseOfferingAverageRating for the CourseOffering
    if @courseOfferingID is not null
    begin
        update CourseOffering
        set CourseOfferingAverageRating = (
            select AVG(CAST(RatingValue AS FLOAT))
            from RegistrationCourseOfferingRating rcor
            join RegistrationCourseOffering rco ON rcor.RegistrationCourseOfferingID = rco.RegistrationCourseOfferingID
            where rco.CourseOfferingID = @courseOfferingID
        )
        where CourseOfferingID = @courseOfferingID;
    end
end;
go
/*
TEST EXAMPLE: WORKS
select * from CourseOffering where CourseOfferingID = 16; -- CourseOfferingAverageRating is null
    insert into RegistrationCourseOfferingRating
        (RegistrationCourseOfferingID, RatingValue, Comments)
        values (16, 5, 'Great course!') -- assuming 16 is a valid RegistrationCourseOfferingID

select * from CourseOffering where CourseOfferingID = 16; -- CourseOfferingAverageRating is now 5
    insert into RegistrationCourseOfferingRating
        (RegistrationCourseOfferingID, RatingValue, Comments)
        values (16, 3, 'Good course!') -- assuming 16 is a valid RegistrationCourseOfferingID

select * from CourseOffering where CourseOfferingID = 16; -- CourseOfferingAverageRating is now 4
    update RegistrationCourseOfferingRating
    set RatingValue = 4
        where RegistrationCourseOfferingRatingID = 1; -- assuming 1 is a valid RegistrationCourseOfferingID

select * from CourseOffering where CourseOfferingID = 16; -- CourseOfferingAverageRating is now 3.5
    delete from RegistrationCourseOfferingRating
        where RegistrationCourseOfferingRatingID = 1; -- assuming 1 is a valid RegistrationCourseOfferingID

select * from CourseOffering where CourseOfferingID = 16; -- CourseOfferingAverageRating is now 4
*/