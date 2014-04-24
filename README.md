## Install

```
make
make install

```
Log into database:

```
CREATE EXTENSION role_manager;
```

## Setup 
To create the 3 standard roles for a given application run:
```
SELECT create_app_roles('appname');
```
This will create: appname_owner, appname_app, appname_readonly

The set_app_privileges() function sets the default privileges for the above roles as follows

 * Owner role - all object in database are changed to being owned by this role
 * App role - All schemas are given USAGE
            - All database tables are given SELECT, INSERT, UPDATE, DELETE, TRUNCATE privileges. 
            - All functions are given EXECUTE.
            - All sequences are given USAGE, SELECT, UPDATE
 * Readonly role - All schemas are given USAGE
                 - All tables are given SELECT

```
SELECT set_app_privileges('appname', true);
```
The **p_owner** parameter in set_app_privileges allows setting the object ownership to be skipped by setting it to false.
This can be useful when changing an existing app to avoid breaking current privileges.
Note that set_app_privileges does NOT revoke any current privileges. It only adds additional grants.
