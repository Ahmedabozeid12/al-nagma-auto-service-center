
CREATE OR REPLACE PACKAGE PKG_CUSTOMER AS

    PROCEDURE ADD_CUSTOMER(
        P_FULL_NAME      IN CUSTOMERS.FULL_NAME%TYPE,
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_NATIONAL_ID    IN CUSTOMERS.NATIONAL_ID%TYPE DEFAULT NULL,
        P_ADDRESS        IN CUSTOMERS.ADDRESS%TYPE DEFAULT NULL,
        P_CUSTOMER_TYPE  IN CUSTOMERS.CUSTOMER_TYPE%TYPE DEFAULT 'INDIVIDUAL',
        P_GENDER         IN CUSTOMERS.GENDER%TYPE DEFAULT NULL,
        P_CUSTOMER_ID    OUT CUSTOMERS.CUSTOMER_ID%TYPE
    );

    PROCEDURE UPDATE_CUSTOMER(
        P_CUSTOMER_ID    IN CUSTOMERS.CUSTOMER_ID%TYPE,
        P_FULL_NAME      IN CUSTOMERS.FULL_NAME%TYPE,
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_NATIONAL_ID    IN CUSTOMERS.NATIONAL_ID%TYPE,
        P_ADDRESS        IN CUSTOMERS.ADDRESS%TYPE,
        P_CUSTOMER_TYPE  IN CUSTOMERS.CUSTOMER_TYPE%TYPE,
        P_GENDER         IN CUSTOMERS.GENDER%TYPE
    );

    PROCEDURE ADD_VEHICLE(
        P_CUSTOMER_ID    IN VEHICLES.CUSTOMER_ID%TYPE,
        P_PLATE_NUMBER   IN VEHICLES.PLATE_NUMBER%TYPE,
        P_MAKE           IN VEHICLES.MAKE%TYPE,
        P_MODEL          IN VEHICLES.MODEL%TYPE,
        P_YEAR           IN VEHICLES.YEAR%TYPE,
        P_COLOR          IN VEHICLES.COLOR%TYPE,
        P_VIN            IN VEHICLES.VIN%TYPE,
        P_ODOMETER       IN VEHICLES.ODOMETER%TYPE DEFAULT 0,
        P_VEHICLE_SIZE   IN VEHICLES.VEHICLE_SIZE%TYPE DEFAULT NULL,
        P_VEHICLE_ID     OUT VEHICLES.VEHICLE_ID%TYPE
    );

    PROCEDURE UPDATE_ODOMETER(
        P_VEHICLE_ID     IN VEHICLES.VEHICLE_ID%TYPE,
        P_NEW_ODOMETER   IN VEHICLES.ODOMETER%TYPE
    );

    PROCEDURE GET_CUSTOMER_BY_PHONE(
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_RESULT         OUT SYS_REFCURSOR
    );

    PROCEDURE GET_CUSTOMER_VEHICLES(
        P_CUSTOMER_ID    IN CUSTOMERS.CUSTOMER_ID%TYPE,
        P_RESULT         OUT SYS_REFCURSOR
    );

END PKG_CUSTOMER;
/


CREATE OR REPLACE PACKAGE BODY PKG_CUSTOMER AS

    PROCEDURE ADD_CUSTOMER(
        P_FULL_NAME      IN CUSTOMERS.FULL_NAME%TYPE,
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_NATIONAL_ID    IN CUSTOMERS.NATIONAL_ID%TYPE DEFAULT NULL,
        P_ADDRESS        IN CUSTOMERS.ADDRESS%TYPE DEFAULT NULL,
        P_CUSTOMER_TYPE  IN CUSTOMERS.CUSTOMER_TYPE%TYPE DEFAULT 'INDIVIDUAL',
        P_GENDER         IN CUSTOMERS.GENDER%TYPE DEFAULT NULL,
        P_CUSTOMER_ID    OUT CUSTOMERS.CUSTOMER_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO CUSTOMERS
        (
            FULL_NAME,
            PHONE,
            NATIONAL_ID,
            ADDRESS,
            CUSTOMER_TYPE,
            GENDER
        )
        VALUES
        (
            P_FULL_NAME,
            P_PHONE,
            P_NATIONAL_ID,
            P_ADDRESS,
            P_CUSTOMER_TYPE,
            P_GENDER
        )
        RETURNING CUSTOMER_ID INTO P_CUSTOMER_ID;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20101,
                'Phone or National ID already exists.'
            );
    END ADD_CUSTOMER;


    PROCEDURE UPDATE_CUSTOMER(
        P_CUSTOMER_ID    IN CUSTOMERS.CUSTOMER_ID%TYPE,
        P_FULL_NAME      IN CUSTOMERS.FULL_NAME%TYPE,
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_NATIONAL_ID    IN CUSTOMERS.NATIONAL_ID%TYPE,
        P_ADDRESS        IN CUSTOMERS.ADDRESS%TYPE,
        P_CUSTOMER_TYPE  IN CUSTOMERS.CUSTOMER_TYPE%TYPE,
        P_GENDER         IN CUSTOMERS.GENDER%TYPE
    )
    IS
    BEGIN

        UPDATE CUSTOMERS
        SET FULL_NAME     = P_FULL_NAME,
            PHONE         = P_PHONE,
            NATIONAL_ID   = P_NATIONAL_ID,
            ADDRESS       = P_ADDRESS,
            CUSTOMER_TYPE = P_CUSTOMER_TYPE,
            GENDER        = P_GENDER
        WHERE CUSTOMER_ID = P_CUSTOMER_ID;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20102,
                'Customer not found.'
            );
        END IF;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20103,
                'Phone or National ID already exists.'
            );
    END UPDATE_CUSTOMER;


    PROCEDURE ADD_VEHICLE(
        P_CUSTOMER_ID    IN VEHICLES.CUSTOMER_ID%TYPE,
        P_PLATE_NUMBER   IN VEHICLES.PLATE_NUMBER%TYPE,
        P_MAKE           IN VEHICLES.MAKE%TYPE,
        P_MODEL          IN VEHICLES.MODEL%TYPE,
        P_YEAR           IN VEHICLES.YEAR%TYPE,
        P_COLOR          IN VEHICLES.COLOR%TYPE,
        P_VIN            IN VEHICLES.VIN%TYPE,
        P_ODOMETER       IN VEHICLES.ODOMETER%TYPE DEFAULT 0,
        P_VEHICLE_SIZE   IN VEHICLES.VEHICLE_SIZE%TYPE DEFAULT NULL,
        P_VEHICLE_ID     OUT VEHICLES.VEHICLE_ID%TYPE
    )
    IS
    BEGIN

        INSERT INTO VEHICLES
        (
            CUSTOMER_ID,
            PLATE_NUMBER,
            MAKE,
            MODEL,
            YEAR,
            COLOR,
            VIN,
            ODOMETER,
            VEHICLE_SIZE
        )
        VALUES
        (
            P_CUSTOMER_ID,
            P_PLATE_NUMBER,
            P_MAKE,
            P_MODEL,
            P_YEAR,
            P_COLOR,
            P_VIN,
            P_ODOMETER,
            P_VEHICLE_SIZE
        )
        RETURNING VEHICLE_ID INTO P_VEHICLE_ID;

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(
                -20104,
                'Plate number or VIN already exists.'
            );
    END ADD_VEHICLE;


    PROCEDURE UPDATE_ODOMETER(
        P_VEHICLE_ID     IN VEHICLES.VEHICLE_ID%TYPE,
        P_NEW_ODOMETER   IN VEHICLES.ODOMETER%TYPE
    )
    IS
        V_OLD_ODOMETER VEHICLES.ODOMETER%TYPE;
    BEGIN

        SELECT ODOMETER
        INTO V_OLD_ODOMETER
        FROM VEHICLES
        WHERE VEHICLE_ID = P_VEHICLE_ID
        FOR UPDATE;

        IF P_NEW_ODOMETER < V_OLD_ODOMETER THEN
            RAISE_APPLICATION_ERROR(
                -20105,
                'New odometer cannot be less than current odometer.'
            );
        END IF;

        UPDATE VEHICLES
        SET ODOMETER = P_NEW_ODOMETER
        WHERE VEHICLE_ID = P_VEHICLE_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20106,
                'Vehicle not found.'
            );
    END UPDATE_ODOMETER;


    PROCEDURE GET_CUSTOMER_BY_PHONE(
        P_PHONE          IN CUSTOMERS.PHONE%TYPE,
        P_RESULT         OUT SYS_REFCURSOR
    )
    IS
    BEGIN

        OPEN P_RESULT FOR
            SELECT CUSTOMER_ID,
                   FULL_NAME,
                   PHONE,
                   NATIONAL_ID,
                   ADDRESS,
                   CUSTOMER_TYPE,
                   GENDER
            FROM CUSTOMERS
            WHERE PHONE = P_PHONE;

    END GET_CUSTOMER_BY_PHONE;


    PROCEDURE GET_CUSTOMER_VEHICLES(
        P_CUSTOMER_ID    IN CUSTOMERS.CUSTOMER_ID%TYPE,
        P_RESULT         OUT SYS_REFCURSOR
    )
    IS
    BEGIN

        OPEN P_RESULT FOR
            SELECT VEHICLE_ID,
                   CUSTOMER_ID,
                   PLATE_NUMBER,
                   MAKE,
                   MODEL,
                   YEAR,
                   COLOR,
                   VIN,
                   ODOMETER,
                   VEHICLE_SIZE
            FROM VEHICLES
            WHERE CUSTOMER_ID = P_CUSTOMER_ID
            ORDER BY VEHICLE_ID;

    END GET_CUSTOMER_VEHICLES;

END PKG_CUSTOMER;
/