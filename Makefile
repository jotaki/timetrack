all: timetrack

testdb:
	rm -f tmp.db
	sqlite3 tmp.db < src/sql/new.sql
	sqlite3 tmp.db < mockdata/mockdata.sql

timetrack:
	@make -C src
	@cp -vf src/timetrack.sh bin/timetrack
	@ln -sf bin/timetrack timetrack

clean:
	@make -C src clean
	@rm -fv bin/timetrack timetrack

sourcable:
	@make -C sourcable

reset: clean timetrack
