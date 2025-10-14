use MIST460_RelationalDatabase_Lastname;

go

create or alter function fnFindCurrentSemester()
returns nvarchar(20)
as
begin
	declare @semester nvarchar(20);

	Set @semester =
    CASE 
        WHEN MONTH(GETDATE()) BETWEEN 1 AND 4 THEN 'Spring'
        WHEN MONTH(GETDATE()) BETWEEN 8 AND 12 THEN 'Fall'
		ELSE 'Summer'
    END

	return @semester;
end;

-- select dbo.fnFindCurrentSemester()

go

create or alter procedure procFindCurrentSemesterCourseOfferingsForSpecifiedCourse
(
	@subjectCode nvarchar(10), @courseNumber nvarchar(10)
)
as
begin
	select C.SubjectCode, C.CourseNumber, CO.CRN, CO.CourseOfferingID,
		CO.CourseOfferingSemester, CO.CourseOfferingYear, CO.NumberSeatsRemaining
	from Course C inner join CourseOffering CO
		on C.CourseID = CO.CourseID
	where C.SubjectCode = @subjectCode
		and C.CourseNumber = @courseNumber
		and CO.CourseOfferingYear  = Year(GetDate()) --  DatePart(Year, SYSDATETIME())
		and CO.CourseOfferingSemester = dbo.fnFindCurrentSemester()
end

/*
execute procFindCurrentSemesterCourseOfferingsForSpecifiedCourse
	@subjectCode = 'MIST', @courseNumber = '460';
*/

go

create or alter procedure procFindPrerequisites
(@subjectCode nvarchar(20), @courseNumber nvarchar(20))
as
begin
	select P.SubjectCode, P.CourseNumber
	from Course C join CoursePrerequisite CP
		on C.CourseID = CP.CourseID
		join Course P
		on P.CourseID = CP.CoursePrequisiteID
	where C.SubjectCode = @subjectCode and
		C.CourseNumber = @courseNumber
end;
/*
	execute procFindPrerequisites @subjectCode = 'MIST', @courseNumber = '460';
*/

go

create or alter function fnFindCoursePrerequisites
(
	@SubjectCode nvarchar(20), @CourseNumber nvarchar(20)
)
returns @PrerequisitesForSpecifiedCourse table
(
	SubjectCode nvarchar(20), 
	CourseNumber nvarchar(20)
)
as
begin
	insert into @PrerequisitesForSpecifiedCourse(SubjectCode, CourseNumber)
	select PrereqCourse.SubjectCode, PrereqCourse.CourseNumber
	from Course as MainCourse inner join CoursePrerequisite as CP
			on MainCourse.CourseID = CP.CourseID
			inner join Course as PrereqCourse
			on CP.PrereqCourseID = PrereqCourse.CourseID
	where MainCourse.SubjectCode = @SubjectCode and
			MainCourse.CourseNumber = @CourseNumber;
	return;
end;

/*
	select *
	from fnFindCoursePrerequisites('MIST', '460');
*/

go

create or alter function fnFindAllCoursesTakenByStudent
(
	--@StudentFullname nvarchar(100)
	@studentID int
)
returns table
as
return
	select /*A.FullName, R.RegistrationID, CRN, CO.CourseOfferingYear,*/ C.SubjectCode, C.CourseNumber
	from 
	/*AppUser A join Student S
		on A.AppUserID = S.StudentID
		join*/ Registration R
		--on R.StudentID = S.StudentID
		join RegistrationCourseOffering RCO
		on R.RegistrationID = RCO.RegistrationID
		join CourseOffering CO
		on RCO.CourseOfferingID = CO.CourseOfferingID
		join Course C
		on CO.CourseID = C.CourseID
		where R.StudentID = @studentID
		--where A.FullName = @StudentFullname --@fullname

/*
SELECT SubjectCode, CourseNumber
FROM fnFindAllCoursesTakenByStudent(1);
*/

go

create or alter procedure procCheckIfStudentHasTakenAllPrerequisitesForCourse
(
	@studentID int, @subjectCode nvarchar(10), @courseNumber nvarchar(10)
)
as
begin
	
	SELECT SubjectCode, CourseNumber 
	FROM fnFindCoursePrerequisites(@subjectCode, @courseNumber)
	EXCEPT
	SELECT SubjectCode, CourseNumber
	FROM fnFindAllCoursesTakenByStudent(@studentID);
		
end;

/*
declare @numberOfPrerequisitesNotTaken int;

execute @numberOfPrerequisitesNotTaken = procCheckIfStudentHasTakenAllPrerequisitesForCourse
	@studentID = 1, @subjectCode = 'MIST', @courseNumber = '460';
print @numberOfPrerequisitesNotTaken;

declare @numberOfPrerequisitesNotTaken int;

execute @numberOfPrerequisitesNotTaken = procCheckIfStudentHasTakenAllPrerequisitesForCourse
	@studentID = 2, @subjectCode = 'MIST', @courseNumber = '460';
print @numberOfPrerequisitesNotTaken;

*/

go

create or alter procedure procCheckIfStudentHasTakenAllPrerequisitesForCourseForEnrollment
(
	@studentID int, @subjectCode nvarchar(10), @courseNumber nvarchar(10)
)
as
begin

	
	declare @temptable table(SubjectCode nvarchar(10), CourseNumber nvarchar(10));

	insert into @temptable(SubjectCode, CourseNumber)

	SELECT SubjectCode, CourseNumber 
	FROM fnFindCoursePrerequisites(@subjectCode, @courseNumber)
	EXCEPT
	SELECT SubjectCode, CourseNumber
	FROM fnFindAllCoursesTakenByStudent(@studentID);
	
	declare @numberOfPrerequisitesNotTaken int;
	select @numberOfPrerequisitesNotTaken = count(*)
	from @temptable;

	return @numberOfPrerequisitesNotTaken
	
end;

/*
declare @numberOfPrerequisitesNotTaken int;

execute @numberOfPrerequisitesNotTaken = 
	procCheckIfStudentHasTakenAllPrerequisitesForCourseForEnrollment
	@studentID = 1, @subjectCode = 'MIST', @courseNumber = '460';
print @numberOfPrerequisitesNotTaken;

declare @numberOfPrerequisitesNotTaken int;

execute @numberOfPrerequisitesNotTaken = 
	procCheckIfStudentHasTakenAllPrerequisitesForCourseForEnrollment
	@studentID = 2, @subjectCode = 'MIST', @courseNumber = '460';
print @numberOfPrerequisitesNotTaken;

*/



go

create or alter function fnHowManyRemainingSeatsInCourseOffering
(
	@courseOfferingID int
)
returns int
begin
	declare @remainingSeats int;

	select @remainingSeats = NumberSeatsRemaining
	from CourseOffering
	where CourseOfferingID = @courseOfferingID;

	return @remainingSeats;
end;
--select dbo.fnHowManyRemainingSeatsInCourseOffering(1);

go

create or alter procedure procEnrollStudentInCourseOffering
(
	@studentID int, @courseOfferingID int, @enrollmentResponse nvarchar(200) output
)
as
begin
	declare @registrationID int, @remainingSeats int, @enrollmentSucceeded bit;

	set @enrollmentSucceeded = 1;
	set @enrollmentResponse = ' ';
	
	if (dbo.fnHowManyRemainingSeatsInCourseOffering(@courseOfferingID) <= 0)
	begin
		set @enrollmentSucceeded = 0
		set @enrollmentResponse = 'No openings in course offering.';
	end

	declare @numberOfPrerequisitesNotTaken int;

	declare @subjectCode nvarchar(10), @courseNumber nvarchar(10);

	select @subjectCode = C.SubjectCode, @courseNumber = C.CourseNumber
	from Course C join CourseOffering CO
		on C.CourseID = CO.CourseID
	where CO.CourseOfferingID = @courseOfferingID;

	-- Check if the student has gotten the required grade (at least a C) letterGrade >= 'C'
	-- Equivalent grade points 2.0 -> gradePoints >= 2.0
	-- Taking -> LetterGrade: Null, Taken -> LetterGrade: ?, EnrollmentStatus: Completed
	execute @numberOfPrerequisitesNotTaken = 
	procCheckIfStudentHasTakenAllPrerequisitesForCourseForEnrollment
		@studentID, @subjectCode, @courseNumber;

	if (@numberOfPrerequisitesNotTaken > 0)
	begin
		set @enrollmentSucceeded = 0
		set @enrollmentResponse = @enrollmentResponse + ' Missing prerequisites.'
	end;

	if(@enrollmentSucceeded = 1)
	begin

		select @registrationID = RegistrationID
		from Registration
		where StudentID = @studentID;

		begin try
			insert into RegistrationCourseOffering
			(RegistrationID, CourseOfferingID, EnrollmentStatus)
			values
			(@registrationID, @courseOfferingID, 'Enrolled');

			if @@ROWCOUNT = 0
				begin
					set @enrollmentSucceeded = 0
					set @enrollmentResponse = @enrollmentResponse + ' Enrollment failed.';
				end

		end try

		begin catch
			set @enrollmentSucceeded = 0
			-- Has the student previously taken the same course?
			-- allowed D/F repeat?
			if (ERROR_MESSAGE() like '%UQ_RegistrationCourseOffering%')
			begin				
				set @enrollmentResponse = @enrollmentResponse + ' Previously enrolled or taken course offering.'				
				return @enrollmentSucceeded;
			end;

		end catch

	end

	if (@enrollmentSucceeded = 1)
	begin
		set @enrollmentResponse = 'Enrolled in Course Offering.';
	end
	
	return @enrollmentSucceeded;--int

end;

/*
declare @enrollmentResponse nvarchar(100), @enrollmentSucceeded bit;

execute @enrollmentSucceeded = procEnrollStudentInCourseOffering
	@studentID = 2, @courseOfferingID = 15, @enrollmentResponse = @enrollmentResponse output;

print @enrollmentSucceeded;
print @enrollmentResponse;
*/

go

create or alter procedure procEnrollStudentInCourseOfferingCalled
(@studentID int, @courseOfferingID int)
as
begin
	set nocount on;
	declare @enrollmentSucceeded bit, @enrollmentResponse nvarchar(100);

	execute @enrollmentSucceeded = procEnrollStudentInCourseOffering
		@studentID = @studentID, @courseOfferingID = @courseOfferingID, 
		@enrollmentResponse = @enrollmentResponse output;

	declare @tempTable table(EnrollmentResponse nvarchar(100), EnrollmentSucceeded bit);

	insert into @temptable(EnrollmentResponse, EnrollmentSucceeded)
	values (@enrollmentResponse, @enrollmentSucceeded);

	select EnrollmentResponse,EnrollmentSucceeded
	from @tempTable;

end;
/*
execute procEnrollStudentInCourseOfferingCalled
@studentID = 1, @courseOfferingID = 15;
*/

go

create or alter trigger trgReduceAvailableSeats -- resulting action we need
on RegistrationCourseOffering -- table with the triggering event
after insert -- triggering event (inserted table mimics RegistrationCourseOffering), delete (deleted table), update (deleted, inserted tables)
as
begin
	declare @courseOfferingID int;
	select @courseOfferingID = CourseOfferingID	
	from inserted;

	update CourseOffering
	set NumberSeatsRemaining = NumberSeatsRemaining - 1
	where CourseOfferingID = @courseOfferingID;
end;

/*
select * from Registration where RegistrationID = 1;
select * from RegistrationCourseOffering where RegistrationID = 1;
select * from CourseOffering where CourseOfferingID = 15; -- 6->5

insert into RegistrationCourseOffering 
(RegistrationID, CourseOfferingID, EnrollmentStatus, LastUpdate)
values
(1, 16, 'Enrolled', getdate());
*/

go

create or alter procedure procGetStudentEnrolledCourseOfferings
(
	@studentId int
)
as
begin
	select CO.CourseOfferingID, CO.CRN, C.SubjectCode, C.CourseNumber,
		RCO.EnrollmentStatus, RCO.LastUpdate
	from Registration R join RegistrationCourseOffering RCO
		on R.RegistrationID = RCO.RegistrationID
		join CourseOffering CO
		on RCO.CourseOfferingID = CO.CourseOfferingID
		join Course C
		on CO.CourseID = C.CourseID
	where R.StudentID = @studentId;

end
/*
	execute procGetStudentEnrolledCourseOfferings @studentID = 1;
*/

go

create or alter procedure procDropStudentFromCourseOffering
(
	@registrationID int, @courseOfferingID int
)
as
begin

	set nocount on;

	update RegistrationCourseOffering
	set EnrollmentStatus = 'Dropped',
		LastUpdate = GETDATE()
	where RegistrationID = @registrationID
	     and CourseOfferingID  = @courseOfferingID;

end;

/*
execute procDropStudentFromCourseOffering
	@studentID = 1, @courseOfferingID = 15
*/

go

create or alter procedure procDropStudentFromCourseOfferingCalled
(
	@studentID int, @courseOfferingID int
)
as
begin
	set nocount on;

	declare @registrationID int;

	select @registrationID = RegistrationID
	from Registration
	where StudentID = @studentID;

	execute procDropStudentFromCourseOffering @registrationID = @registrationID, 
	@courseOfferingID = @courseOfferingID;

	select EnrollmentStatus, RegistrationID, CourseOfferingID, LastUpdate
	from RegistrationCourseOffering
	where RegistrationID = @registrationID and CourseOfferingID = @courseOfferingID;
end;

/*
execute procDropStudentFromCourseOfferingCalled
	@studentID = 1, @courseOfferingID = 15
*/



go

create or alter trigger trgUpdateAvailableSeats -- resulting action we need
on RegistrationCourseOffering -- table with the triggering event
after update -- triggering event (inserted table mimics RegistrationCourseOffering), delete (deleted table), update (deleted, inserted tables)
as
begin
	declare @courseOfferingID int, @enrollmentStatus nvarchar(12);
	select @courseOfferingID = CourseOfferingID, @enrollmentStatus = EnrollmentStatus
	from inserted;

	if(@enrollmentStatus = 'Dropped')
	begin
		update CourseOffering
		set NumberSeatsRemaining = NumberSeatsRemaining + 1
		where CourseOfferingID = @courseOfferingID;
	end;
end;

go
