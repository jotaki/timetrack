all: timetrack

testdb:
	rm -f tmp.db
	sqlite3 tmp.db < src/sql/new.sql
	sqlite3 tmp.db < mockdata/mockdata.sql

timetrack:
	@make -C src
	@cp -vf src/timetrack.sh bin/timetrack
	@make -C src clean

clean:
	@rm -fv bin/timetrack

reset: clean timetrack
