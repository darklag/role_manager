## Install

```
make
make install

```
Log into database:

```
CREATE SCHEMA role_manager;
CREATE EXTENSION role_manager SCHEMA role_manager;
```
To install cluster-wide on all existing databases, use the following SQL to create a script
```
example=# \t
Showing only tuples.
example=# \o create_schema.sh
example=# select 'psql -d '||datname||' -c "CREATE SCHEMA role_manager"' from pg_database where datallowconn order by datname;
Time: 2.218 ms
example=# \o create_roleman_extension.sh
example=# select 'psql -d '||datname||' -c "CREATE EXTENSION role_manager SCHEMA role_manager"' from pg_database where datallowconn order by datname;
Time: 0.769 ms
example=# \o
example=# \t
Tuples only is off.
```
Note that this will also install it to the "template1" database, which ensures the extension
is installed on all future databases automatically. If the extension is ever updated, make sure the
new version of the extension is re-installed to $SHAREDIR/extension. Running make/make install again
on the new version should take care of this automatically. This will ensure that template1 installs
the latest version of the extension to new databases.

## Update

To update the extension, copy the update file(s) to the $SHAREDIR/extension directory.
$SHAREDIR can be determined by running: pg_config --sharedir
For a single database, run the following while connected to that database (with the relevant version number):
```
ALTER EXTENSION role_manager UPDATE TO '1.0.2'
```
If you need to update the extension across all databases in a cluster, the following SQL can
be used to create a script. 
```
example=# \t
Showing only tuples.
example=# \o update_roleman.sh
example=# select 'psql -d '||datname||' -c "ALTER EXTENSION role_manager UPDATE TO ''1.0.1''"' from pg_database where datallowconn order by datname;
Time: 6.387 ms
example=# \o
example=# \t
Tuples only is off.
```

## Setup Example
Application name: example
Database name: example_us_production

Create the 3 standard roles and generate passwords for them:
```
example_us_production=# select * from role_manager.create_app_roles('example');
     rolename     |   password   
------------------+--------------
 example_app      | GXkjw0D4djLv
 example_readonly | 9pOwCmuzsPRW
 example_owner    | wVh8Kd0Q0azl
(3 rows)
```

Set the default privileges for the example_owner role and adjust the ownership and privileges of all current objects:

```
example_us_production=# select role_manager.set_app_privileges('example');
 set_app_privileges 
--------------------
 
(1 row)

example=# \dt 
           List of relations
 Schema | Name | Type  |     Owner     
--------+------+-------+---------------
 public | test | table | example_owner
(1 row)

example=# \ddp
                        Default access privileges
     Owner     | Schema |   Type   |          Access privileges          
---------------+--------+----------+-------------------------------------
 example_owner |        | function | =X/example_owner                   +
               |        |          | example_app=X/example_owner        +
               |        |          | example_owner=X/example_owner
 example_owner |        | sequence | example_app=rwU/example_owner      +
               |        |          | example_owner=rwU/example_owner
 example_owner |        | table    | example_app=arwdD/example_owner    +
               |        |          | example_readonly=r/example_owner   +
               |        |          | example_owner=arwdDxt/example_owner
(3 rows)
```

## Functions
*create_app_roles(p_appname text, p_app_role boolean DEFAULT true, p_readonly_role boolean DEFAULT true, p_owner_role boolean DEFAULT true, p_set_password boolean DEFAULT true, p_password_length int DEFAULT 12, out rolename text, out password text) RETURNS SETOF record*
 * Creates the 3 standard roles for a given application: appname_owner, appname_app, appname_readonly.
 * p_appname - Application name used as a basename for all roles. Replaces "appname" in above 3 examples.
 * p_app_role, p_owner_role, p_readonly_role - parameters to control creating each role. Default to true. Set any one to false to avoid creating that role.
 * p_set_password - By default a randomly generated password will be set for each role. You can stop this by setting this parameter to false.
 * p_password_length - Set the length of the password. Defaults to 12 characters.
 * This function can be run from any database since roles are created cluster-wide.
 * Returns a row set with the new role name and password for each role created.


*set_app_privileges (p_appname text,  p_owner boolean DEFAULT false, p_debug boolean DEFAULT false) RETURNS void*
 * Unlike create_app_roles(), this function must be run on the database the roles will be using.
 * Alters the default privileges of the appname_owner role so that any objects created by it will give the proper privilges to appname_app and appname_readonly.
 * Sets the privileges on ALL objects in the current database for the above roles as follows:
 * Owner role 
   * All object in database are changed to being owned by this role
 * App role 
   * All schemas are given USAGE
   * All database tables are given SELECT, INSERT, UPDATE, DELETE, TRUNCATE privileges 
   * All functions are given EXECUTE privilege
   * All sequences are given USAGE, SELECT, UPDATE privileges
 * Readonly role 
   * All schemas are given USAGE privilege
   * All tables are given SELECT privilege
 * p_owner - Setting this to true actually changes the ownership of all objects in the database, and the database itself, to the owner role. This can be distruptive on large, busy databases so the default is false.
 * Note that set_app_privileges does NOT revoke any current privileges. It only adds additional grants.


*drop_app_roles(p_appname text, p_app_role boolean DEFAULT true, p_readonly_role boolean DEFAULT true, p_owner_role boolean DEFAULT true) RETURNS text*
 * Drop the 3 default roles if they exist.
 * p_appname - Application name used when create_app_roles() was run.
 * p_app_role, p_owner_role, p_readonly_role - parameters to control dropping each role. Default to true. Set any one to false to avoid dropping that role.
 * Note that if any current objects are owned or have privileges granted to these roles, this function will fail. This is inherent in the DROP ROLE command in postgresql.


