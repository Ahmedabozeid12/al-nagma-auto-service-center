CREATE OR REPLACE PACKAGE PKG_JOB_CARD AS

    PROCEDURE ADD_JOB_CARD(
        P_VEHICLE_ID          IN JOB_CARDS.VEHICLE_ID%TYPE,
        P_CREATED_BY_USER_ID  IN JOB_CARDS.CREATED_BY_USER_ID%TYPE,
        P_CUSTOMER_COMPLAINT  IN JOB_CARDS.CUSTOMER_COMPLAINT%TYPE,
        P_ODOMETER_READING    IN JOB_CARDS.ODOMETER_READING%TYPE,
        P_EXPECTED_DELIVERY   IN JOB_CARDS.EXPECTED_DELIVERY%TYPE DEFAULT NULL,
        P_WASH_REQUESTED      IN JOB_CARDS.WASH_REQUESTED%TYPE DEFAULT 'N',
        P_JOB_CARD_ID         OUT JOB_CARDS.JOB_CARD_ID%TYPE
    );

    PROCEDURE ADD_SERVICE(
        P_JOB_CARD_ID          IN JOB_CARD_SERVICES.JOB_CARD_ID%TYPE,
        P_SERVICE_ID           IN JOB_CARD_SERVICES.SERVICE_ID%TYPE,
        P_TECHNICIAN_ID        IN JOB_CARD_SERVICES.TECHNICIAN_ID%TYPE DEFAULT NULL,
        P_QUANTITY              IN JOB_CARD_SERVICES.QUANTITY%TYPE DEFAULT 1,
        P_JOB_CARD_SERVICE_ID   OUT JOB_CARD_SERVICES.JOB_CARD_SERVICE_ID%TYPE
    );

    PROCEDURE CHANGE_STATUS(
        P_JOB_CARD_ID  IN JOB_CARDS.JOB_CARD_ID%TYPE,
        P_STATUS_NAME  IN JOB_STATUS.STATUS_NAME%TYPE
    );

    PROCEDURE GET_JOB_CARD_TOTAL(
        P_JOB_CARD_ID IN NUMBER,
        P_TOTAL       OUT NUMBER
    );

    PROCEDURE GET_JOB_CARD(
        P_JOB_CARD_ID IN JOB_CARDS.JOB_CARD_ID%TYPE,
        P_RESULT      OUT SYS_REFCURSOR
    );

END PKG_JOB_CARD;
/CREATE OR REPLACE PACKAGE BODY PKG_JOB_CARD AS

    PROCEDURE ADD_JOB_CARD(
        P_VEHICLE_ID          IN JOB_CARDS.VEHICLE_ID%TYPE,
        P_CREATED_BY_USER_ID  IN JOB_CARDS.CREATED_BY_USER_ID%TYPE,
        P_CUSTOMER_COMPLAINT  IN JOB_CARDS.CUSTOMER_COMPLAINT%TYPE,
        P_ODOMETER_READING    IN JOB_CARDS.ODOMETER_READING%TYPE,
        P_EXPECTED_DELIVERY   IN JOB_CARDS.EXPECTED_DELIVERY%TYPE DEFAULT NULL,
        P_WASH_REQUESTED      IN JOB_CARDS.WASH_REQUESTED%TYPE DEFAULT 'N',
        P_JOB_CARD_ID         OUT JOB_CARDS.JOB_CARD_ID%TYPE
    )
    IS
        V_STATUS_ID JOB_STATUS.STATUS_ID%TYPE;
    BEGIN

        SELECT STATUS_ID
        INTO V_STATUS_ID
        FROM JOB_STATUS
        WHERE STATUS_NAME = 'NEW';

        INSERT INTO JOB_CARDS
        (
            JOB_CARD_ID,
            VEHICLE_ID,
            STATUS_ID,
            CREATED_BY_USER_ID,
            CUSTOMER_COMPLAINT,
            ODOMETER_READING,
            EXPECTED_DELIVERY,
            WASH_REQUESTED
        )
        VALUES
        (
            NULL,
            P_VEHICLE_ID,
            V_STATUS_ID,
            P_CREATED_BY_USER_ID,
            P_CUSTOMER_COMPLAINT,
            P_ODOMETER_READING,
            P_EXPECTED_DELIVERY,
            P_WASH_REQUESTED
        )
        RETURNING JOB_CARD_ID
        INTO P_JOB_CARD_ID;

    END ADD_JOB_CARD;


    PROCEDURE ADD_SERVICE(
        P_JOB_CARD_ID          IN JOB_CARD_SERVICES.JOB_CARD_ID%TYPE,
        P_SERVICE_ID           IN JOB_CARD_SERVICES.SERVICE_ID%TYPE,
        P_TECHNICIAN_ID        IN JOB_CARD_SERVICES.TECHNICIAN_ID%TYPE DEFAULT NULL,
        P_QUANTITY              IN JOB_CARD_SERVICES.QUANTITY%TYPE DEFAULT 1,
        P_JOB_CARD_SERVICE_ID   OUT JOB_CARD_SERVICES.JOB_CARD_SERVICE_ID%TYPE
    )
    IS
        V_UNIT_PRICE SERVICES.UNIT_PRICE%TYPE;
        V_ACTIVE     SERVICES.IS_ACTIVE%TYPE;
    BEGIN

        SELECT UNIT_PRICE,
               IS_ACTIVE
        INTO V_UNIT_PRICE,
             V_ACTIVE
        FROM SERVICES
        WHERE SERVICE_ID = P_SERVICE_ID;

        IF V_ACTIVE <> 'Y' THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Service is not active'
            );
        END IF;

        INSERT INTO JOB_CARD_SERVICES
        (
            JOB_CARD_SERVICE_ID,
            JOB_CARD_ID,
            SERVICE_ID,
            TECHNICIAN_ID,
            QUANTITY,
            UNIT_PRICE,
            LINE_STATUS
        )
        VALUES
        (
            NULL,
            P_JOB_CARD_ID,
            P_SERVICE_ID,
            P_TECHNICIAN_ID,
            P_QUANTITY,
            V_UNIT_PRICE,
            'COMPLETED'
        )
        RETURNING JOB_CARD_SERVICE_ID
        INTO P_JOB_CARD_SERVICE_ID;

    END ADD_SERVICE;


    PROCEDURE CHANGE_STATUS(
        P_JOB_CARD_ID IN JOB_CARDS.JOB_CARD_ID%TYPE,
        P_STATUS_NAME IN JOB_STATUS.STATUS_NAME%TYPE
    )
    IS
        V_STATUS_ID JOB_STATUS.STATUS_ID%TYPE;
    BEGIN

        SELECT STATUS_ID
        INTO V_STATUS_ID
        FROM JOB_STATUS
        WHERE STATUS_NAME = P_STATUS_NAME;

        UPDATE JOB_CARDS
        SET STATUS_ID = V_STATUS_ID,
            CLOSE_DATE =
                CASE
                    WHEN P_STATUS_NAME IN ('DELIVERED', 'CANCELED')
                    THEN SYSDATE
                    ELSE CLOSE_DATE
                END
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20023,
                'Job card not found'
            );
        END IF;

    END CHANGE_STATUS;


    PROCEDURE GET_JOB_CARD_TOTAL(
        P_JOB_CARD_ID IN NUMBER,
        P_TOTAL       OUT NUMBER
    )
    IS
        V_SERVICE_TOTAL NUMBER := 0;
        V_PART_TOTAL    NUMBER := 0;
        V_WASH_TOTAL    NUMBER := 0;
    BEGIN

        /* SERVICE TOTAL */

        SELECT NVL(SUM(QUANTITY * UNIT_PRICE), 0)
        INTO V_SERVICE_TOTAL
        FROM JOB_CARD_SERVICES
        WHERE JOB_CARD_ID = P_JOB_CARD_ID
        AND LINE_STATUS <> 'CANCELED';


        /* PARTS TOTAL */

        SELECT NVL(
                   SUM(
                       QUANTITY_ISSUED *
                       NVL(UNIT_PRICE, 0)
                   ),
                   0
               )
        INTO V_PART_TOTAL
        FROM PARTS_ISSUED
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;


        /* WASH TOTAL */

        SELECT NVL(SUM(PRICE), 0)
        INTO V_WASH_TOTAL
        FROM CAR_WASH
        WHERE JOB_CARD_ID = P_JOB_CARD_ID;


        /* GRAND TOTAL */

        P_TOTAL :=
            V_SERVICE_TOTAL
            + V_PART_TOTAL
            + V_WASH_TOTAL;

    END GET_JOB_CARD_TOTAL;


    PROCEDURE GET_JOB_CARD(
        P_JOB_CARD_ID IN JOB_CARDS.JOB_CARD_ID%TYPE,
        P_RESULT      OUT SYS_REFCURSOR
    )
    IS
    BEGIN

        OPEN P_RESULT FOR

            SELECT
                JC.JOB_CARD_ID,
                C.CUSTOMER_ID,
                C.FULL_NAME AS CUSTOMER_NAME,
                C.PHONE,
                V.VEHICLE_ID,
                V.PLATE_NUMBER,
                V.MAKE,
                V.MODEL,
                V.COLOR,
                V.ODOMETER,
                JS.STATUS_NAME,
                JC.OPEN_DATE,
                JC.EXPECTED_DELIVERY,
                JC.CUSTOMER_COMPLAINT,
                JC.WASH_REQUESTED

            FROM JOB_CARDS JC,
                 VEHICLES V,
                 CUSTOMERS C,
                 JOB_STATUS JS

            WHERE JC.VEHICLE_ID = V.VEHICLE_ID
              AND V.CUSTOMER_ID = C.CUSTOMER_ID
              AND JC.STATUS_ID = JS.STATUS_ID
              AND JC.JOB_CARD_ID = P_JOB_CARD_ID;

    END GET_JOB_CARD;


END PKG_JOB_CARD;
/