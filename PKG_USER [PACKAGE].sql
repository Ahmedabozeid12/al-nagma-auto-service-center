
CREATE OR REPLACE PACKAGE PKG_USER AS

    PROCEDURE ADD_USER(
        P_ROLE_ID       IN USERS.ROLE_ID%TYPE,
        P_USERNAME      IN USERS.USERNAME%TYPE,
        P_PASSWORD      IN USERS.PASSWORD_USER%TYPE,
        P_FULL_NAME     IN USERS.FULL_NAME%TYPE,
        P_USER_ID       OUT USERS.USER_ID%TYPE
    );

    PROCEDURE LOGIN(
        P_USERNAME      IN USERS.USERNAME%TYPE,
        P_PASSWORD      IN USERS.PASSWORD_USER%TYPE,
        P_USER_ID       OUT USERS.USER_ID%TYPE,
        P_ROLE_NAME     OUT ROLES.ROLE_NAME%TYPE,
        P_FULL_NAME     OUT USERS.FULL_NAME%TYPE
    );

END PKG_USER;
/


CREATE OR REPLACE PACKAGE BODY PKG_USER AS

    PROCEDURE ADD_USER(
        P_ROLE_ID       IN USERS.ROLE_ID%TYPE,
        P_USERNAME      IN USERS.USERNAME%TYPE,
        P_PASSWORD      IN USERS.PASSWORD_USER%TYPE,
        P_FULL_NAME     IN USERS.FULL_NAME%TYPE,
        P_USER_ID       OUT USERS.USER_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO USERS
        (
            ROLE_ID,
            USERNAME,
            PASSWORD_USER,
            FULL_NAME
        )
        VALUES
        (
            P_ROLE_ID,
            P_USERNAME,
            P_PASSWORD,
            P_FULL_NAME
        )
        RETURNING USER_ID INTO P_USER_ID;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20701,
                'Username already exists.'
            );
    END ADD_USER;


    PROCEDURE LOGIN(
        P_USERNAME      IN USERS.USERNAME%TYPE,
        P_PASSWORD      IN USERS.PASSWORD_USER%TYPE,
        P_USER_ID       OUT USERS.USER_ID%TYPE,
        P_ROLE_NAME     OUT ROLES.ROLE_NAME%TYPE,
        P_FULL_NAME     OUT USERS.FULL_NAME%TYPE
    )
    IS
    BEGIN

        SELECT U.USER_ID,
               R.ROLE_NAME,
               U.FULL_NAME
        INTO P_USER_ID,
             P_ROLE_NAME,
             P_FULL_NAME
        FROM USERS U,
             ROLES R
        WHERE U.ROLE_ID = R.ROLE_ID
          AND U.USERNAME = P_USERNAME
          AND U.PASSWORD_USER = P_PASSWORD;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN

            RAISE_APPLICATION_ERROR(
                -20702,
                'Invalid username or password.'
            );

    END LOGIN;

END PKG_USER;
/