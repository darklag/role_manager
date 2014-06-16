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
SELECT * FROM create_app_roles('appname');
```
This will create: appname_owner, appname_app, appname_readonly. 
This function returns a row set with the new role name and password for each role created.
There are parameters to control creating each role that default to true: p_app_role, p_owner_role, p_readonly_role.
By default a 12 character, randomly generated password will be set for each role. 
You can stop this by setting the p_set_password parameter to false.
You can control the length of the password with p_password_length.
Passwords will only contain upper/lower alphanumeric characters.

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
