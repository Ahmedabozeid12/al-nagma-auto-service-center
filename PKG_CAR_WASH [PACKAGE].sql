
CREATE OR REPLACE PACKAGE PKG_CAR_WASH AS

    PROCEDURE ADD_WASH(
        P_JOB_CARD_ID        IN CAR_WASH.JOB_CARD_ID%TYPE,
        P_USER_ID            IN CAR_WASH.PERFORMED_BY_USER_ID%TYPE,
        P_WASH_TYPE          IN CAR_WASH.WASH_TYPE%TYPE,
        P_PRICE              IN CAR_WASH.PRICE%TYPE DEFAULT NULL,
        P_NOTES              IN CAR_WASH.NOTES%TYPE DEFAULT NULL,
        P_CAR_WASH_ID        OUT CAR_WASH.CAR_WASH_ID%TYPE
    );

    PROCEDURE GET_WASH_PRICE(
        P_WASH_TYPE          IN WASH_PRICES.WASH_TYPE%TYPE,
        P_VEHICLE_SIZE       IN WASH_PRICES.VEHICLE_SIZE%TYPE,
        P_PRICE              OUT WASH_PRICES.PRICE%TYPE
    );

END PKG_CAR_WASH;
/


CREATE OR REPLACE PACKAGE BODY PKG_CAR_WASH AS

    PROCEDURE ADD_WASH(
        P_JOB_CARD_ID        IN CAR_WASH.JOB_CARD_ID%TYPE,
        P_USER_ID            IN CAR_WASH.PERFORMED_BY_USER_ID%TYPE,
        P_WASH_TYPE          IN CAR_WASH.WASH_TYPE%TYPE,
        P_PRICE              IN CAR_WASH.PRICE%TYPE DEFAULT NULL,
        P_NOTES              IN CAR_WASH.NOTES%TYPE DEFAULT NULL,
        P_CAR_WASH_ID        OUT CAR_WASH.CAR_WASH_ID%TYPE
    )
    IS
        V_PRICE WASH_PRICES.PRICE%TYPE;
        V_SIZE VEHICLES.VEHICLE_SIZE%TYPE;
        V_JOB_CARD_EXISTS NUMBER;
    BEGIN

        SELECT COUNT(*)
        INTO V_JOB_CARD_EXISTS
        FROM JOB_CARDS
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;

        IF V_JOB_CARD_EXISTS = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20401,
                'Job Card not found.'
            );
        END IF;


        SELECT VEHICLE_SIZE
        INTO V_SIZE
        FROM VEHICLES V,
             JOB_CARDS JC
        WHERE JC.VEHICLE_ID = V.VEHICLE_ID
          AND JC.JOB_CARD_ID = P_JOB_CARD_ID;


        IF P_PRICE IS NULL THEN

            SELECT PRICE
            INTO V_PRICE
            FROM WASH_PRICES
            WHERE WASH_TYPE = P_WASH_TYPE
              AND VEHICLE_SIZE = V_SIZE;

        ELSE

            V_PRICE := P_PRICE;

        END IF;


        INSERT INTO CAR_WASH
        (
            JOB_CARD_ID,
            PERFORMED_BY_USER_ID,
            WASH_TYPE,
            PRICE,
            NOTES
        )
        VALUES
        (
            P_JOB_CARD_ID,
            P_USER_ID,
            P_WASH_TYPE,
            V_PRICE,
            P_NOTES
        )
        RETURNING CAR_WASH_ID INTO P_CAR_WASH_ID;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20402,
                'Wash price or vehicle size not found.'
            );
    END ADD_WASH;


    PROCEDURE GET_WASH_PRICE(
        P_WASH_TYPE          IN WASH_PRICES.WASH_TYPE%TYPE,
        P_VEHICLE_SIZE       IN WASH_PRICES.VEHICLE_SIZE%TYPE,
        P_PRICE              OUT WASH_PRICES.PRICE%TYPE
    )
    IS
    BEGIN

        SELECT PRICE
        INTO P_PRICE
        FROM WASH_PRICES
        WHERE WASH_TYPE = P_WASH_TYPE
          AND VEHICLE_SIZE = P_VEHICLE_SIZE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20403,
                'Wash price not found.'
            );
    END GET_WASH_PRICE;

END PKG_CAR_WASH;
/